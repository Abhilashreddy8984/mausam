"""
Context Thresholds
==================
Named constants used by the RankingService for weather-context adjustments.

WHY separate constants?
-----------------------
Threshold values are the most likely thing to be updated as the project
matures — for example, when official IMD advisory thresholds are published.
Keeping them here means:
  - A single change here updates all ranking logic automatically.
  - The values are self-documenting (name explains what it means).
  - Domain experts can review and tune without reading ranking logic.

IMPORTANT: These are PROTOTYPE thresholds for the SIH academic demo.
They are NOT official IMD thresholds or advisory values.
They should be replaced with officially validated values before any
public-facing or operational deployment.

Score boost values
------------------
Boost amounts are also defined here so that the overall scale of the
scoring system is visible in one place.

Scoring scale reference
-----------------------
  Persona base score     : 1.0 – 10.0  (from persona weight tables)
  Weather context boost  : 1.0 – 5.0   (defined below)
  Time context boost     : 0.5 – 2.0   (defined below)
  ─────────────────────────────────────
  Max possible score     : ≈ 17.0
  Min possible score     : ≈ 1.0

This keeps the scoring transparent and human-readable.
"""

# ---------------------------------------------------------------------------
# Weather condition thresholds
# (PROTOTYPE values — not official IMD thresholds)
# ---------------------------------------------------------------------------

# Rain: probability (%) at or above which "significant rain" is triggered
HIGH_RAIN_PROBABILITY: float = 60.0

# Rain: condition strings that indicate active rain (case-insensitive match)
RAIN_CONDITION_KEYWORDS: tuple = (
    "rain",
    "shower",
    "drizzle",
    "thunderstorm",
    "storm",
    "heavy",
)

# Temperature: °C at or above which "high heat" is triggered
HIGH_TEMPERATURE_THRESHOLD: float = 38.0

# Temperature: °C at or below which "cold" is triggered
LOW_TEMPERATURE_THRESHOLD: float = 15.0

# Wind: km/h at or above which "strong wind" is triggered
HIGH_WIND_THRESHOLD: float = 40.0

# UV Index: at or above which "high UV" is triggered
HIGH_UV_THRESHOLD: int = 8

# Air Quality Index: at or above which "poor AQI" is triggered
HIGH_AQI_THRESHOLD: int = 150

# Visibility: km at or below which "poor visibility" is triggered
POOR_VISIBILITY_THRESHOLD: float = 4.0

# ---------------------------------------------------------------------------
# Boost amounts for weather context adjustments
# ---------------------------------------------------------------------------

# Applied when significant rain is detected for a rain-sensitive persona
BOOST_RAIN_HIGH: float = 5.0

# Applied for moderate rain relevance boost
BOOST_RAIN_MODERATE: float = 3.0

# Applied when high temperature is detected
BOOST_TEMPERATURE_HIGH: float = 4.0

# Applied when strong wind is detected
BOOST_WIND_HIGH: float = 4.0

# Applied when poor visibility is detected
BOOST_VISIBILITY_POOR: float = 4.0

# Applied when high UV is detected
BOOST_UV_HIGH: float = 4.0

# Applied when poor AQI is detected
BOOST_AQI_POOR: float = 5.0

# Applied for general secondary relevance boost
BOOST_SECONDARY: float = 2.0

# ---------------------------------------------------------------------------
# Time-of-day context windows (hours, 24h clock)
# ---------------------------------------------------------------------------

# Morning: sunrise/temperature more relevant
MORNING_START: int = 5
MORNING_END: int = 10

# Afternoon: UV/temperature peak relevance window
AFTERNOON_START: int = 10
AFTERNOON_END: int = 16

# Evening: visibility and alerts more relevant
EVENING_START: int = 16
EVENING_END: int = 21

# ---------------------------------------------------------------------------
# Time context boost amounts
# Keep these SMALLER than weather context boosts so persona still dominates
# ---------------------------------------------------------------------------
BOOST_TIME_PRIMARY: float = 2.0    # main card boosted by time-of-day
BOOST_TIME_SECONDARY: float = 1.0  # supporting card boosted by time-of-day
