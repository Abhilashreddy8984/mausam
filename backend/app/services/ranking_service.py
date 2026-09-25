"""
Ranking Service
===============
Context-aware, rule-based personalization for the Mausam homepage.

Design principle
----------------
"Personalization changes the priority, not the availability."

Every weather card is ALWAYS returned.  This service only computes a
relevance score for each card — the Flutter UI sorts cards by score
with the highest-scoring card shown first.

This is NOT machine learning.
------------------------------
All scoring rules are explicit, transparent, and hand-crafted.
They can be read, understood, and modified by any team member.
The rules are NOT trained on data.

Scoring formula (additive)
--------------------------
  final_score = persona_score
              + weather_context_score
              + time_context_score

  persona_score         — per-card weight from the persona weight table
                          (range 1.0 – 10.0)
  weather_context_score — boost applied when current conditions make a
                          card more urgent for this persona
                          (range 0.0 – 5.0 per boost)
  time_context_score    — small boost for cards that are more relevant
                          at the current time of day
                          (range 0.0 – 2.0)

Cards with no explicit persona weight receive the DEFAULT_WEIGHT (1.0)
as their persona_score.  Weather and time context boosts may still push
them higher if conditions warrant.

Same inputs always produce the same output (deterministic).

Architecture
------------
  WeatherProvider
       ↓
  WeatherResponse + server time
       ↓
  RankingContext   (built in routes.py)
       ↓
  RankingService.rank(cards, persona, context)
       ↓
  Scored & sorted WeatherCards  →  Flutter
"""

from typing import List, Optional

from app.models.ranking_context import RankingContext
from app.models.weather import WeatherCard
from app.services.context_thresholds import (
    # Weather thresholds
    HIGH_RAIN_PROBABILITY,
    RAIN_CONDITION_KEYWORDS,
    HIGH_TEMPERATURE_THRESHOLD,
    LOW_TEMPERATURE_THRESHOLD,
    HIGH_WIND_THRESHOLD,
    HIGH_UV_THRESHOLD,
    HIGH_AQI_THRESHOLD,
    POOR_VISIBILITY_THRESHOLD,
    # Weather boost amounts
    BOOST_RAIN_HIGH,
    BOOST_RAIN_MODERATE,
    BOOST_TEMPERATURE_HIGH,
    BOOST_WIND_HIGH,
    BOOST_VISIBILITY_POOR,
    BOOST_UV_HIGH,
    BOOST_AQI_POOR,
    BOOST_SECONDARY,
    # Time windows
    MORNING_START,
    MORNING_END,
    AFTERNOON_START,
    AFTERNOON_END,
    EVENING_START,
    EVENING_END,
    # Time boost amounts
    BOOST_TIME_PRIMARY,
    BOOST_TIME_SECONDARY,
)

# ---------------------------------------------------------------------------
# Supported personas
# ---------------------------------------------------------------------------
SUPPORTED_PERSONAS = {
    "farmer",
    "student",
    "traveller",
    "health",
    "commuter",
    "outdoor_worker",
    "senior",
    "event_planner",
}

# ---------------------------------------------------------------------------
# Persona base weight tables
# Keys are WeatherCard.type strings.
# Higher weight → higher base relevance for this persona.
# Unspecified card types receive DEFAULT_WEIGHT (always kept, shown lower).
# ---------------------------------------------------------------------------
_DEFAULT_WEIGHT: float = 1.0

