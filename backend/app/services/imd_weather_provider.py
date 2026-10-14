"""
IMD Weather Provider
====================
Implements WeatherProvider using the official India Meteorological
Department (IMD) API at https://api.imd.gov.in/api/v1/

API reference: https://api.imd.gov.in/public/api_reference.html

Endpoint parameters — verified from official docs
--------------------------------------------------
current_wx        → ?id=<StationId>        (numeric station ID, NOT city name)
cityforecast      → ?id=<StationCode>      (numeric station code)
cityforecastloc   → ?id=<StationCode>      (same, adds Lat/Lon to response)
districtnowcast   → ?id=<numericId>        (numeric district ID)
districtwarning   → ?id=<numericObjId>     (numeric Obj_id)

None of these endpoints accept city=<name>.  Passing city= was the root
cause of the 401 — the URL did not match any valid IMD route, so the
gateway returned 401/403 before any auth check could succeed.

Configuration
-------------
All credentials and IDs are read from environment variables (see
app/config/settings.py).  Nothing is hard-coded here.

Required env vars:
  IMD_API_KEY              — API key issued by IMD
  IMD_CURRENT_WX_URL       — https://api.imd.gov.in/api/v1/current_wx
  IMD_STATION_ID           — numeric station ID for current_wx

Optional env vars (supplementary data):
  IMD_CITY_FORECAST_URL    — https://api.imd.gov.in/api/v1/cityforecastloc
  IMD_FORECAST_STATION_CODE— station code for cityforecast
  IMD_WARNINGS_URL         — https://api.imd.gov.in/api/v1/districtwarning
  IMD_DISTRICT_WARNING_ID  — numeric Obj_id for districtwarning
  IMD_NOWCAST_URL          — https://api.imd.gov.in/api/v1/districtnowcast
  IMD_DISTRICT_NOWCAST_ID  — numeric district ID for districtnowcast
  IMD_AUTH_HEADER          — HTTP header name for the API key (default: X-Api-Key)

401 diagnostic note
-------------------
If the API returns HTTP 401, the sanitized response message is logged
(without the key value) so the exact IMD error reason is visible.
Possible causes of 401:
  1. Wrong API key value             → code-side fix: correct key in .env
  2. Correct key but IP not in IMD whitelist → external: contact IMD
  3. Wrong authentication header name → code-side fix: set IMD_AUTH_HEADER
"""

import logging

import requests

from app.config.settings import (
    HTTP_TIMEOUT_SECONDS,
    IMD_AUTH_HEADER,
    IMD_CITY_FORECAST_URL,
    IMD_CURRENT_WX_URL,
    IMD_DISTRICT_NOWCAST_ID,
    IMD_DISTRICT_WARNING_ID,
    IMD_FORECAST_STATION_CODE,
    IMD_NOWCAST_URL,
    IMD_STATION_ID,
    IMD_WARNINGS_URL,
    ConfigurationError,
    require_imd_config,
)
from app.models.weather import WeatherResponse
from app.services.imd_auth import IMDAuthError, get_access_token, invalidate_token
from app.services.imd_mapper import _safe_float, map_current_weather
from app.services.weather_provider import LocationQuery, WeatherProvider

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Verified static coordinates for known IMD station IDs.
#
# These are the geographic coordinates of the physical weather stations.
# They are used as fallback when the Flutter client does not supply GPS
# coordinates, so that Open-Meteo UV/AQI/visibility/forecast can still
# be fetched.
#
# IMPORTANT: Only add a station to this table when you have verified its
# location from an official source (IMD station list, coordinates returned
# by the /current_wx endpoint, or the IMD API mapping endpoint).
# Do NOT assume coordinates for an unlisted station ID.
# ---------------------------------------------------------------------------
_STATION_COORDS: dict[str, tuple[float, float]] = {
    # Hyderabad (Begumpet synoptic station)
    # Verified from IMD station metadata and Open-Meteo agree with this.
    "43128": (17.4500, 78.4700),
    "42867": (17.4500, 78.4700),   # Hyderabad alternate station code
}

# Fallback coordinates for known cities if station ID is not in table
_CITY_COORDS: dict[str, tuple[float, float]] = {
    "hyderabad": (17.4500, 78.4700),
    "secunderabad": (17.4500, 78.4700),
}


