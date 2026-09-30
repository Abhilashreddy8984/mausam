"""
Weather Models
==============
Pydantic models for all weather data in the Mausam backend.

Design rules
------------
- Every new field is Optional with a sensible default (None or []).
- Fields used by Flutter must keep their existing names and types.
- New fields that Flutter does not yet read are silently ignored by
  Dart's fromJson — fully backward-compatible.
- No IMD-specific JSON structure leaks into this file.
  The IMD mapper (app/services/imd_mapper.py) owns that translation.

Change log
----------
v0.1  Initial: WeatherCard, WeatherResponse (city, temperature, humidity,
       wind_speed, condition, cards, source)
v0.2  Added optional `source` to WeatherResponse.
v0.3  Added optional `ranking_reasons` to WeatherCard.
v0.4  Rich weather model: forecast, warnings, nowcast, numeric fields
       for feels_like, pressure, wind_direction, rainfall, cloud_cover,
       uv_index, aqi, visibility_km, observation_time, district, state.
       All additions are Optional / empty-list so Demo provider needs
       zero changes and Flutter is unaffected.
"""

from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel


# ---------------------------------------------------------------------------
# WeatherCard — one ranked card on the homepage (unchanged from v0.3)
# ---------------------------------------------------------------------------

class WeatherCard(BaseModel):
    """
    One weather information card displayed on the personalized homepage.

    Fields
    ------
    type             : Internal identifier, e.g. "temperature", "rain_alert".
    title            : Human-readable card title shown in the UI.
    value            : The primary display value — always a string.
    unit             : Unit string, e.g. "°C", "%", "km/h", "".
    severity         : "low" | "medium" | "high" — drives UI colour coding.
    score            : Relevance score assigned by RankingService.
    ranking_reasons  : Optional debug list explaining the score.
                       Flutter ignores unknown JSON fields — backward-compat.
    """

    type: str
    title: str
    value: str
    unit: str
    severity: str
    score: float = 0.0
    ranking_reasons: Optional[List[str]] = None


# ---------------------------------------------------------------------------
# ForecastDay — one day in a multi-day forecast
# ---------------------------------------------------------------------------

class ForecastDay(BaseModel):
    """
    A single day's forecast entry.

    All fields are Optional so that a partial IMD response
    does not break the model.
    """

    date: Optional[str] = None           # "YYYY-MM-DD"
    min_temp_c: Optional[float] = None
    max_temp_c: Optional[float] = None
    rainfall_mm: Optional[float] = None
    rain_probability: Optional[float] = None   # 0–100 %
    condition: Optional[str] = None
    weather_code: Optional[str] = None


# ---------------------------------------------------------------------------
# WeatherWarning — a district-level weather warning
# ---------------------------------------------------------------------------

class WeatherWarning(BaseModel):
    """
    A single weather warning entry.

    Populated from the IMD district-wise warnings API when available.
    Demo provider returns an empty list.
    """

    warning_type: Optional[str] = None   # e.g. "Yellow Alert", "Red Alert"
    severity: Optional[str] = None       # "low" | "medium" | "high"
    title: Optional[str] = None
    description: Optional[str] = None
    district: Optional[str] = None
    valid_from: Optional[str] = None     # ISO datetime string
    valid_until: Optional[str] = None
    source: Optional[str] = None        # e.g. "IMD"


# ---------------------------------------------------------------------------
# NowcastEntry — a district-level nowcast entry
# ---------------------------------------------------------------------------

class NowcastEntry(BaseModel):
    """
    A single nowcast entry (short-range, high-resolution forecast).

    Populated from the IMD district-wise nowcast API when available.
    Demo provider returns an empty list.
    """

    phenomenon: Optional[str] = None    # e.g. "Thunderstorm", "Heavy Rain"
    severity: Optional[str] = None      # "low" | "medium" | "high"
    description: Optional[str] = None
    district: Optional[str] = None
    issued_time: Optional[str] = None   # ISO datetime string
    valid_until: Optional[str] = None


# ---------------------------------------------------------------------------
# WeatherResponse — full payload returned by /weather and /homepage
# ---------------------------------------------------------------------------

class WeatherResponse(BaseModel):
    """
    Complete weather response returned by the /weather and /homepage endpoints.

    Backward-compatible fields (used by current Flutter app)
    --------------------------------------------------------
    city        : Name of the city.
    temperature : Current temperature in °C.
    humidity    : Relative humidity percentage.
    wind_speed  : Wind speed in km/h.
    condition   : Short weather condition string.
    cards       : Ranked WeatherCard list.
    source      : "demo" | "IMD" | None.

    New optional fields (added v0.4 — Flutter ignores unknown fields)
    -----------------------------------------------------------------
    district          : District name if available (IMD uses district-level data).
    state             : State/region name.
    latitude          : Observation point latitude.
    longitude         : Observation point longitude.
    feels_like        : Apparent/feels-like temperature in °C.
    pressure_hpa      : Atmospheric pressure in hPa.
    wind_direction    : Wind direction string, e.g. "SW", "NW".
    rainfall_mm       : Rainfall in mm (last observation period).
    cloud_cover_pct   : Cloud cover as a percentage (0–100).
    uv_index          : UV index (integer).
    aqi               : Air Quality Index (integer).
    visibility_km     : Visibility in km.
    observation_time  : ISO datetime string of when data was observed/issued.
    weather_code      : Provider-specific weather code, e.g. IMD weather code.
    forecast          : List of ForecastDay objects (up to 7 days).
    warnings          : List of WeatherWarning objects.
    nowcast           : List of NowcastEntry objects.
    """

    # ── Existing fields — Flutter uses these directly ──────────────────────
    city: str
    temperature: float
    humidity: float
    wind_speed: float
    condition: str
    cards: List[WeatherCard]
    source: Optional[str] = None

    # ── Location detail (new, optional) ────────────────────────────────────
    district: Optional[str] = None
    state: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None

    # ── Rich current-conditions numbers (new, optional) ────────────────────
    # These feed directly into RankingContext so the ranking engine can
    # use real numeric values instead of the None placeholders it
    # currently receives from DemoWeatherProvider.
    feels_like: Optional[float] = None       # °C
    pressure_hpa: Optional[float] = None     # hPa
    wind_direction: Optional[str] = None     # e.g. "SW"
    rainfall_mm: Optional[float] = None      # mm
    cloud_cover_pct: Optional[float] = None  # 0–100
    uv_index: Optional[int] = None
    aqi: Optional[int] = None
    visibility_km: Optional[float] = None    # km
    observation_time: Optional[str] = None   # ISO datetime string
    weather_code: Optional[str] = None       # provider-specific code

    # ── Forecast, warnings, nowcast (new, optional) ────────────────────────
    forecast: List[ForecastDay] = []
    warnings: List[WeatherWarning] = []
    nowcast: List[NowcastEntry] = []
