"""
API Routes
==========
All HTTP endpoints for the Mausam backend are defined here.

The route layer depends only on:
  - WeatherProvider interface  (via provider_factory.get_provider)
  - RankingService
  - WeatherResponse model

It does NOT import DemoWeatherProvider or IMDWeatherProvider directly.
Swapping the active weather provider requires no changes here.

Architecture
------------
  provider_factory.get_provider()
       ↓
  WeatherProvider.get_weather(LocationQuery)
       ↓
  WeatherResponse
       ↓
  RankingService.rank(cards, persona)
       ↓
  Ranked WeatherResponse  →  Flutter

Endpoints
---------
GET /health                               — service liveness check
GET /weather?city=Hyderabad               — full weather data (unranked)
GET /homepage?persona=farmer&city=Hyderabad — personalized ranked homepage

TODO (caching)
--------------
A caching layer should be added between get_provider() and the actual
provider call once the IMD integration is active.  The appropriate
cache TTL should be determined from the official IMD API documentation.
"""

from fastapi import APIRouter, HTTPException, Query

from app.models.weather import WeatherResponse
from app.services.provider_factory import get_provider
from app.services.ranking_service import RankingService, SUPPORTED_PERSONAS
from app.services.weather_provider import LocationQuery

router = APIRouter()

# Single shared ranking service instance
_ranking_service = RankingService()


# --------------------------------------------------------------------------- #
# GET /health                                                                  #
# --------------------------------------------------------------------------- #
@router.get("/health")
def health_check():
    """
    Liveness probe.
    Returns a simple JSON object confirming the service is running.
    """
    return {"status": "ok", "service": "mausam-backend"}


# --------------------------------------------------------------------------- #
# GET /weather                                                                 #
# --------------------------------------------------------------------------- #
@router.get("/weather", response_model=WeatherResponse)
def get_weather(
    city: str = Query(
        default="Hyderabad",
        description="City name to fetch weather for",
    ),
):
    """
    Returns full weather data for the requested city.

    Cards are returned in their default (unranked) order.
    Use /homepage with a persona to get ranked cards.

    The `source` field in the response identifies which provider
    produced the data ("demo" for demo data, "IMD" for live data).

    Example
    -------
    GET /weather?city=Hyderabad
    """
    provider = get_provider()
    location = LocationQuery(city=city)
    weather = provider.get_weather(location)
    return weather


# --------------------------------------------------------------------------- #
# GET /homepage                                                                #
# --------------------------------------------------------------------------- #
@router.get("/homepage", response_model=WeatherResponse)
def get_homepage(
    persona: str = Query(
        ...,
        description=(
            f"User persona. Supported values: {sorted(SUPPORTED_PERSONAS)}"
        ),
    ),
    city: str = Query(default="Hyderabad", description="City name"),
):
    """
    Returns personalized weather data for the given persona and city.

    All weather cards are always returned — personalization only changes
    their ORDER, not their availability.

    The `source` field in the response identifies the weather provider.

    Example
    -------
    GET /homepage?persona=farmer&city=Hyderabad
    """
    # Fetch raw weather data through the active provider
    provider = get_provider()
    location = LocationQuery(city=city)
    weather = provider.get_weather(location)

    # Rank cards for this persona
    try:
        ranked_cards = _ranking_service.rank(weather.cards, persona)
    except ValueError as exc:
        raise HTTPException(
            status_code=400,
            detail={
                "error": str(exc),
                "supported_personas": sorted(SUPPORTED_PERSONAS),
            },
        ) from exc

    # Return ranked response — preserve source from provider
    return WeatherResponse(
        city=weather.city,
        temperature=weather.temperature,
        humidity=weather.humidity,
        wind_speed=weather.wind_speed,
        condition=weather.condition,
        cards=ranked_cards,
        source=weather.source,
    )