# ---------------------------------------------------------------------------
# Open-Meteo hourly value extractor
# ---------------------------------------------------------------------------

def _extract_current_hour_value(
    response_json: dict,
    key: str,
    label: str,
) -> float | None:
    """
    Extract the value for the current local hour from an Open-Meteo
    hourly response.

    Open-Meteo returns data shaped like:

        {
          "timezone": "Asia/Kolkata",          ← IANA name — preferred
          "utc_offset_seconds": 19800,         ← fallback only
          "hourly": {
            "time":   ["2026-10-04T00:00", "2026-10-04T01:00", ...],
            "<key>":  [3.2, 4.1, ...]
          }
        }

    Timezone resolution (in order):
      1. IANA name from the "timezone" field via zoneinfo.ZoneInfo —
         correctly handles DST transitions.
      2. Fixed UTC offset from "utc_offset_seconds" if the IANA name
         is absent or ZoneInfo cannot find it.
      3. UTC if neither is available.

    Hour matching:
      The current wall-clock time in the resolved timezone is truncated
      to the hour and formatted as "YYYY-MM-DDTHH:00".  An exact match
      in the "time" array is required.

    Stale-value policy:
      We do NOT fall back to a previous hour.  If the current-hour slot
      is absent or its value is None, return None.  Serving an hour-old
      value without the caller's knowledge is less safe than returning
      None and letting the caller decide.

    Returns None on any parse failure — never raises.
    """
    from datetime import datetime, timezone, timedelta
    from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

    try:
        hourly = response_json.get("hourly") or {}
        times  = hourly.get("time", [])
        values = hourly.get(key, [])

        if not times or not values or len(times) != len(values):
            logger.debug("Open-Meteo %s: empty or mismatched arrays.", label)
            return None

        # ── Resolve timezone ─────────────────────────────────────────
        local_tz = None
        iana_name = response_json.get("timezone")   # e.g. "Asia/Kolkata"
        if iana_name:
            try:
                local_tz = ZoneInfo(iana_name)
            except (ZoneInfoNotFoundError, KeyError):
                logger.debug(
                    "Open-Meteo %s: unrecognised IANA timezone '%s', "
                    "falling back to utc_offset_seconds.",
                    label, iana_name,
                )

        if local_tz is None:
            # Fall back to the fixed UTC offset supplied in the response
            utc_offset_seconds = response_json.get("utc_offset_seconds")
            if isinstance(utc_offset_seconds, (int, float)):
                local_tz = timezone(timedelta(seconds=int(utc_offset_seconds)))
            else:
                logger.debug(
                    "Open-Meteo %s: no usable timezone, defaulting to UTC.",
                    label,
                )
                local_tz = timezone.utc

        # ── Determine current-hour string ────────────────────────────
        now_local  = datetime.now(tz=timezone.utc).astimezone(local_tz)
        target_str = now_local.strftime("%Y-%m-%dT%H:00")

        # ── Exact match required — no stale fallback ─────────────────
        if target_str not in times:
            logger.debug(
                "Open-Meteo %s: current-hour slot '%s' not in response "
                "(response covers %s..%s). Returning None — "
                "will not serve a stale past value.",
                label, target_str,
                times[0] if times else "?",
                times[-1] if times else "?",
            )
            return None

        idx = times.index(target_str)
        val = values[idx]
        if val is None:
            logger.debug(
                "Open-Meteo %s: value is None for slot '%s'.",
                label, target_str,
            )
            return None

        return float(val)

    except Exception as exc:          # noqa: BLE001
        logger.debug("Open-Meteo %s hour extraction failed: %s", label, exc)
        return None


# ---------------------------------------------------------------------------
# Provider-specific exceptions
# ---------------------------------------------------------------------------

class IMDFetchError(Exception):
    """Raised when an HTTP request to the IMD API fails."""


class IMDParseError(Exception):
    """Raised when the IMD API returns a response that cannot be parsed."""


# ---------------------------------------------------------------------------
# IMDWeatherProvider
# ---------------------------------------------------------------------------

