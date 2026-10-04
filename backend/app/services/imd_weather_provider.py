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
from app.services.imd_mapper import map_current_weather
from app.services.weather_provider import LocationQuery, WeatherProvider

logger = logging.getLogger(__name__)


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

        # ── 4. Map raw JSON → WeatherResponse ──────────────────────────────
        return map_current_weather(
            current_json=current_json,
            forecast_json=forecast_json,
            warnings_json=warnings_json,
            nowcast_json=nowcast_json,
        )

    # ---------------------------------------------------------------------- #
    # Private HTTP helpers                                                     #
    # ---------------------------------------------------------------------- #

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
