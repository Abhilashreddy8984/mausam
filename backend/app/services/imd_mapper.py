"""
IMD Response Mapper
===================
Translates raw IMD API JSON dictionaries into our internal
WeatherResponse model.

Architecture boundary
---------------------
This is the ONLY file that knows about IMD JSON field names.
No other file in the application (routes, ranking, Flutter) ever
sees raw IMD data — they all work with WeatherResponse.

  IMD API (JSON)
       ↓
  imd_mapper.py   ← THIS FILE
       ↓
  WeatherResponse  (app/models/weather.py)
       ↓
  RankingService / Routes / Flutter

Design rules
------------
- Every field access uses .get() with a safe default — never crashes
  on missing or null IMD fields.
- Numeric fields are parsed through _safe_float() / _safe_int() —
  non-numeric strings (e.g. "N/A", "") silently return None.
- Weather cards (WeatherCard objects) are built from the numeric fields
  so the ranking engine and Flutter UI have something to display.
- This module never makes HTTP requests — that is IMDWeatherProvider's job.
- This module never reads environment variables.

IMD field names used
---------------------
Based on publicly documented IMD API schema.
Exact field names will be verified against live API responses when
authorized access is obtained.  Only change field names here — nowhere
else needs to change.

Current weather (current_wx_api.php)
  Station_Name, District, State, Lat, Lon
  Temp, Feels_Like, RH, Wind_Speed, Wind_Dir
  Rainfall, Cloud_Cover, Pressure, Visibility
  UV_Index, Weather_Desc, Weather_Code, Obs_Time

7-day forecast (cityweather_loc.php)
  City, State, Lat, Lon
  Forecast[].Date, Max_Temp, Min_Temp, Rainfall, Rain_Prob
  Forecast[].Weather_Desc, Weather_Code

District warnings (warnings_district_api.php)
  District, State
  Warnings[].Warning_Type, Severity, Title, Description
  Warnings[].Valid_From, Valid_Until, Source

District nowcast (nowcast_district_api.php)
  District, State
  Nowcast[].Phenomenon, Severity, Description
  Nowcast[].Issued_Time, Valid_Until
"""

import logging
from typing import Any

from app.models.weather import (
    ForecastDay,
    NowcastEntry,
    WeatherCard,
    WeatherResponse,
    WeatherWarning,
)

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Safe numeric parsers
# ---------------------------------------------------------------------------

def _safe_float(value: Any) -> float | None:
    """
    Convert a value to float, returning None if conversion fails.
    Handles None, empty string, "N/A", and similar non-numeric inputs.
    """
    if value is None:
        return None
    try:
        return float(str(value).strip())
    except (ValueError, TypeError):
        return None


def _safe_int(value: Any) -> int | None:
    """
    Convert a value to int, returning None if conversion fails.
    Uses _safe_float internally to handle decimal strings like "8.0".
    """
    f = _safe_float(value)
    return int(f) if f is not None else None


def _safe_str(value: Any) -> str | None:
    """
    Return stripped string, or None if blank/None.
    """
    if value is None:
        return None
    s = str(value).strip()
    return s if s else None


# ---------------------------------------------------------------------------
# Severity helper
# ---------------------------------------------------------------------------

def _severity_from_temperature(temp_c: float | None) -> str:
    """Derive a card severity string from temperature."""
    if temp_c is None:
        return "low"
    if temp_c >= 40:
        return "high"
    if temp_c >= 35:
        return "medium"
    return "low"


def _severity_from_warning_type(warning_type: str | None) -> str:
    """Map IMD alert colour names to our severity strings."""
    if not warning_type:
        return "medium"
    wt = warning_type.lower()
    if "red" in wt:
        return "high"
    if "orange" in wt:
        return "high"
    if "yellow" in wt:
        return "medium"
    return "low"


def _severity_from_wind(speed_kmh: float | None) -> str:
    if speed_kmh is None:
        return "low"
    if speed_kmh >= 60:
        return "high"
    if speed_kmh >= 35:
        return "medium"
    return "low"


def _severity_from_rain(rainfall_mm: float | None) -> str:
    if rainfall_mm is None:
        return "low"
    if rainfall_mm >= 20:
        return "high"
    if rainfall_mm >= 5:
        return "medium"
    return "low"


def _severity_from_uv(uv: int | None) -> str:
    if uv is None:
        return "low"
    if uv >= 8:
        return "high"
    if uv >= 6:
        return "medium"
    return "low"


def _severity_from_aqi(aqi: int | None) -> str:
    if aqi is None:
        return "low"
    if aqi >= 200:
        return "high"
    if aqi >= 100:
        return "medium"
    return "low"


def _severity_from_visibility(vis_km: float | None) -> str:
    if vis_km is None:
        return "low"
    if vis_km <= 2:
        return "high"
    if vis_km <= 5:
        return "medium"
    return "low"


# ---------------------------------------------------------------------------
# Card builder
# ---------------------------------------------------------------------------

