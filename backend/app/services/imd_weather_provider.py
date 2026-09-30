"""
IMD Weather Provider
====================
Implements WeatherProvider using the official India Meteorological
Department (IMD) API endpoints.

Current status
--------------
The HTTP calls are fully implemented and ready.
The provider raises ConfigurationError if credentials are absent —
it does NOT silently return fake data when IMD is selected.

To activate:
  1. Obtain official IMD API credentials (IMD / MoES authorization).
  2. Set environment variables in backend/.env:
         WEATHER_PROVIDER=imd
         IMD_API_KEY=your_key_here
         IMD_CURRENT_WX_URL=https://mausam.imd.gov.in/api/current_wx_api.php
         IMD_CITY_FORECAST_URL=https://city.imd.gov.in/api/cityweather_loc.php
         IMD_NOWCAST_URL=https://mausam.imd.gov.in/api/nowcast_district_api.php
         IMD_WARNINGS_URL=https://mausam.imd.gov.in/api/warnings_district_api.php
  3. Start the backend — no code changes required.

Architecture
------------
  IMDWeatherProvider.get_weather(location)
       ↓
  _fetch_current()          ← HTTP GET with API key header
  _fetch_forecast()         ← HTTP GET (optional, lat/lon required)
  _fetch_warnings()         ← HTTP GET (optional)
  _fetch_nowcast()          ← HTTP GET (optional)
       ↓
  imd_mapper.map_current_weather(current, forecast, warnings, nowcast)
       ↓
  WeatherResponse           ← same model used by DemoWeatherProvider
       ↓
  RankingService / Routes / Flutter

Security rules
--------------
- API key is read from settings.py (environment variable only).
- The key is passed in an HTTP header — NEVER in the URL.
- The key is NEVER logged, even at DEBUG level.
- If a request fails, the error is logged without exposing the key.

Failure modes
-------------
- ConfigurationError  : credentials absent when IMD is selected.
- IMDFetchError       : HTTP error or timeout from IMD API.
- IMDParseError       : IMD returned unexpected / malformed JSON.

All three are caught in get_weather() and re-raised so the route layer
can return a clean 503 / 502 response to Flutter rather than a 500.
"""

import logging

import requests

