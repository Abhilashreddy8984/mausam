"""
Application Settings
====================
Single place for all environment-variable configuration.

python-dotenv is used so that a .env file in the backend/ directory
is loaded automatically when the application starts — no manual
export commands needed during development.

Rules
-----
- All secrets (API keys, base URLs) are read from environment variables.
- No secret value is ever stored in this file.
- Default values are safe to expose in source control (they contain
  no credentials).
- If a required secret is missing when a non-demo provider is selected,
  the application raises a clear ConfigurationError rather than silently
  using fake data.

.env file
---------
Create backend/.env (already git-ignored) and populate it:

    WEATHER_PROVIDER=demo
    IMD_API_KEY=your_key_here
    IMD_CURRENT_WX_URL=https://mausam.imd.gov.in/api/current_wx_api.php
    IMD_CITY_FORECAST_URL=https://city.imd.gov.in/api/cityweather_loc.php
    IMD_NOWCAST_URL=https://mausam.imd.gov.in/api/nowcast_district_api.php
    IMD_WARNINGS_URL=https://mausam.imd.gov.in/api/warnings_district_api.php

See backend/.env.example for a template with placeholder values.
"""

import os
from pathlib import Path

# ---------------------------------------------------------------------------
# Load .env file if present (development convenience)
# ---------------------------------------------------------------------------
# python-dotenv is loaded here — once — before any settings are read.
# If python-dotenv is not installed or .env does not exist, the app still
# works correctly using OS environment variables or defaults.
try:
    from dotenv import load_dotenv

    # Look for .env in backend/ (one level up from app/config/)
    _backend_dir = Path(__file__).resolve().parent.parent.parent
    _env_path = _backend_dir / ".env"
    if _env_path.exists():
        load_dotenv(dotenv_path=_env_path)
except ImportError:
    # python-dotenv not installed — that is fine; use OS env vars only.
    pass


# ---------------------------------------------------------------------------
# Custom exception for missing required configuration
# ---------------------------------------------------------------------------

class ConfigurationError(Exception):
    """
    Raised when a required environment variable is absent or empty
    while a non-demo provider has been explicitly requested.

    Never raised in demo mode — the demo provider has no credentials.
    """


# ---------------------------------------------------------------------------
# Provider selection
# ---------------------------------------------------------------------------

#: Active weather provider.  "demo" works with no credentials.
WEATHER_PROVIDER: str = os.getenv("WEATHER_PROVIDER", "demo").strip().lower()


# ---------------------------------------------------------------------------
# IMD API configuration
# ---------------------------------------------------------------------------
# All values below are read from environment variables.
# None defaults mean "not configured" — the IMD provider will raise
# ConfigurationError at call time if a required value is missing.

#: IMD API key — required when WEATHER_PROVIDER=imd.
#: NEVER log or print this value.
IMD_API_KEY: str | None = os.getenv("IMD_API_KEY") or None

#: IMD current weather endpoint
IMD_CURRENT_WX_URL: str | None = (
    os.getenv("IMD_CURRENT_WX_URL") or None
)

#: IMD 7-day city forecast endpoint (station-code based)
IMD_CITY_FORECAST_URL: str | None = (
    os.getenv("IMD_CITY_FORECAST_URL") or None
)

#: IMD district-wise nowcast endpoint
IMD_NOWCAST_URL: str | None = (
    os.getenv("IMD_NOWCAST_URL") or None
)

#: IMD district-wise warnings endpoint
IMD_WARNINGS_URL: str | None = (
    os.getenv("IMD_WARNINGS_URL") or None
)

# ---------------------------------------------------------------------------
# HTTP client settings
# ---------------------------------------------------------------------------

#: Timeout (seconds) for outbound API requests.
#: Keep short so backend failures are caught quickly and the app
#: can respond with an informative error rather than hanging.
HTTP_TIMEOUT_SECONDS: int = int(os.getenv("HTTP_TIMEOUT_SECONDS", "10"))

# ---------------------------------------------------------------------------
# IMD station / district identifier configuration
# ---------------------------------------------------------------------------
# The official IMD API (api.imd.gov.in/api/v1/) identifies locations
# by numeric station codes and district/object IDs — NOT by city name.
#
# current_wx   → requires ?id=StationId   (e.g. "42867" for Hyderabad AP)
# cityforecast → requires ?id=StationCode (e.g. "42182")
# districtnowcast  → requires ?id=numericDistrictId
# districtwarning  → requires ?id=numericObjId
#
# Set these in backend/.env for the location you want to serve.
# Do NOT hard-code values here — they belong in environment variables.