class IMDWeatherProvider(WeatherProvider):
    """
    Fetches live weather data from the official IMD API endpoints,
    maps the responses through imd_mapper, and returns a WeatherResponse
    structurally identical to what DemoWeatherProvider returns.

    The route layer, ranking engine, and Flutter application are fully
    unaware of which provider is active.
    """

    def get_weather(self, location: LocationQuery) -> WeatherResponse:
        """
        Fetch current weather + optional supplementary data from IMD.

        Parameters
        ----------
        location : LocationQuery — city name used for logging only.
                   Actual API calls use station/district numeric IDs
                   from environment variables, per IMD API spec.

        Returns
        -------
        WeatherResponse with source="IMD".

        Raises
        ------
        ConfigurationError
            If IMD_API_KEY, IMD_CURRENT_WX_URL, or IMD_STATION_ID are absent.
        IMDFetchError
            If any required HTTP request fails or times out.
        IMDParseError
            If the IMD response cannot be parsed as JSON.
        """
        # ── 1. Validate configuration before any network call ──────────────
        require_imd_config()
        # Re-import settings module to pick up any runtime .env changes
        from app.config import settings as _s

        logger.info(
            "IMDWeatherProvider: fetching weather for city='%s' "
            "using station_id='%s'",
            location.city.strip(),
            _s.IMD_STATION_ID,
        )

        # ── 2. Fetch current weather (required) ────────────────────────────
        # Official parameter: ?id=<StationId>  (NOT city=)
        current_json = self._fetch_current(
            station_id=_s.IMD_STATION_ID,
            api_key=_s.IMD_API_KEY,
            url=_s.IMD_CURRENT_WX_URL,
            auth_header=_s.IMD_AUTH_HEADER,
        )

        # ── 3. Fetch optional supplementary data (best-effort) ─────────────

        # City forecast — requires station code, not lat/lon
        forecast_json = None
        if _s.IMD_CITY_FORECAST_URL and _s.IMD_FORECAST_STATION_CODE:
            forecast_json = self._fetch_forecast(
                station_code=_s.IMD_FORECAST_STATION_CODE,
                api_key=_s.IMD_API_KEY,
                url=_s.IMD_CITY_FORECAST_URL,
                auth_header=_s.IMD_AUTH_HEADER,
            )

        # District warnings — requires numeric Obj_id
        warnings_json = None
        if _s.IMD_WARNINGS_URL and _s.IMD_DISTRICT_WARNING_ID:
            warnings_json = self._fetch_warnings(
                district_id=_s.IMD_DISTRICT_WARNING_ID,
                api_key=_s.IMD_API_KEY,
                url=_s.IMD_WARNINGS_URL,
                auth_header=_s.IMD_AUTH_HEADER,
            )

        # District nowcast — requires numeric district ID
        nowcast_json = None
        if _s.IMD_NOWCAST_URL and _s.IMD_DISTRICT_NOWCAST_ID:
            nowcast_json = self._fetch_nowcast(
                district_id=_s.IMD_DISTRICT_NOWCAST_ID,
                api_key=_s.IMD_API_KEY,
                url=_s.IMD_NOWCAST_URL,
                auth_header=_s.IMD_AUTH_HEADER,
            )

        # ── 3e. Open-Meteo supplementary UV + AQI + visibility + forecast ──
        # Attempted when coordinates are available.  Coordinates come from:
        #   1. GPS fix passed by the Flutter client (location.latitude/.longitude)
        #   2. Static lookup for the configured IMD_STATION_ID as fallback.
        #
        # The static table maps verified IMD station IDs to their geographic
        # coordinates.  Coordinates are never assumed from an unknown station —
        # only explicitly listed stations are resolved.
        #
        # A failure here is never fatal — IMD weather is returned regardless.
        supplementary_uv_index: int | None = None
        supplementary_aqi: int | None = None
        supplementary_visibility_km: float | None = None
        supplementary_forecast: list | None = None

        # Prefer caller-supplied GPS; fall back to static station coords.
        eff_lat = location.latitude
        eff_lon = location.longitude

        if eff_lat is None or eff_lon is None:
            # 1. Check if current_json returned coordinates
            if isinstance(current_json, dict):
                eff_lat = _safe_float(current_json.get("Lat") or current_json.get("Latitude"))
                eff_lon = _safe_float(current_json.get("Lon") or current_json.get("Longitude"))
            elif isinstance(current_json, list):
                station_key = str(_s.IMD_STATION_ID).strip() if _s.IMD_STATION_ID else None
                for item in current_json:
                    if isinstance(item, dict):
                        item_id = str(item.get("Station Id", "")).strip()
                        if not station_key or item_id == station_key:
                            eff_lat = _safe_float(item.get("Lat") or item.get("Latitude"))
                            eff_lon = _safe_float(item.get("Lon") or item.get("Longitude"))
                            if eff_lat is not None and eff_lon is not None:
                                break

        if eff_lat is None or eff_lon is None:
            station_id = str(_s.IMD_STATION_ID).strip() if _s.IMD_STATION_ID else None
            if station_id and station_id in _STATION_COORDS:
                eff_lat, eff_lon = _STATION_COORDS[station_id]
                logger.info(
                    "Open-Meteo: no GPS fix — using static coords for "
                    "station_id='%s' (lat=%.4f lon=%.4f)",
                    station_id, eff_lat, eff_lon,
                )
            elif location.city and location.city.strip().lower() in _CITY_COORDS:
                city_key = location.city.strip().lower()
                eff_lat, eff_lon = _CITY_COORDS[city_key]
                logger.info(
                    "Open-Meteo: no GPS fix — using static coords for "
                    "city='%s' (lat=%.4f lon=%.4f)",
                    city_key, eff_lat, eff_lon,
                )
            else:
                logger.debug(
                    "Open-Meteo: no GPS and no static coords for "
                    "station_id='%s' — UV/AQI/visibility/forecast skipped.",
                    station_id,
                )

        if eff_lat is not None and eff_lon is not None:
            uv_aqi = self._fetch_open_meteo_uv_aqi(
                lat=eff_lat,
                lon=eff_lon,
            )
            if uv_aqi is not None:
                supplementary_uv_index      = uv_aqi.get("uv_index")
                supplementary_aqi           = uv_aqi.get("aqi")
                supplementary_visibility_km = uv_aqi.get("visibility_km")

            supplementary_forecast = self._fetch_open_meteo_forecast(
                lat=eff_lat,
                lon=eff_lon,
            )

        # ── 4. Map raw JSON → WeatherResponse ──────────────────────────────
        return map_current_weather(
            current_json=current_json,
            forecast_json=forecast_json,
            warnings_json=warnings_json,
            nowcast_json=nowcast_json,
            uv_index=supplementary_uv_index,
            aqi=supplementary_aqi,
            visibility_km=supplementary_visibility_km,
            open_meteo_forecast=supplementary_forecast,
            latitude=eff_lat,
            longitude=eff_lon,
        )

    # ---------------------------------------------------------------------- #
    # Private HTTP helpers                                                     #
    # ---------------------------------------------------------------------- #

    def _fetch_open_meteo_uv_aqi(
        self,
        lat: float,
        lon: float,
    ) -> dict | None:
        """
        Retrieve UV Index and European AQI from the Open-Meteo public APIs.

        Open-Meteo is a free, no-credentials-required service.
        Reference:
          UV:  https://api.open-meteo.com/v1/forecast
          AQI: https://air-quality-api.open-meteo.com/v1/air-quality

        Both responses contain an hourly time-series.  We select the value
        whose ISO-8601 timestamp matches the current local hour at the
        requested coordinates (using the timezone returned by Open-Meteo).

        Returns
        -------
        dict | None
            {"uv_index": int | None, "aqi": int | None}
            None on any failure — never raises.

        Notes
        -----
        - A failure of this method must never prevent the main IMD weather
          response from being returned.
        - The AQI is a model-based estimate (European AQI scale), NOT
          official CPCB AQI.
        - No caching is applied; the caller is responsible for rate management.
        """
        from datetime import datetime, timezone

        result: dict = {"uv_index": None, "aqi": None, "visibility_km": None}

        # ── UV Index + Visibility ─────────────────────────────────────────
        # Both fetched in one call to the forecast endpoint to avoid an
        # extra HTTP request.  Visibility is returned in metres; we convert
        # to km here so the mapper receives the correct unit.
        try:
            uv_resp = requests.get(
                "https://api.open-meteo.com/v1/forecast",
                params={
                    "latitude":         str(lat),
                    "longitude":        str(lon),
                    "hourly":           "uv_index,visibility",
                    "forecast_days":    "1",
                    "timezone":         "auto",
                },
                headers={"Accept": "application/json"},
                timeout=HTTP_TIMEOUT_SECONDS,
            )
            if uv_resp.ok:
                uv_data = uv_resp.json()
                uv_val = _extract_current_hour_value(
                    uv_data, key="uv_index", label="UV"
                )
                if uv_val is not None:
                    result["uv_index"] = int(round(uv_val))
                vis_val = _extract_current_hour_value(
                    uv_data, key="visibility", label="visibility"
                )
                if vis_val is not None:
                    # Open-Meteo returns visibility in metres; convert to km
                    result["visibility_km"] = round(vis_val / 1000.0, 2)
            else:
                logger.warning(
                    "Open-Meteo UV endpoint returned HTTP %s — UV+visibility skipped.",
                    uv_resp.status_code,
                )
        except requests.exceptions.Timeout:
            logger.warning("Open-Meteo UV request timed out — UV+visibility skipped.")
        except requests.exceptions.RequestException as exc:
            logger.warning("Open-Meteo UV request error: %s — UV+visibility skipped.",
                           type(exc).__name__)
        except (ValueError, KeyError, TypeError) as exc:
            logger.warning("Open-Meteo UV parse error: %s — UV+visibility skipped.", exc)

        # ── European AQI ──────────────────────────────────────────────────
        try:
            aqi_resp = requests.get(
                "https://air-quality-api.open-meteo.com/v1/air-quality",
                params={
                    "latitude":      str(lat),
                    "longitude":     str(lon),
                    "hourly":        "european_aqi",
                    "forecast_days": "1",
                    "timezone":      "auto",
                },
                headers={"Accept": "application/json"},
                timeout=HTTP_TIMEOUT_SECONDS,
            )
            if aqi_resp.ok:
                aqi_data = aqi_resp.json()
                aqi_val = _extract_current_hour_value(
                    aqi_data, key="european_aqi", label="AQI"
                )
                if aqi_val is not None:
                    result["aqi"] = int(round(aqi_val))
            else:
                logger.warning(
                    "Open-Meteo AQI endpoint returned HTTP %s — AQI skipped.",
                    aqi_resp.status_code,
                )
        except requests.exceptions.Timeout:
            logger.warning("Open-Meteo AQI request timed out — AQI skipped.")
        except requests.exceptions.RequestException as exc:
            logger.warning("Open-Meteo AQI request error: %s — AQI skipped.",
                           type(exc).__name__)
        except (ValueError, KeyError, TypeError) as exc:
            logger.warning("Open-Meteo AQI parse error: %s — AQI skipped.", exc)

        return result

    def _fetch_open_meteo_forecast(
        self,
        lat: float,
        lon: float,
    ) -> list | None:
        """
        Retrieve a 7-day daily forecast from Open-Meteo.

        Returns a list of dicts shaped for _map_open_meteo_forecast() in the
        mapper, or None on any failure.  Never raises — forecast failure
        must not prevent the IMD weather response from being returned.

        Fields requested:
          temperature_2m_max         — daily maximum temperature (°C)
          temperature_2m_min         — daily minimum temperature (°C)
          precipitation_probability_max — 0–100 chance-of-rain percentage
          precipitation_sum          — total rainfall in mm
          weather_code               — WMO weather interpretation code
          time                       — date string per day
        """
        try:
            resp = requests.get(
                "https://api.open-meteo.com/v1/forecast",
                params={
                    "latitude":     str(lat),
                    "longitude":    str(lon),
                    "daily": ",".join([
                        "temperature_2m_max",
                        "temperature_2m_min",
                        "precipitation_probability_max",
                        "precipitation_sum",
                        "weather_code",
                    ]),
                    "forecast_days": "7",
                    "timezone":      "auto",
                },
                headers={"Accept": "application/json"},
                timeout=HTTP_TIMEOUT_SECONDS,
            )
            if not resp.ok:
                logger.warning(
                    "Open-Meteo daily forecast returned HTTP %s — forecast skipped.",
                    resp.status_code,
                )
                return None

            data = resp.json()
            daily = data.get("daily") or {}
            times  = daily.get("time", [])
            tmax   = daily.get("temperature_2m_max", [])
            tmin   = daily.get("temperature_2m_min", [])
            prob   = daily.get("precipitation_probability_max", [])
            precip = daily.get("precipitation_sum", [])
            codes  = daily.get("weather_code") or daily.get("weathercode") or []

            if not times:
                logger.debug("Open-Meteo forecast: empty time array.")
                return None

            # Zip available arrays; shorter arrays are padded with None
            n = len(times)
            days = []
            for i in range(n):
                days.append({
                    "date":     times[i] if i < len(times)  else None,
                    "max_temp": tmax[i]  if i < len(tmax)   else None,
                    "min_temp": tmin[i]  if i < len(tmin)   else None,
                    "rain_prob":prob[i]  if i < len(prob)   else None,
                    "precip":   precip[i]if i < len(precip) else None,
                    "wmo_code": codes[i] if i < len(codes)  else None,
                })
            return days

        except requests.exceptions.Timeout:
            logger.warning("Open-Meteo forecast request timed out — forecast skipped.")
        except requests.exceptions.RequestException as exc:
            logger.warning("Open-Meteo forecast request error: %s — forecast skipped.",
                           type(exc).__name__)
        except (ValueError, KeyError, TypeError) as exc:
            logger.warning("Open-Meteo forecast parse error: %s — forecast skipped.", exc)
        return None

    def _fetch_current(
        self,
        station_id: str,
        api_key: str,
        url: str,
        auth_header: str,
        _jwt_token: str | None = None,
    ) -> dict:
        """
        GET current weather from IMD current_wx.

        Official parameter: ?id=<StationId>
        The station ID is a numeric IMD identifier, e.g. "42867" for
        Hyderabad Begumpet.  It is NOT a city name.
        """
        params = {"id": station_id}
        return self._get(
            url, params=params, api_key=api_key,
            auth_header=auth_header, label="current weather",
            _jwt_token=_jwt_token,
        )

    def _fetch_forecast(
        self,
        station_code: str,
        api_key: str,
        url: str,
        auth_header: str,
        _jwt_token: str | None = None,
    ) -> dict | None:
        """
        GET 7-day forecast from IMD cityforecastloc.

        Official parameter: ?id=<StationCode>
        Returns None if the request fails (forecast is optional).
        """
        params = {"id": station_code}
        try:
            return self._get(
                url, params=params, api_key=api_key,
                auth_header=auth_header, label="forecast",
                _jwt_token=_jwt_token,
            )
        except (IMDFetchError, IMDParseError) as exc:
            logger.warning("IMD forecast fetch failed (non-fatal): %s", exc)
            return None

    def _fetch_warnings(
        self,
        district_id: str,
        api_key: str,
        url: str,
        auth_header: str,
        _jwt_token: str | None = None,
    ) -> dict | None:
        """
        GET district-wise warnings from IMD districtwarning.

        Official parameter: ?id=<numericObjId>
        Returns None if the request fails (warnings are optional).
        """
        params = {"id": district_id}
        try:
            return self._get(
                url, params=params, api_key=api_key,
                auth_header=auth_header, label="warnings",
                _jwt_token=_jwt_token,
            )
        except (IMDFetchError, IMDParseError) as exc:
            logger.warning("IMD warnings fetch failed (non-fatal): %s", exc)
            return None

    def _fetch_nowcast(
        self,
        district_id: str,
        api_key: str,
        url: str,
        auth_header: str,
        _jwt_token: str | None = None,
    ) -> dict | None:
        """
        GET district-wise nowcast from IMD districtnowcast.

        Official parameter: ?id=<numericDistrictId>
        Returns None if the request fails (nowcast is optional).
        """
        params = {"id": district_id}
        try:
            return self._get(
                url, params=params, api_key=api_key,
                auth_header=auth_header, label="nowcast",
                _jwt_token=_jwt_token,
            )
        except (IMDFetchError, IMDParseError) as exc:
            logger.warning("IMD nowcast fetch failed (non-fatal): %s", exc)
            return None

    def _get(
        self,
        url: str,
        params: dict,
        api_key: str,
        auth_header: str,
        label: str,
        _jwt_token: str | None = None,
    ) -> dict:
        """
        Execute a GET request to the IMD API with both required auth headers.

        Authentication (both headers required per IMD specification):
            X-API-KEY (or IMD_AUTH_HEADER): the production API key
            Authorization: Bearer <JWT access token>

        The JWT is obtained and cached by imd_auth.get_access_token().
        If the server returns 401, the cached token is invalidated and one
        retry is attempted (handles server-side token revocation gracefully).

        Neither the API key nor the JWT is ever logged or placed in the URL.

        Parameters
        ----------
        _jwt_token : str | None
            Optional pre-supplied JWT for unit tests.  When None (the default
            production path), the JWT is obtained from imd_auth.get_access_token().
            Tests pass a dummy string here to avoid needing real credentials.

        Raises
        ------
        IMDFetchError  : on HTTP error status or connection/timeout failure.
        IMDParseError  : if the response body is not valid JSON.
        IMDAuthError   : if a JWT cannot be obtained (production path only).
        """
        return self._get_with_retry(
            url=url,
            params=params,
            api_key=api_key,
            auth_header=auth_header,
            label=label,
            allow_retry=True,
            _jwt_token=_jwt_token,
        )

    def _get_with_retry(
        self,
        url: str,
        params: dict,
        api_key: str,
        auth_header: str,
        label: str,
        allow_retry: bool,
        _jwt_token: str | None = None,
    ) -> dict:
        """
        Internal GET implementation with optional single 401 retry.

        Parameters
        ----------
        _jwt_token : str | None
            When provided, this token is used directly and imd_auth is
            not called.  This allows low-level tests to exercise HTTP
            error paths without supplying real IMD credentials.
            In production this is always None; the auth module supplies
            the token.
        """
        # Obtain JWT: use the supplied test token, or fetch from auth module
        if _jwt_token is not None:
            jwt = _jwt_token
        else:
            jwt = get_access_token()

        try:
            response = requests.get(
                url,
                params=params,
                headers={
                    auth_header: api_key,          # X-API-KEY (or configured name)
                    "Authorization": f"Bearer {jwt}",  # JWT Bearer token
                    "Accept": "application/json",
                    # jwt value is intentionally not logged anywhere
                },
                timeout=HTTP_TIMEOUT_SECONDS,
            )
        except requests.exceptions.Timeout:
            raise IMDFetchError(
                f"IMD {label} request timed out after {HTTP_TIMEOUT_SECONDS}s."
            )
        except requests.exceptions.ConnectionError as exc:
            raise IMDFetchError(
                f"IMD {label} connection error: {type(exc).__name__}"
            )
        except requests.exceptions.RequestException as exc:
            raise IMDFetchError(
                f"IMD {label} request error: {type(exc).__name__}"
            )

        # ── Handle 401: token may have been revoked server-side ────────────
        if response.status_code == 401 and allow_retry and _jwt_token is None:
            # Only auto-retry in production mode (not test mode with _jwt_token)
            logger.warning(
                "IMD %s returned 401. "
                "This means either: (a) the JWT was accepted but the API key is "
                "wrong/unwhitelisted, or (b) the JWT was rejected. "
                "Invalidating cached JWT and retrying once with a fresh token.",
                label,
            )
            invalidate_token()
            return self._get_with_retry(
                url=url,
                params=params,
                api_key=api_key,
                auth_header=auth_header,
                label=label,
                allow_retry=False,
                _jwt_token=None,  # fetch fresh token from auth module
            )

        if not response.ok:
            # Log sanitized diagnostic — never log the key or JWT value.
            sanitized_body = response.text[:200].replace(
                api_key, "[REDACTED]"
            ) if response.text else "(empty body)"
            logger.error(
                "IMD %s returned HTTP %s. "
                "Auth header used: '%s'. "
                "Request params (no credentials): %s. "
                "Sanitized response body: %s. "
                "If status is 401/403: verify API key, JWT credentials, "
                "and that the server IP is whitelisted by IMD.",
                label,
                response.status_code,
                auth_header,
                {k: v for k, v in params.items()},
                sanitized_body,
            )
            raise IMDFetchError(
                f"IMD {label} returned HTTP {response.status_code}. "
                f"See server logs for sanitized diagnostic."
            )

        try:
            return response.json()
        except ValueError as exc:
            raise IMDParseError(
                f"IMD {label} response is not valid JSON: {exc}"
            )
