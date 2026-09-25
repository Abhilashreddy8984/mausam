"""
IMD Weather Provider (Stub)
============================
Placeholder implementation of WeatherProvider for the official
India Meteorological Department (IMD) data source.

Current status: NOT IMPLEMENTED
--------------------------------
This class raises NotImplementedError on every call.
It exists only to:
  1. Confirm the WeatherProvider interface is correct.
  2. Reserve the integration point for future development.
  3. Document exactly what is needed to complete the integration.

How to activate this provider
------------------------------
  1. Obtain official IMD API access credentials through the appropriate
     authorization process (contact IMD / MoES for details).
  2. Store credentials as environment variables — NEVER in source code:
       IMD_API_KEY=<your_key>
       IMD_API_BASE_URL=<official_endpoint>
  3. Implement get_weather() below using the officially documented
     IMD API schema once you have verified the real response format.
  4. Register "imd" in provider_factory.py (already stubbed).
  5. Set WEATHER_PROVIDER=imd in your environment.

⚠  Do NOT invent or hard-code any IMD endpoint URL or schema here
   until the official API documentation has been reviewed.

TODO (caching)
--------------
The official IMD API guidance should be consulted for appropriate
cache TTL values.  A caching layer should be inserted between
provider_factory.get_provider() and the IMD HTTP call in this class
to avoid redundant requests and respect any IMD rate limits.

Architecture reminder
---------------------
  IMDWeatherProvider.get_weather(location)
       ↓
  [future cache layer]
       ↓
  IMD API HTTP call
       ↓
  Map IMD response → WeatherResponse
       ↓
  RankingService.rank(cards, persona)
       ↓
  Flutter homepage
"""

from app.models.weather import WeatherResponse
from app.services.weather_provider import LocationQuery, WeatherProvider


class IMDWeatherProvider(WeatherProvider):
    """
    Future integration point for the official IMD weather API.

    Do NOT use this provider in production until:
      - Official IMD API access has been authorized.
      - Credentials are securely stored in environment variables.
      - The IMD response schema has been verified and mapped.
    """

    def get_weather(self, location: LocationQuery) -> WeatherResponse:
        """
        Fetch live weather data from the official IMD API.

        NOT IMPLEMENTED — raises NotImplementedError until configured.

        Parameters
        ----------
        location : LocationQuery with city name and optional coordinates.

        Raises
        ------
        NotImplementedError
            Always, until this provider is fully implemented.
        """
        raise NotImplementedError(
            "IMD provider is not configured yet. "
            "To enable it: obtain official IMD API credentials, "
            "set IMD_API_KEY and IMD_API_BASE_URL environment variables, "
            "implement get_weather() in imd_weather_provider.py, "
            "then set WEATHER_PROVIDER=imd in your environment. "
            "See the docstring at the top of this file for full instructions."
        )