from app.config.settings import (
    HTTP_TIMEOUT_SECONDS,
    IMD_CITY_FORECAST_URL,
    IMD_CURRENT_WX_URL,
    IMD_NOWCAST_URL,
    IMD_WARNINGS_URL,
    ConfigurationError,
    require_imd_config,
)
from app.models.weather import WeatherResponse
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
    that is structurally identical to what DemoWeatherProvider returns.

    The route layer, ranking engine, and Flutter application are fully
    unaware of which provider is active.

    ⚠  Do NOT use in production until:
         - Official IMD API access has been authorized.
         - Credentials are set in environment variables (not source code).
         - Responses have been validated against the live API.
    """

    def get_weather(self, location: LocationQuery) -> WeatherResponse:
        """
        Fetch current weather + optional forecast/warnings/nowcast from IMD.

        Parameters
        ----------
        location : LocationQuery with at minimum a city name.
                   latitude/longitude are used for the forecast call when
                   available (IMD forecast API is coordinate-based).

        Returns
        -------
        WeatherResponse with source="IMD".

        Raises
        ------
        ConfigurationError
            If IMD_API_KEY or IMD_CURRENT_WX_URL is not set.
        IMDFetchError
            If any HTTP request fails or times out.
        IMDParseError
            If the IMD response cannot be parsed as JSON.
        """
        # ── 1. Validate configuration before any network call ──────────────
        require_imd_config()  # raises ConfigurationError if key/URL missing
        from app.config import settings as _s  # import here to pick up .env

        city    = location.city.strip()
        lat     = location.latitude
        lon     = location.longitude

        logger.info(
            "IMDWeatherProvider: fetching weather for city='%s' lat=%s lon=%s",
            city, lat, lon,
        )

        # ── 2. Fetch current weather (required) ────────────────────────────
        current_json = self._fetch_current(city, _s.IMD_API_KEY, _s.IMD_CURRENT_WX_URL)

        # ── 3. Fetch optional supplementary data (best-effort) ─────────────
        forecast_json = None
        if lat is not None and lon is not None and _s.IMD_CITY_FORECAST_URL:
            forecast_json = self._fetch_forecast(lat, lon, _s.IMD_API_KEY, _s.IMD_CITY_FORECAST_URL)

        warnings_json = None
        if _s.IMD_WARNINGS_URL:
            warnings_json = self._fetch_warnings(city, _s.IMD_API_KEY, _s.IMD_WARNINGS_URL)

        nowcast_json = None
        if _s.IMD_NOWCAST_URL:
            nowcast_json = self._fetch_nowcast(city, _s.IMD_API_KEY, _s.IMD_NOWCAST_URL)

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
        self, city: str, api_key: str, url: str
    ) -> dict:
        """
        GET current weather from IMD current_wx_api.php.

        The API key is sent as a request header — never in the URL.
        The exact header name will be confirmed when authorized access
        is obtained and the official documentation is reviewed.
        """
        params = {"city": city}
        return self._get(url, params=params, api_key=api_key, label="current weather")

    def _fetch_forecast(
        self, lat: float, lon: float, api_key: str, url: str
    ) -> dict | None:
        """
        GET 7-day forecast from IMD cityweather_loc.php.
        Returns None if the request fails (forecast is optional).
        """
        params = {"lat": str(lat), "lon": str(lon)}
        try:
            return self._get(url, params=params, api_key=api_key, label="forecast")
        except (IMDFetchError, IMDParseError) as exc:
            logger.warning("IMD forecast fetch failed (non-fatal): %s", exc)
            return None

    def _fetch_warnings(
        self, city: str, api_key: str, url: str
    ) -> dict | None:
        """
        GET district-wise warnings from IMD warnings_district_api.php.
        Returns None if the request fails (warnings are optional).
        """
        params = {"city": city}
        try:
            return self._get(url, params=params, api_key=api_key, label="warnings")
        except (IMDFetchError, IMDParseError) as exc:
            logger.warning("IMD warnings fetch failed (non-fatal): %s", exc)
            return None

    def _fetch_nowcast(
        self, city: str, api_key: str, url: str
    ) -> dict | None:
        """
        GET district-wise nowcast from IMD nowcast_district_api.php.
        Returns None if the request fails (nowcast is optional).
        """
        params = {"city": city}
        try:
            return self._get(url, params=params, api_key=api_key, label="nowcast")
        except (IMDFetchError, IMDParseError) as exc:
            logger.warning("IMD nowcast fetch failed (non-fatal): %s", exc)
            return None

    def _get(
        self,
        url: str,
        params: dict,
        api_key: str,
        label: str,
    ) -> dict:
        """
        Execute a GET request to the IMD API.

        Security: the API key is passed in the 'X-API-Key' header.
        It is NEVER logged, even on failure.

        Raises
        ------
        IMDFetchError  : on HTTP error status or connection/timeout failure.
        IMDParseError  : if the response body is not valid JSON.
        """
        # NOTE: The exact authentication header name for the IMD API will be
        # confirmed once authorized access is obtained.  'X-API-Key' is a
        # common convention; update this constant if IMD uses a different name.
        _AUTH_HEADER = "X-API-Key"

        try:
            response = requests.get(
                url,
                params=params,
                headers={
                    _AUTH_HEADER: api_key,
                    "Accept": "application/json",
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

        if not response.ok:
            # Log status code but never the response body (may contain key)
            raise IMDFetchError(
                f"IMD {label} returned HTTP {response.status_code} "
                f"for URL pattern '{url}'."
            )

        try:
            return response.json()
        except ValueError as exc:
            raise IMDParseError(
                f"IMD {label} response is not valid JSON: {exc}"
            )