_PERSONA_WEIGHTS: dict[str, dict[str, float]] = {
    "farmer": {
        "rain_alert":    10.0,
        "humidity":       9.0,
        "temperature":    8.0,
        "wind_speed":     7.0,
        "uv_index":       6.0,
        "sunrise_sunset": 6.0,
        "pollen":         5.0,
        "feels_like":     4.0,
        "air_quality":    3.0,
        "visibility":     3.0,
    },
    "student": {
        "rain_alert":     6.0,
        "temperature":    7.0,
        "feels_like":     8.0,
        "wind_speed":     5.0,
        "air_quality":    4.0,
        "uv_index":       4.0,
        "visibility":     3.0,
        "humidity":       3.0,
        "sunrise_sunset": 2.0,
        "pollen":         3.0,
    },
    "traveller": {
        "visibility":     10.0,
        "wind_speed":      9.0,
        "rain_alert":      9.0,
        "temperature":     8.0,
        "feels_like":      7.0,
        "uv_index":        6.0,
        "air_quality":     5.0,
        "sunrise_sunset":  5.0,
        "humidity":        4.0,
        "pollen":          3.0,
    },
    "health": {
        "air_quality":    10.0,
        "pollen":          9.0,
        "uv_index":        8.0,
        "humidity":        7.0,
        "temperature":     6.0,
        "feels_like":      6.0,
        "rain_alert":      4.0,
        "wind_speed":      3.0,
        "visibility":      2.0,
        "sunrise_sunset":  2.0,
    },
    "commuter": {
        "rain_alert":     10.0,
        "visibility":      9.0,
        "wind_speed":      8.0,
        "temperature":     6.0,
        "feels_like":      6.0,
        "air_quality":     5.0,
        "humidity":        4.0,
        "sunrise_sunset":  4.0,
        "uv_index":        3.0,
        "pollen":          2.0,
    },
    "outdoor_worker": {
        "uv_index":       10.0,
        "temperature":     9.0,
        "feels_like":      9.0,
        "humidity":        8.0,
        "rain_alert":      8.0,
        "wind_speed":      7.0,
        "air_quality":     6.0,
        "visibility":      5.0,
        "sunrise_sunset":  5.0,
        "pollen":          4.0,
    },
    "senior": {
        "feels_like":     10.0,
        "temperature":     9.0,
        "air_quality":     9.0,
        "humidity":        8.0,
        "uv_index":        7.0,
        "rain_alert":      6.0,
        "pollen":          6.0,
        "wind_speed":      5.0,
        "visibility":      3.0,
        "sunrise_sunset":  3.0,
    },
    "event_planner": {
        "rain_alert":     10.0,
        "wind_speed":      9.0,
        "temperature":     8.0,
        "visibility":      8.0,
        "humidity":        7.0,
        "feels_like":      6.0,
        "uv_index":        5.0,
        "air_quality":     4.0,
        "sunrise_sunset":  5.0,
        "pollen":          3.0,
    },
}


# ---------------------------------------------------------------------------
# Helper — detect rain from context
# ---------------------------------------------------------------------------
def _is_significant_rain(context: RankingContext) -> bool:
    """
    Returns True if current conditions indicate significant rain.
    Checks rain_probability threshold OR condition keyword match.
    """
    if (
        context.rain_probability is not None
        and context.rain_probability >= HIGH_RAIN_PROBABILITY
    ):
        return True
    if context.condition:
        cond_lower = context.condition.lower()
        if any(kw in cond_lower for kw in RAIN_CONDITION_KEYWORDS):
            return True
    return False


def _is_high_temperature(context: RankingContext) -> bool:
    return (
        context.temperature_c is not None
        and context.temperature_c >= HIGH_TEMPERATURE_THRESHOLD
    )


def _is_strong_wind(context: RankingContext) -> bool:
    return (
        context.wind_speed_kmh is not None
        and context.wind_speed_kmh >= HIGH_WIND_THRESHOLD
    )


def _is_poor_visibility(context: RankingContext) -> bool:
    return (
        context.visibility_km is not None
        and context.visibility_km <= POOR_VISIBILITY_THRESHOLD
    )


def _is_high_uv(context: RankingContext) -> bool:
    return (
        context.uv_index is not None
        and context.uv_index >= HIGH_UV_THRESHOLD
    )


def _is_poor_aqi(context: RankingContext) -> bool:
    return (
        context.aqi is not None
        and context.aqi >= HIGH_AQI_THRESHOLD
    )


# ---------------------------------------------------------------------------
# Weather context boosts
# Each function returns a dict: card_type -> boost_amount
# Only non-zero boosts are returned.
# ---------------------------------------------------------------------------