#: Station ID for current_wx queries (numeric IMD station identifier).
#: Example for Hyderabad (Begumpet): "42867"
IMD_STATION_ID: str | None = os.getenv("IMD_STATION_ID") or None

#: Station code for cityforecast queries.
#: May differ from IMD_STATION_ID.
#: Example for Hyderabad: "42182"
IMD_FORECAST_STATION_CODE: str | None = (
    os.getenv("IMD_FORECAST_STATION_CODE") or None
)

#: Numeric district/object ID for districtwarning queries.
#: See https://api.imd.gov.in/api/v1/districtwarning for available IDs.
IMD_DISTRICT_WARNING_ID: str | None = (
    os.getenv("IMD_DISTRICT_WARNING_ID") or None
)

#: Numeric district ID for districtnowcast queries.
#: See https://api.imd.gov.in/api/v1/districtnowcast for available IDs.
IMD_DISTRICT_NOWCAST_ID: str | None = (
    os.getenv("IMD_DISTRICT_NOWCAST_ID") or None
)

# ---------------------------------------------------------------------------
# IMD authentication header configuration
# ---------------------------------------------------------------------------
# The exact HTTP header name used to pass the API key is not confirmed
# from the official public documentation.  It is made configurable here
# so it can be updated without a code change once confirmed with IMD.
#
# Default: "X-Api-Key"  (common convention for government REST APIs)
# Override via environment variable:  IMD_AUTH_HEADER=<HeaderName>
IMD_AUTH_HEADER: str = os.getenv("IMD_AUTH_HEADER", "X-Api-Key").strip()

# ---------------------------------------------------------------------------
# IMD OAuth / JWT credentials
# ---------------------------------------------------------------------------
# IMD requires a Bearer JWT token on every data request in addition to
# the API key.  The JWT is obtained by POSTing to the IMD OAuth endpoint
# with the registered account email and password.
#
# OAuth endpoint: https://api.imd.gov.in/api/oauth/token.php
#
# These values are read ONLY from environment variables.
# NEVER hard-code them in source code.

#: Registered IMD account email — used to obtain JWT access tokens.
#: NEVER log or print this value.
IMD_EMAIL: str | None = os.getenv("IMD_EMAIL") or None

#: Registered IMD account password — used to obtain JWT access tokens.
#: NEVER log or print this value.
IMD_PASSWORD: str | None = os.getenv("IMD_PASSWORD") or None

#: IMD OAuth token endpoint.
#: Override only if IMD officially changes this URL.
IMD_TOKEN_URL: str = os.getenv(
    "IMD_TOKEN_URL",
    "https://api.imd.gov.in/api/oauth/token.php",
).strip()


# ---------------------------------------------------------------------------
# Validation helper
# ---------------------------------------------------------------------------

def require_imd_config() -> None:
    """
    Raise ConfigurationError if the minimum IMD configuration is absent.

    Call this at the top of IMDWeatherProvider.get_weather() before
    making any HTTP request.

    Required:
      IMD_API_KEY      — API key sent as X-API-KEY header
      IMD_CURRENT_WX_URL — base URL for current weather endpoint
      IMD_STATION_ID   — numeric station identifier
      IMD_EMAIL        — IMD account email (for JWT generation)
      IMD_PASSWORD     — IMD account password (for JWT generation)

    Raises
    ------
    ConfigurationError
        If any required environment variable is absent.
    """
    missing: list[str] = []
    if not IMD_API_KEY:
        missing.append("IMD_API_KEY")
    if not IMD_CURRENT_WX_URL:
        missing.append("IMD_CURRENT_WX_URL")
    if not IMD_STATION_ID:
        missing.append(
            "IMD_STATION_ID (numeric IMD station ID required by current_wx, "
            "e.g. '42867' for Hyderabad Begumpet — see "
            "https://api.imd.gov.in/api/v1/current_wx for available IDs)"
        )
    if not IMD_EMAIL:
        missing.append("IMD_EMAIL (registered IMD account email for JWT auth)")
    if not IMD_PASSWORD:
        missing.append("IMD_PASSWORD (registered IMD account password for JWT auth)")

    if missing:
        raise ConfigurationError(
            f"IMD provider is selected (WEATHER_PROVIDER=imd) but the "
            f"following required environment variables are not set: "
            f"{missing}. "
            f"Set them in backend/.env or as OS environment variables. "
            f"See backend/.env.example for a template. "
            f"Do NOT hard-code credentials in source code."
        )