def _build_cards(
    temperature: float | None,
    feels_like: float | None,
    humidity: float | None,
    wind_speed: float | None,
    wind_direction: str | None,
    rainfall_mm: float | None,
    uv_index: int | None,
    aqi: int | None,
    visibility_km: float | None,
    condition: str | None,
) -> list[WeatherCard]:
    """
    Build the standard set of WeatherCard objects from parsed numeric values.

    Cards are built for every field that has a non-None value.
    This ensures the ranking engine has a card to score even when the
    IMD response is partial.

    The card set mirrors the 10 cards produced by DemoWeatherProvider so
    that the Flutter UI and ranking engine work identically regardless of
    which provider is active.
    """
    cards: list[WeatherCard] = []

    if temperature is not None:
        cards.append(WeatherCard(
            type="temperature",
            title="Temperature",
            value=str(round(temperature, 1)),
            unit="°C",
            severity=_severity_from_temperature(temperature),
        ))

    if humidity is not None:
        cards.append(WeatherCard(
            type="humidity",
            title="Humidity",
            value=str(int(humidity)),
            unit="%",
            severity="medium" if humidity > 80 else "low",
        ))

    if wind_speed is not None:
        wind_val = f"{int(round(wind_speed))} {wind_direction or ''}".strip()
        cards.append(WeatherCard(
            type="wind_speed",
            title="Wind Speed",
            value=wind_val,
            unit="km/h",
            severity=_severity_from_wind(wind_speed),
        ))

    # Rain alert card — shown whenever rainfall > 0 OR condition suggests rain
    rain_value = (
        f"{rainfall_mm:.1f} mm" if rainfall_mm and rainfall_mm > 0
        else (condition or "No rainfall reported")
    )
    cards.append(WeatherCard(
        type="rain_alert",
        title="Rain Alert",
        value=rain_value,
        unit="",
        severity=_severity_from_rain(rainfall_mm),
    ))

    if uv_index is not None:
        cards.append(WeatherCard(
            type="uv_index",
            title="UV Index",
            value=str(uv_index),
            unit="",
            severity=_severity_from_uv(uv_index),
        ))

    if aqi is not None:
        cards.append(WeatherCard(
            type="air_quality",
            title="Air Quality Index",
            value=str(aqi),
            unit="AQI",
            severity=_severity_from_aqi(aqi),
        ))

    if visibility_km is not None:
        cards.append(WeatherCard(
            type="visibility",
            title="Visibility",
            value=str(round(visibility_km, 1)),
            unit="km",
            severity=_severity_from_visibility(visibility_km),
        ))

    if feels_like is not None:
        cards.append(WeatherCard(
            type="feels_like",
            title="Feels Like",
            value=str(round(feels_like, 1)),
            unit="°C",
            severity=_severity_from_temperature(feels_like),
        ))

    # Pollen — IMD current weather does not expose pollen directly.
    # Add a placeholder card so the ranking engine always has a pollen
    # card to rank (it will receive a low score for most personas).
    cards.append(WeatherCard(
        type="pollen",
        title="Pollen Level",
        value="Data unavailable",
        unit="",
        severity="low",
    ))

    return cards


# ---------------------------------------------------------------------------
# Public mapper functions
# ---------------------------------------------------------------------------