def _weather_boosts_for_persona(
    persona: str, context: RankingContext
) -> dict[str, float]:
    """
    Compute weather-context score boosts for a given persona.

    Returns a dict mapping card type → additional score boost.
    Only cards that receive a boost appear in the dict.
    Cards NOT in the dict receive 0 boost (persona score unchanged).

    These rules are PROTOTYPE rules for the SIH demo.
    They are NOT official IMD advisories.
    """
    boosts: dict[str, float] = {}
    rain   = _is_significant_rain(context)
    hot    = _is_high_temperature(context)
    windy  = _is_strong_wind(context)
    foggy  = _is_poor_visibility(context)
    uv     = _is_high_uv(context)
    smoggy = _is_poor_aqi(context)

    if persona == "farmer":
        if rain:
            boosts["rain_alert"]  = BOOST_RAIN_HIGH
            boosts["humidity"]    = BOOST_SECONDARY
        if hot:
            boosts["temperature"] = BOOST_TEMPERATURE_HIGH
            boosts["feels_like"]  = BOOST_SECONDARY
        if windy:
            boosts["wind_speed"]  = BOOST_WIND_HIGH

    elif persona == "student":
        if rain:
            boosts["rain_alert"]  = BOOST_RAIN_HIGH
            boosts["visibility"]  = BOOST_SECONDARY
        if foggy:
            boosts["visibility"]  = BOOST_VISIBILITY_POOR

    elif persona == "traveller":
        if rain:
            boosts["rain_alert"]  = BOOST_RAIN_HIGH
            boosts["visibility"]  = BOOST_SECONDARY
        if foggy:
            boosts["visibility"]  = BOOST_VISIBILITY_POOR
        if windy:
            boosts["wind_speed"]  = BOOST_WIND_HIGH

    elif persona == "health":
        if smoggy:
            boosts["air_quality"] = BOOST_AQI_POOR
            boosts["pollen"]      = BOOST_SECONDARY
        if uv:
            boosts["uv_index"]    = BOOST_UV_HIGH
        if hot:
            boosts["temperature"] = BOOST_TEMPERATURE_HIGH
            boosts["feels_like"]  = BOOST_SECONDARY

    elif persona == "commuter":
        if rain:
            boosts["rain_alert"]  = BOOST_RAIN_HIGH
        if foggy:
            boosts["visibility"]  = BOOST_VISIBILITY_POOR
        if windy:
            boosts["wind_speed"]  = BOOST_WIND_HIGH

    elif persona == "outdoor_worker":
        if hot:
            boosts["temperature"] = BOOST_TEMPERATURE_HIGH
            boosts["feels_like"]  = BOOST_SECONDARY
        if uv:
            boosts["uv_index"]    = BOOST_UV_HIGH
        if rain:
            boosts["rain_alert"]  = BOOST_RAIN_MODERATE
        if windy:
            boosts["wind_speed"]  = BOOST_WIND_HIGH

    elif persona == "senior":
        if hot:
            boosts["temperature"] = BOOST_TEMPERATURE_HIGH
            boosts["feels_like"]  = BOOST_SECONDARY
        if rain:
            boosts["rain_alert"]  = BOOST_RAIN_MODERATE
        if smoggy:
            boosts["air_quality"] = BOOST_AQI_POOR

    elif persona == "event_planner":
        if rain:
            boosts["rain_alert"]  = BOOST_RAIN_HIGH
            boosts["visibility"]  = BOOST_SECONDARY
        if hot:
            boosts["temperature"] = BOOST_TEMPERATURE_HIGH
        if windy:
            boosts["wind_speed"]  = BOOST_WIND_HIGH

    return boosts


# ---------------------------------------------------------------------------
# Time-of-day context boosts
# Returns a dict: card_type -> boost_amount
# ---------------------------------------------------------------------------

def _time_boosts(hour: int) -> dict[str, float]:
    """
    Small time-of-day relevance boosts.

    These are intentionally smaller than weather/persona boosts so that
    time adjustments never override strong persona relevance.

    Morning   (05–10): sunrise_sunset and temperature more relevant.
    Afternoon (10–16): uv_index and temperature at peak relevance.
    Evening   (16–21): visibility and rain_alert more relevant.
    """
    if MORNING_START <= hour < MORNING_END:
        return {
            "sunrise_sunset": BOOST_TIME_PRIMARY,
            "temperature":    BOOST_TIME_SECONDARY,
        }
    elif AFTERNOON_START <= hour < AFTERNOON_END:
        return {
            "uv_index":    BOOST_TIME_PRIMARY,
            "temperature": BOOST_TIME_PRIMARY,
            "feels_like":  BOOST_TIME_SECONDARY,
        }
    elif EVENING_START <= hour < EVENING_END:
        return {
            "visibility": BOOST_TIME_PRIMARY,
            "rain_alert": BOOST_TIME_SECONDARY,
        }
    # Night (21–05): no time boost — all cards use persona + weather scores only
    return {}


# ---------------------------------------------------------------------------
# Scoring helper — build explanation list (development / debug only)
# ---------------------------------------------------------------------------

