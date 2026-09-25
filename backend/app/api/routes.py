"""
API Routes
==========
All HTTP endpoints for the Mausam backend are defined here.

The route layer:
  - Fetches weather data through the active WeatherProvider (via factory).
  - Builds a RankingContext from the weather response + server time.
  - Passes cards + persona + context to RankingService.
  - Returns the ranked WeatherResponse to the Flutter client.

The route layer does NOT know which provider is active (Demo or IMD).
Swapping providers requires zero changes here.

Architecture
------------
  provider_factory.get_provider()
       ↓
  WeatherProvider.get_weather(LocationQuery)
       ↓
  WeatherResponse  +  server time  →  RankingContext
       ↓
  RankingService.rank(cards, persona, context)
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

from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, Query

from app.models.ranking_context import RankingContext
from app.models.weather import WeatherResponse
from app.services.provider_factory import get_provider
from app.services.ranking_service import RankingService, SUPPORTED_PERSONAS
from app.services.weather_provider import LocationQuery

router = APIRouter()

# Single shared ranking service instance — stateless, safe to share
_ranking_service = RankingService()


def _build_context(
    persona: str,
    city: str,
    weather: WeatherResponse,
) -> RankingContext:
    """
    Build a RankingContext from the API request + weather response.

    Uses the server's current local hour for time-of-day adjustments.
    All weather fields are taken directly from the WeatherResponse —
    no values are invented or assumed.

    The WeatherResponse does not currently carry rain_probability,
    visibility_km, uv_index, or aqi as top-level fields (those are
    inside WeatherCard values as strings).  We pass None for these
    and the ranking service skips those context adjustments gracefully.

    When the backend is connected to a real API that provides these
    as structured numbers, they can be added to WeatherResponse and
    wired in here — no other changes needed.
    """
    current_hour = datetime.now(timezone.utc).hour  # use UTC for consistency

    return RankingContext(
        persona=persona,
        city=city,
        current_hour=current_hour,
        # Structured weather fields available from WeatherResponse:
        temperature_c=weather.temperature,
        humidity_pct=weather.humidity,
        wind_speed_kmh=weather.wind_speed,
        condition=weather.condition,
        # Fields not yet in WeatherResponse as top-level numbers:
        # (set to None → ranking service skips those context checks)
        feels_like_c=None,
        rain_probability=None,
        visibility_km=None,
        uv_index=None,
        aqi=None,
    )


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

    The `source` field identifies which provider produced the data
    ("demo" for demo data, "IMD" for live data).

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

    Ranking uses an additive scoring model:
      score = persona_base + weather_context_boost + time_of_day_boost

    The `source` field identifies the weather provider.
    The `ranking_reasons` field on each card (development only) explains
    why it received its score — Flutter ignores this field.

    Example
    -------
    GET /homepage?persona=farmer&city=Hyderabad
    """
    # ── 1. Fetch weather data ──────────────────────────────────
    provider = get_provider()
    location = LocationQuery(city=city)
    weather = provider.get_weather(location)

    # ── 2. Build ranking context ───────────────────────────────
    context = _build_context(persona, city, weather)

    # ── 3. Rank cards ──────────────────────────────────────────
    try:
        ranked_cards = _ranking_service.rank(weather.cards, persona, context)
    except ValueError as exc:
        raise HTTPException(
            status_code=400,
            detail={
                "error": str(exc),
                "supported_personas": sorted(SUPPORTED_PERSONAS),
            },
        ) from exc

    # ── 4. Return ranked response ──────────────────────────────
    return WeatherResponse(
        city=weather.city,
        temperature=weather.temperature,
        humidity=weather.humidity,
        wind_speed=weather.wind_speed,
        condition=weather.condition,
        cards=ranked_cards,
        source=weather.source,
    )
