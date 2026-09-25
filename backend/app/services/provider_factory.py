"""
Weather Provider Factory
========================
Single point of provider selection for the entire backend.

The route layer calls get_provider() to obtain the active WeatherProvider.
Routes never import DemoWeatherProvider or IMDWeatherProvider directly.

Provider selection
------------------
The active provider is chosen by the WEATHER_PROVIDER environment variable.

  WEATHER_PROVIDER=demo    → DemoWeatherProvider  (default)
  WEATHER_PROVIDER=imd     → IMDWeatherProvider   (not yet implemented)

The default is "demo" — the application works with no .env file at all.

How to set the provider
-----------------------
  Windows PowerShell:
    $env:WEATHER_PROVIDER = "demo"
    uvicorn app.main:app --reload

  Linux / macOS:
    WEATHER_PROVIDER=demo uvicorn app.main:app --reload

  .env file (optional — requires python-dotenv to auto-load):
    WEATHER_PROVIDER=demo

⚠  Never put API keys or credentials in this file or in source code.
   Use environment variables for all secrets.

TODO (caching)
--------------
A lightweight cache (e.g. functools.lru_cache, cachetools TTLCache,
or a Redis client) should be inserted here — between get_provider()
and the actual provider call — once the IMD integration is active.
This avoids hitting the IMD API on every request and respects any
rate limits specified in the official IMD API documentation.
"""

import os

from app.services.weather_provider import WeatherProvider

# ---------------------------------------------------------------------------
# Registry — maps the WEATHER_PROVIDER string to a provider class.
# Add new providers here; nothing else in the codebase needs to change.
# ---------------------------------------------------------------------------
_PROVIDER_KEY_DEMO = "demo"
_PROVIDER_KEY_IMD  = "imd"

# Default if WEATHER_PROVIDER env var is absent or empty.
_DEFAULT_PROVIDER_KEY = _PROVIDER_KEY_DEMO

# Lazy registry — providers are imported only when requested so the
# application starts without errors even if optional dependencies
# (e.g. an IMD SDK) are not installed.
_REGISTRY: dict[str, type] = {}


def _build_registry() -> dict[str, type]:
    """Populate the registry on first use."""
    from app.services.weather_service import DemoWeatherProvider
    from app.services.imd_weather_provider import IMDWeatherProvider

    return {
        _PROVIDER_KEY_DEMO: DemoWeatherProvider,
        _PROVIDER_KEY_IMD:  IMDWeatherProvider,
    }


def get_provider() -> WeatherProvider:
    """
    Return a WeatherProvider instance based on the WEATHER_PROVIDER
    environment variable.

    Returns
    -------
    WeatherProvider
        An instance of the configured provider class.

    Raises
    ------
    ValueError
        If WEATHER_PROVIDER is set to an unrecognised value.

    Examples
    --------
    >>> provider = get_provider()          # → DemoWeatherProvider()
    >>> response = provider.get_weather(LocationQuery(city="Hyderabad"))
    """
    global _REGISTRY
    if not _REGISTRY:
        _REGISTRY = _build_registry()

    key = os.getenv("WEATHER_PROVIDER", _DEFAULT_PROVIDER_KEY).strip().lower()

    if key not in _REGISTRY:
        supported = sorted(_REGISTRY.keys())
        raise ValueError(
            f"Unknown WEATHER_PROVIDER='{key}'. "
            f"Supported values: {supported}. "
            f"Defaulting to '{_DEFAULT_PROVIDER_KEY}' if this variable is unset."
        )

    provider_class = _REGISTRY[key]
    return provider_class()
