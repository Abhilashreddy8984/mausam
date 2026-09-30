"""
API Routes
==========
All HTTP endpoints for the Mausam backend.

The route layer:
  - Fetches weather data through the active WeatherProvider (via factory).
  - Builds a RankingContext from the rich WeatherResponse + server time.
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
GET /health
GET /weather?city=Hyderabad
GET /homepage?persona=farmer&city=Hyderabad
GET /homepage?persona=farmer&city=Hyderabad&latitude=17.385&longitude=78.487

TODO (caching)
--------------
A caching layer should be added between get_provider() and the provider call
once the IMD integration is active. Cache TTL should come from the official
IMD API documentation.
"""

from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, Query

from app.config.settings import ConfigurationError
from app.models.ranking_context import RankingContext
from app.models.weather import WeatherResponse
from app.services.provider_factory import get_provider
from app.services.ranking_service import RankingService, SUPPORTED_PERSONAS
from app.services.weather_provider import LocationQuery

router = APIRouter()

_ranking_service = RankingService()


def _build_context(
    persona: str,
    city: str,
    weather: WeatherResponse,
    latitude: float | None = None,
    longitude: float | None = None,
) -> RankingContext:
    """
    Build a RankingContext from the API request + WeatherResponse.

    Now wires ALL numeric fields that WeatherResponse exposes into the
    context so the ranking engine can use real values from a live provider
    instead of the None placeholders it received from DemoWeatherProvider.

    DemoWeatherProvider still returns None for most of these fields —
    the ranking service handles None gracefully (skips those adjustments).
    A real IMD provider will populate them, enabling full context-aware
    ranking without any changes to the ranking engine.

    Parameters
    ----------
    persona   : Active persona key.
    city      : City from the query parameter.
    weather   : WeatherResponse from the active provider.
    latitude  : Optional GPS latitude from Flutter.
    longitude : Optional GPS longitude from Flutter.
    """
    current_hour = datetime.now(timezone.utc).hour

    return RankingContext(
        persona=persona,
        city=city,
        latitude=latitude,
        longitude=longitude,
        current_hour=current_hour,
        # ── Basic fields (always populated by DemoWeatherProvider) ─────────
        temperature_c=weather.temperature,
        humidity_pct=weather.humidity,
        wind_speed_kmh=weather.wind_speed,
        condition=weather.condition,
        # ── Rich fields (None from Demo; real values from IMD) ─────────────
        # When these are None the ranking service skips those context checks.
        # When a real provider populates them the ranking engine automatically
        # uses them — no code changes needed anywhere else.
        feels_like_c=weather.feels_like,
        rain_probability=None,  # not a top-level field in WeatherResponse yet;
                                # will be wired once IMD delivers it directly
        visibility_km=weather.visibility_km,
        uv_index=weather.uv_index,
        aqi=weather.aqi,
    )


# --------------------------------------------------------------------------- #
# GET /health                                                                  #
# --------------------------------------------------------------------------- #
@router.get("/health")
def health_check():
    """Liveness probe."""
    return {"status": "ok", "service": "mausam-backend"}


# --------------------------------------------------------------------------- #
# GET /weather                                                                 #
# --------------------------------------------------------------------------- #
@router.get("/weather", response_model=WeatherResponse)
def get_weather(
    city: str = Query(default="Hyderabad", description="City name"),
):
    """
    Returns full weather data for the requested city (unranked cards).

    The `source` field identifies the active provider ("demo" or "IMD").

    Example: GET /weather?city=Hyderabad
    """
    try:
        provider = get_provider()
    except ConfigurationError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc

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
        description=f"User persona. Supported: {sorted(SUPPORTED_PERSONAS)}",
    ),
    city: str = Query(default="Hyderabad", description="City name"),
    latitude: float | None = Query(
        default=None,
        description="Optional GPS latitude from the device, e.g. 17.3850.",
    ),
    longitude: float | None = Query(
        default=None,
        description="Optional GPS longitude from the device, e.g. 78.4867.",
    ),
):
    """
    Returns personalized weather data for the given persona and city.

    All weather cards are always returned — personalization only changes
    their ORDER, not their availability.

    Ranking formula:
      score = persona_score + weather_context_score + time_context_score

    The `source` field in the response identifies the weather provider.
    The `ranking_reasons` field on each card is for development inspection
    only — Flutter ignores it.

    Examples
    --------
    GET /homepage?persona=farmer&city=Hyderabad
    GET /homepage?persona=farmer&city=Hyderabad&latitude=17.385&longitude=78.487
    """
    # ── 1. Get provider (raises 503 if IMD is mis-configured) ─────────────
    try:
        provider = get_provider()
    except ConfigurationError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    # ── 2. Fetch weather ────────────────────────────────────────────────────
    location = LocationQuery(city=city, latitude=latitude, longitude=longitude)
    weather = provider.get_weather(location)

    # ── 3. Build ranking context (uses rich WeatherResponse fields) ─────────
    context = _build_context(persona, city, weather, latitude, longitude)

    # ── 4. Rank cards ───────────────────────────────────────────────────────
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

    # ── 5. Return ranked response ────────────────────────────────────────────
    return WeatherResponse(
        # Existing fields Flutter reads
        city=weather.city,
        temperature=weather.temperature,
        humidity=weather.humidity,
        wind_speed=weather.wind_speed,
        condition=weather.condition,
        cards=ranked_cards,
        source=weather.source,
        # Rich fields (Flutter ignores unknown fields — backward-compatible)
        district=weather.district,
        state=weather.state,
        latitude=weather.latitude,
        longitude=weather.longitude,
        feels_like=weather.feels_like,
        pressure_hpa=weather.pressure_hpa,
        wind_direction=weather.wind_direction,
        rainfall_mm=weather.rainfall_mm,
        cloud_cover_pct=weather.cloud_cover_pct,
        uv_index=weather.uv_index,
        aqi=weather.aqi,
        visibility_km=weather.visibility_km,
        observation_time=weather.observation_time,
        weather_code=weather.weather_code,
        forecast=weather.forecast,
        warnings=weather.warnings,
        nowcast=weather.nowcast,
    )
