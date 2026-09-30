"""
Weather Provider Factory
========================
Single point of provider selection for the entire backend.

The route layer calls get_provider() to obtain the active WeatherProvider.
Routes never import DemoWeatherProvider or IMDWeatherProvider directly.

Provider selection
------------------
The active provider is chosen by the WEATHER_PROVIDER environment variable,
which is loaded from backend/.env (via settings.py) or from the OS env.

  WEATHER_PROVIDER=demo    → DemoWeatherProvider  (default, no credentials)
  WEATHER_PROVIDER=imd     → IMDWeatherProvider   (requires IMD credentials)

Default
-------
"demo" — the application works with no .env file at all.

Security
--------
Never put API keys or credentials in this file or in source code.
Use environment variables (see backend/.env.example for a template).

Configuration error behaviour
------------------------------
If WEATHER_PROVIDER=imd but IMD_API_KEY / IMD_CURRENT_WX_URL are absent,
get_provider() raises ConfigurationError with an actionable message.
This is intentional — we must never silently return demo data when the
operator explicitly requested live IMD data.

TODO (caching)
--------------
A lightweight cache (e.g. cachetools TTLCache) should be inserted between
get_provider() and the actual provider.get_weather() call once IMD is active.
Cache TTL should match the IMD API refresh rate from the official docs.
"""

from app.config.settings import (
    WEATHER_PROVIDER,
    ConfigurationError,
    require_imd_config,
)
from app.services.weather_provider import WeatherProvider

# ---------------------------------------------------------------------------
# Registry keys
# ---------------------------------------------------------------------------
_KEY_DEMO = "demo"
_KEY_IMD  = "imd"

_DEFAULT_KEY = _KEY_DEMO

# Lazy registry — providers are imported only when requested.
# This means the app starts cleanly even if optional dependencies
# (e.g. requests) are not yet installed in the current environment.
_REGISTRY: dict[str, type] = {}


def _build_registry() -> dict[str, type]:
    """Populate the registry on first use."""
    from app.services.weather_service import DemoWeatherProvider
    from app.services.imd_weather_provider import IMDWeatherProvider

    return {
        _KEY_DEMO: DemoWeatherProvider,
        _KEY_IMD:  IMDWeatherProvider,
    }


def get_provider() -> WeatherProvider:
    """
    Return a WeatherProvider instance for the currently configured provider.

    Reads WEATHER_PROVIDER from settings (already loaded from .env by
    settings.py at import time).

    Returns
    -------
    WeatherProvider instance ready to call .get_weather(location).

    Raises
    ------
    ConfigurationError
        If WEATHER_PROVIDER=imd but required IMD credentials are absent.
    ValueError
        If WEATHER_PROVIDER is set to an unrecognised value.
    """
    global _REGISTRY
    if not _REGISTRY:
        _REGISTRY = _build_registry()

    key = WEATHER_PROVIDER  # already lowercased + stripped in settings.py

    if key not in _REGISTRY:
        supported = sorted(_REGISTRY.keys())
        raise ValueError(
            f"Unknown WEATHER_PROVIDER='{key}'. "
            f"Supported values: {supported}. "
            f"Set WEATHER_PROVIDER=demo to use demo data without credentials."
        )

    # ── IMD-specific pre-flight check ──────────────────────────────────────
    # Validate that all required IMD environment variables are present
    # BEFORE instantiating the provider, so callers receive a clear
    # ConfigurationError rather than a cryptic AttributeError or HTTP 401.
    if key == _KEY_IMD:
        require_imd_config()  # raises ConfigurationError if key/URL missing

    return _REGISTRY[key]()