def _build_reasons(
    card_type: str,
    persona_score: float,
    weather_boost: float,
    time_boost: float,
    context: RankingContext,
) -> list[str]:
    """
    Build a list of human-readable strings explaining why this card
    received its score.  Used for the optional ranking_reasons field.
    """
    reasons: list[str] = []

    if persona_score >= 8.0:
        reasons.append("high persona relevance")
    elif persona_score >= 5.0:
        reasons.append("moderate persona relevance")
    else:
        reasons.append("low persona relevance")

    if weather_boost > 0:
        if card_type == "rain_alert" and _is_significant_rain(context):
            reasons.append("significant rain detected")
        elif card_type == "temperature" and _is_high_temperature(context):
            reasons.append("high temperature detected")
        elif card_type == "wind_speed" and _is_strong_wind(context):
            reasons.append("strong wind detected")
        elif card_type == "visibility" and _is_poor_visibility(context):
            reasons.append("poor visibility detected")
        elif card_type == "uv_index" and _is_high_uv(context):
            reasons.append("high UV index detected")
        elif card_type == "air_quality" and _is_poor_aqi(context):
            reasons.append("poor air quality detected")
        else:
            reasons.append("weather condition boost applied")

    if time_boost > 0:
        hour = context.current_hour
        if MORNING_START <= hour < MORNING_END:
            reasons.append("morning time window")
        elif AFTERNOON_START <= hour < AFTERNOON_END:
            reasons.append("afternoon peak window")
        elif EVENING_START <= hour < EVENING_END:
            reasons.append("evening time window")

    return reasons


# ---------------------------------------------------------------------------
# RankingService
# ---------------------------------------------------------------------------

class RankingService:
    """
    Context-aware, rule-based card ranking service.

    Scoring formula
    ---------------
      final_score = persona_score
                  + weather_context_score
                  + time_context_score

    Cards are never filtered — all are always returned, ordered by score.
    """

    def rank(
        self,
        cards: List[WeatherCard],
        persona: str,
        context: Optional[RankingContext] = None,
    ) -> List[WeatherCard]:
        """
        Score and sort weather cards.

        Parameters
        ----------
        cards   : List of WeatherCard objects from the weather provider.
        persona : One of the SUPPORTED_PERSONAS strings.
        context : RankingContext with weather/time/location data.
                  If None, only persona weights are used (backward-compatible).

        Returns
        -------
        All input cards with .score populated, sorted by score descending.
        Cards with equal score are ordered alphabetically by type for
        deterministic, reproducible output.

        Raises
        ------
        ValueError if persona is not in SUPPORTED_PERSONAS.
        """
        persona = persona.lower().strip()

        if persona not in SUPPORTED_PERSONAS:
            raise ValueError(
                f"Unknown persona '{persona}'. "
                f"Supported personas: {sorted(SUPPORTED_PERSONAS)}"
            )

        # ── Compute context boosts ─────────────────────────────
        weather_boosts: dict[str, float] = {}
        time_boosts_map: dict[str, float] = {}

        if context is not None:
            weather_boosts = _weather_boosts_for_persona(persona, context)
            time_boosts_map = _time_boosts(context.current_hour)

        # ── Score every card ───────────────────────────────────
        persona_weights = _PERSONA_WEIGHTS.get(persona, {})
        scored_cards: List[WeatherCard] = []

        for card in cards:
            persona_score  = persona_weights.get(card.type, _DEFAULT_WEIGHT)
            weather_boost  = weather_boosts.get(card.type, 0.0)
            time_boost     = time_boosts_map.get(card.type, 0.0)
            final_score    = persona_score + weather_boost + time_boost

            # Build ranking reasons (optional debug field)
            reasons = []
            if context is not None:
                reasons = _build_reasons(
                    card.type, persona_score, weather_boost, time_boost, context
                )

            # model_copy never mutates the original card object.
            # ranking_reasons is an Optional[List[str]] field on WeatherCard.
            # Flutter ignores unknown JSON fields — fully backward-compatible.
            scored_cards.append(
                card.model_copy(
                    update={
                        "score": round(final_score, 2),
                        "ranking_reasons": reasons if reasons else None,
                    }
                )
            )

        # ── Sort: highest score first; alphabetical type as tiebreaker ──
        scored_cards.sort(key=lambda c: (-c.score, c.type))

        return scored_cards
