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
    latitude: float | None = None,
    longitude: float | None = None,
) -> RankingContext:
    """
    Build a RankingContext from the API request + weather response.

    Uses the server's current UTC hour for time-of-day adjustments.
    All weather fields are taken directly from WeatherResponse —
    no values are invented or assumed.

    Parameters
    ----------
    persona   : Active persona key, e.g. "farmer".
    city      : City name from the query parameter.
    weather   : WeatherResponse from the active provider.
    latitude  : Optional decimal latitude from the Flutter GPS fix.
    longitude : Optional decimal longitude from the Flutter GPS fix.
                When provided, both are stored in RankingContext so that
                future providers (e.g. IMD) can use coordinates directly.
                The current DemoWeatherProvider ignores them — this is by
                design; coordinates are carried through now so the
                architecture is ready for the IMD integration step.

    Notes
    -----
    WeatherResponse does not yet carry rain_probability, visibility_km,
    uv_index, or aqi as top-level numeric fields (those are embedded
    inside WeatherCard.value strings).  We pass None for these and the
    ranking service skips those context adjustments gracefully.
    Once a real API provides them as numbers, wire them in here —
    no other changes needed.
    """
    current_hour = datetime.now(timezone.utc).hour  # UTC for consistency

    return RankingContext(
        persona=persona,
        city=city,
        # GPS coordinates from Flutter — None when location unavailable
        latitude=latitude,
        longitude=longitude,
        current_hour=current_hour,
        # Structured weather fields available from WeatherResponse:
        temperature_c=weather.temperature,
        humidity_pct=weather.humidity,
        wind_speed_kmh=weather.wind_speed,
        condition=weather.condition,
        # Fields not yet in WeatherResponse as top-level numbers:
        # (None → ranking service skips those context checks)
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
    latitude: float | None = Query(
        default=None,
        description=(
            "Optional decimal latitude from the device GPS fix, e.g. 17.3850. "
            "When provided, stored in RankingContext for future coordinate-based "
            "provider lookups. Currently carried through but not used by "
            "DemoWeatherProvider."
        ),
    ),
    longitude: float | None = Query(
        default=None,
        description=(
            "Optional decimal longitude from the device GPS fix, e.g. 78.4867. "
            "Paired with latitude — both must be supplied or both omitted."
        ),
    ),
):
    """
    Returns personalized weather data for the given persona and city.

    All weather cards are always returned — personalization only changes
    their ORDER, not their availability.

    Ranking uses an additive scoring model:
      score = persona_base + weather_context_boost + time_of_day_boost

    Optional GPS coordinates
    ------------------------
    latitude and longitude are accepted but not yet used by the
    DemoWeatherProvider for weather lookup.  They are stored in
    RankingContext so the architecture is ready for the IMD integration
    step, where coordinates will drive the weather data fetch.

    The `source` field identifies the weather provider.
    The `ranking_reasons` field on each card (development only) explains
    why it received its score — Flutter ignores this field.

    Examples
    --------
    GET /homepage?persona=farmer&city=Hyderabad
    GET /homepage?persona=farmer&city=Hyderabad&latitude=17.3850&longitude=78.4867
    """
    # ── 1. Fetch weather data ──────────────────────────────────
    provider = get_provider()
    location = LocationQuery(city=city, latitude=latitude, longitude=longitude)
    weather = provider.get_weather(location)

    # ── 2. Build ranking context (includes GPS coordinates) ────
    context = _build_context(persona, city, weather, latitude, longitude)

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
