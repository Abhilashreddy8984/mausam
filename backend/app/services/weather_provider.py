"""
Weather Provider Interface
==========================
Defines the contract that every weather data source must satisfy.

Any class that subclasses WeatherProvider and implements get_weather()
can be plugged into the route layer without changing routes, ranking,
or the Flutter application.

Current implementations
-----------------------
  DemoWeatherProvider   — hard-coded demo data (default for development)
  IMDWeatherProvider    — stub; raises NotImplementedError until configured

Future implementations (examples)
----------------------------------
  OpenWeatherMapProvider
  IMDLiveProvider  (once official API credentials are obtained)

Architecture
------------
  WeatherProvider
       ↓
  WeatherResponse  (app/models/weather.py)
       ↓
  RankingService   (app/services/ranking_service.py)
       ↓
  Personalized Homepage  (/homepage endpoint)
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Optional

from app.models.weather import WeatherResponse


# ---------------------------------------------------------------------------
# LocationQuery — optional location context for a weather request.
#
# City name is sufficient for the current MVP.
# latitude / longitude are optional and will be used once:
#   - GPS coordinates flow through from the Flutter location service
#   - The active weather provider supports coordinate-based lookups
#
# No fields are required — callers may supply city only, coordinates only,
# or both (provider decides which to prefer).
# ---------------------------------------------------------------------------
@dataclass
class LocationQuery:
    """
    Encapsulates all location information for a weather request.

    Attributes
    ----------
    city      : Human-readable city name, e.g. "Hyderabad".
                Used as the primary lookup key in the current MVP.
    latitude  : Optional decimal latitude, e.g. 17.385.
    longitude : Optional decimal longitude, e.g. 78.4867.

    Usage
    -----
    # City only (current usage)
    query = LocationQuery(city="Hyderabad")

    # Future: with GPS coordinates
    query = LocationQuery(city="Hyderabad", latitude=17.385, longitude=78.4867)
    """

    city: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None


# ---------------------------------------------------------------------------
# WeatherProvider — the interface every provider must implement.
# ---------------------------------------------------------------------------
class WeatherProvider(ABC):
    """
    Abstract base class for all weather data providers.

    Subclasses MUST implement get_weather().

    The route layer depends only on this interface.  It never imports
    DemoWeatherProvider or IMDWeatherProvider directly, which means:
      - swapping providers requires no route changes
      - adding a new provider requires no route changes
      - the Flutter API contract is never broken by a provider change
    """

    @abstractmethod
    def get_weather(self, location: LocationQuery) -> WeatherResponse:
        """
        Fetch weather data for the given location.

        Parameters
        ----------
        location : LocationQuery with at minimum a city name.
                   Providers may also use latitude/longitude if available.

        Returns
        -------
        WeatherResponse populated with current weather data and cards.

        Notes
        -----
        Implementations should:
          - Always return a valid WeatherResponse (never return None).
          - Set the `source` field to identify the provider.
          - Fall back gracefully if the primary lookup fails.
        """
        ...