def map_current_weather(
    current_json: dict,
    forecast_json: dict | None = None,
    warnings_json: dict | None = None,
    nowcast_json: dict | None = None,
) -> WeatherResponse:
    """
    Build a WeatherResponse from one or more raw IMD API responses.

    Parameters
    ----------
    current_json   : Parsed JSON from current_wx_api.php.
    forecast_json  : Parsed JSON from cityweather_loc.php (optional).
    warnings_json  : Parsed JSON from warnings_district_api.php (optional).
    nowcast_json   : Parsed JSON from nowcast_district_api.php (optional).

    Returns
    -------
    WeatherResponse populated with all available fields.
    Missing fields are None / empty list — never raises.
    """
    # ── Parse current weather fields ──────────────────────────
    city        = _safe_str(current_json.get("Station_Name")) or "Unknown"
    district    = _safe_str(current_json.get("District"))
    state       = _safe_str(current_json.get("State"))
    lat         = _safe_float(current_json.get("Lat"))
    lon         = _safe_float(current_json.get("Lon"))

    temperature  = _safe_float(current_json.get("Temp"))
    feels_like   = _safe_float(current_json.get("Feels_Like"))
    humidity     = _safe_float(current_json.get("RH"))
    wind_speed   = _safe_float(current_json.get("Wind_Speed"))
    wind_dir     = _safe_str(current_json.get("Wind_Dir"))
    rainfall_mm  = _safe_float(current_json.get("Rainfall"))
    cloud_cover  = _safe_float(current_json.get("Cloud_Cover"))
    pressure     = _safe_float(current_json.get("Pressure"))
    visibility   = _safe_float(current_json.get("Visibility"))
    uv_index     = _safe_int(current_json.get("UV_Index"))
    condition    = _safe_str(current_json.get("Weather_Desc")) or "Unknown"
    weather_code = _safe_str(current_json.get("Weather_Code"))
    obs_time     = _safe_str(current_json.get("Obs_Time"))

    # Guard: temperature and humidity are required for a valid response.
    # Log a warning if they are missing (malformed response).
    if temperature is None:
        logger.warning(
            "IMD current weather response missing 'Temp' field for city '%s'. "
            "Ranking engine will skip temperature context adjustments.",
            city,
        )
    if humidity is None:
        logger.warning(
            "IMD current weather response missing 'RH' field for city '%s'.",
            city,
        )

    # ── Build WeatherCards ────────────────────────────────────
    cards = _build_cards(
        temperature=temperature,
        feels_like=feels_like,
        humidity=humidity,
        wind_speed=wind_speed,
        wind_direction=wind_dir,
        rainfall_mm=rainfall_mm,
        uv_index=uv_index,
        aqi=None,   # IMD current weather does not include AQI directly
        visibility_km=visibility,
        condition=condition,
    )

    # ── Map forecast ──────────────────────────────────────────
    forecast = _map_forecast(forecast_json) if forecast_json else []

    # ── Map warnings ──────────────────────────────────────────
    warnings = _map_warnings(warnings_json) if warnings_json else []

    # ── Map nowcast ───────────────────────────────────────────
    nowcast = _map_nowcast(nowcast_json) if nowcast_json else []

    return WeatherResponse(
        # ── Existing fields (Flutter reads these) ──────────────
        city=city,
        temperature=temperature if temperature is not None else 0.0,
        humidity=humidity if humidity is not None else 0.0,
        wind_speed=wind_speed if wind_speed is not None else 0.0,
        condition=condition,
        cards=cards,
        source="IMD",
        # ── New rich fields ────────────────────────────────────
        district=district,
        state=state,
        latitude=lat,
        longitude=lon,
        feels_like=feels_like,
        pressure_hpa=pressure,
        wind_direction=wind_dir,
        rainfall_mm=rainfall_mm,
        cloud_cover_pct=cloud_cover,
        uv_index=uv_index,
        aqi=None,
        visibility_km=visibility,
        observation_time=obs_time,
        weather_code=weather_code,
        forecast=forecast,
        warnings=warnings,
        nowcast=nowcast,
    )


def _map_forecast(forecast_json: dict) -> list[ForecastDay]:
    """Parse the forecast section of cityweather_loc.php response."""
    raw_list = forecast_json.get("Forecast", [])
    if not isinstance(raw_list, list):
        logger.warning("IMD forecast 'Forecast' key is not a list.")
        return []

    days: list[ForecastDay] = []
    for entry in raw_list:
        if not isinstance(entry, dict):
            continue
        days.append(ForecastDay(
            date=_safe_str(entry.get("Date")),
            min_temp_c=_safe_float(entry.get("Min_Temp")),
            max_temp_c=_safe_float(entry.get("Max_Temp")),
            rainfall_mm=_safe_float(entry.get("Rainfall")),
            rain_probability=_safe_float(entry.get("Rain_Prob")),
            condition=_safe_str(entry.get("Weather_Desc")),
            weather_code=_safe_str(entry.get("Weather_Code")),
        ))
    return days


def _map_warnings(warnings_json: dict) -> list[WeatherWarning]:
    """Parse the warnings section of warnings_district_api.php response."""
    district = _safe_str(warnings_json.get("District"))
    raw_list = warnings_json.get("Warnings", [])
    if not isinstance(raw_list, list):
        logger.warning("IMD warnings 'Warnings' key is not a list.")
        return []

    entries: list[WeatherWarning] = []
    for w in raw_list:
        if not isinstance(w, dict):
            continue
        wtype = _safe_str(w.get("Warning_Type"))
        entries.append(WeatherWarning(
            warning_type=wtype,
            severity=_safe_str(w.get("Severity")) or _severity_from_warning_type(wtype),
            title=_safe_str(w.get("Title")),
            description=_safe_str(w.get("Description")),
            district=district,
            valid_from=_safe_str(w.get("Valid_From")),
            valid_until=_safe_str(w.get("Valid_Until")),
            source=_safe_str(w.get("Source")) or "IMD",
        ))
    return entries


def _map_nowcast(nowcast_json: dict) -> list[NowcastEntry]:
    """Parse the nowcast section of nowcast_district_api.php response."""
    district = _safe_str(nowcast_json.get("District"))
    raw_list = nowcast_json.get("Nowcast", [])
    if not isinstance(raw_list, list):
        logger.warning("IMD nowcast 'Nowcast' key is not a list.")
        return []

    entries: list[NowcastEntry] = []
    for n in raw_list:
        if not isinstance(n, dict):
            continue
        entries.append(NowcastEntry(
            phenomenon=_safe_str(n.get("Phenomenon")),
            severity=_safe_str(n.get("Severity")),
            description=_safe_str(n.get("Description")),
            district=district,
            issued_time=_safe_str(n.get("Issued_Time")),
            valid_until=_safe_str(n.get("Valid_Until")),
        ))
    return entries
