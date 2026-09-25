"""
Ranking Service
===============
Rule-based personalization for the Mausam homepage.

Design principle
----------------
"Personalization changes the priority, not the availability."

Every weather card is ALWAYS returned.  This service only assigns a
relevance score to each card so the Flutter UI can sort them with the
most useful cards at the top for a given persona.

No machine learning is used here — weights are transparent and
hand-crafted for the MVP.  They can be tuned or replaced later.
"""

from typing import List, Dict
from app.models.weather import WeatherCard

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
# Persona weight tables
# Keys are WeatherCard.type values.
# Higher weight → card appears higher in the ranked list.
# Unspecified card types receive a default weight of 1.0 (always present).
# ---------------------------------------------------------------------------
_PERSONA_WEIGHTS: Dict[str, Dict[str, float]] = {
    "farmer": {
        "rain_alert":     10.0,
        "humidity":        9.0,
        "temperature":     8.0,
        "wind_speed":      7.0,
        "uv_index":        6.0,
        "air_quality":     3.0,
        "visibility":      3.0,
        "feels_like":      4.0,
        "sunrise_sunset":  6.0,
        "pollen":          5.0,
    },
    "student": {
        "rain_alert":      6.0,
        "temperature":     7.0,
        "feels_like":      8.0,
        "wind_speed":      5.0,
        "air_quality":     4.0,
        "uv_index":        4.0,
        "visibility":      3.0,
        "humidity":        3.0,
        "sunrise_sunset":  2.0,
        "pollen":          3.0,
    },
    "traveller": {
        "visibility":      10.0,
        "wind_speed":       9.0,
        "rain_alert":       9.0,
        "temperature":      8.0,
        "feels_like":       7.0,
        "uv_index":         6.0,
        "air_quality":      5.0,
        "humidity":         4.0,
        "sunrise_sunset":   5.0,
        "pollen":           3.0,
    },
    "health": {
        "air_quality":     10.0,
        "pollen":           9.0,
        "uv_index":         8.0,
        "humidity":         7.0,
        "temperature":      6.0,
        "feels_like":       6.0,
        "rain_alert":       4.0,
        "wind_speed":       3.0,
        "visibility":       2.0,
        "sunrise_sunset":   2.0,
    },
    "commuter": {
        "rain_alert":      10.0,
        "visibility":       9.0,
        "wind_speed":       8.0,
        "temperature":      6.0,
        "feels_like":       6.0,
        "air_quality":      5.0,
        "humidity":         4.0,
        "uv_index":         3.0,
        "sunrise_sunset":   4.0,
        "pollen":           2.0,
    },
    "outdoor_worker": {
        "uv_index":        10.0,
        "temperature":      9.0,
        "feels_like":       9.0,
        "humidity":         8.0,
        "rain_alert":       8.0,
        "wind_speed":       7.0,
        "air_quality":      6.0,
        "visibility":       5.0,
        "sunrise_sunset":   5.0,
        "pollen":           4.0,
    },
    "senior": {
        "feels_like":      10.0,
        "temperature":      9.0,
        "air_quality":      9.0,
        "humidity":         8.0,
        "uv_index":         7.0,
        "rain_alert":       6.0,
        "wind_speed":       5.0,
        "pollen":           6.0,
        "visibility":       3.0,
        "sunrise_sunset":   3.0,
    },
    "event_planner": {
        "rain_alert":      10.0,
        "wind_speed":       9.0,
        "temperature":      8.0,
        "visibility":       8.0,
        "humidity":         7.0,
        "feels_like":       6.0,
        "uv_index":         5.0,
        "air_quality":      4.0,
        "sunrise_sunset":   5.0,
        "pollen":           3.0,
    },
}

_DEFAULT_WEIGHT = 1.0  # fallback for any card type not listed above


class RankingService:
    """
    Assigns a relevance score to each WeatherCard based on persona weights,
    then returns the cards sorted highest-score-first.

    The cards list is never filtered — all cards are returned every time.
    """

    def rank(self, cards: List[WeatherCard], persona: str) -> List[WeatherCard]:
        """
        Parameters
        ----------
        cards   : List of WeatherCard objects from the weather service.
        persona : One of the SUPPORTED_PERSONAS strings.

        Returns
        -------
        The same cards with their .score field populated, sorted
        by score descending (most relevant first).

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

        weights = _PERSONA_WEIGHTS.get(persona, {})

        scored_cards: List[WeatherCard] = []
        for card in cards:
            score = weights.get(card.type, _DEFAULT_WEIGHT)
            # model_copy creates a new object so we don't mutate the original
            scored_cards.append(card.model_copy(update={"score": score}))

        # Sort by score descending; use card type as tiebreaker for stability
        scored_cards.sort(key=lambda c: (-c.score, c.type))

        return scored_cards
