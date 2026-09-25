"""
API Routes
==========
All HTTP endpoints for the Mausam backend are defined here.

Endpoints
---------
GET /health                          — service liveness check
GET /weather?city=Hyderabad          — full weather data (unranked)
GET /homepage?persona=farmer&city=Hyderabad — personalized ranked homepage
"""

from fastapi import APIRouter, HTTPException, Query
from app.models.weather import WeatherResponse
from app.services.weather_service import DemoWeatherService
from app.services.ranking_service import RankingService, SUPPORTED_PERSONAS

router = APIRouter()

# Single shared instances — lightweight for the MVP
_weather_service = DemoWeatherService()
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
    city: str = Query(default="Hyderabad", description="City name to fetch weather for"),
):
    """
    Returns full weather data for the requested city.

    Cards are returned in their default (unranked) order.
    Use /homepage with a persona to get ranked cards.

    Example
    -------
    GET /weather?city=Hyderabad
    """
    weather = _weather_service.get_weather(city)
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

    Example
    -------
    GET /homepage?persona=farmer&city=Hyderabad
    """
    # Fetch raw weather data
    weather = _weather_service.get_weather(city)

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

    # Return response with ranked cards
    return WeatherResponse(
        city=weather.city,
        temperature=weather.temperature,
        humidity=weather.humidity,
        wind_speed=weather.wind_speed,
        condition=weather.condition,
        cards=ranked_cards,
    )
