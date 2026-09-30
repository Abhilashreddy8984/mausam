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

#: IMD 7-day city forecast endpoint (lat/lon based)
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
# Validation helper
# ---------------------------------------------------------------------------

def require_imd_config() -> None:
    """
    Raise ConfigurationError if the minimum IMD configuration is absent.

    Call this at the top of IMDWeatherProvider.get_weather() before
    making any HTTP request.

    Raises
    ------
    ConfigurationError
        If IMD_API_KEY or IMD_CURRENT_WX_URL is not set.
    """
    missing: list[str] = []
    if not IMD_API_KEY:
        missing.append("IMD_API_KEY")
    if not IMD_CURRENT_WX_URL:
        missing.append("IMD_CURRENT_WX_URL")

    if missing:
        raise ConfigurationError(
            f"IMD provider is selected (WEATHER_PROVIDER=imd) but the "
            f"following required environment variables are not set: "
            f"{missing}. "
            f"Set them in backend/.env or as OS environment variables. "
            f"See backend/.env.example for a template. "
            f"Do NOT hard-code credentials in source code."
        )
