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

Official IMD current_wx field names (api.imd.gov.in/public/api_reference.html)
-------------------------------------------------------------------------------
Field name in API response → Description
  "Station Id"             → Numeric station identifier
  "Station"                → Station name
  "Date of Observation"    → YYYY-mm-dd
  "Time of Observation"    → UTC time
  "M.S.L.P"               → Mean Sea Level Pressure in hPa
  "Wind Direction"         → Numeric code (see Wind Direction table in docs)
  "Wind Speed"             → km/h
  "Temperature"            → °C
  "Weather Code"           → 01–99 (see Weather Code table in docs)
  "Nebulosity"             → 0–8 (cloud coverage)
  "Humidity"               → %
  "Last 24 hrs Rainfall"   → mm

Note: The official current_wx response does NOT include Feels_Like,
Visibility, UV_Index, or district/state fields.  Those are absent from
the spec and are mapped to None when missing.

Wind direction code → compass string mapping is included below.
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
# Wind direction code → compass string
# Source: official IMD API wind direction table
# ---------------------------------------------------------------------------
_WIND_DIR_MAP: dict[int, str] = {
    0:   "Calm",
    20:  "NNE",
    50:  "NE",
    70:  "ENE",
    90:  "E",
    110: "ESE",
    140: "SE",
    160: "SSE",
    180: "S",
    200: "SSW",
    230: "SW",
    250: "WSW",
    270: "W",
    290: "WNW",
    320: "NW",
    340: "NNW",
    360: "N",
}


def _wind_dir_to_compass(code: Any) -> str | None:
    """
    Convert an IMD wind direction code to a compass abbreviation.
    Returns None if the code is missing or not recognised.
    """
    val = _safe_int(code)
    if val is None:
        return None
    # Find the nearest entry in the table
    closest = min(_WIND_DIR_MAP.keys(), key=lambda k: abs(k - val))
    return _WIND_DIR_MAP[closest]


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

def _normalize_current_response(current_json: Any) -> dict:
    """
    Normalize the current_wx response to a single station dict.

    The official IMD current_wx endpoint returns a JSON ARRAY of station
    objects, for example:

        [
          {"Station Id": "43128", "Station": "Hyderabad", "Temperature": "30", ...},
          {"Station Id": "43129", "Station": "Secunderabad", ...}
        ]

    Station selection logic:
      1. If a station ID is configured (IMD_STATION_ID env var), select the
         dict whose "Station Id" matches it.
      2. If the configured station is NOT found in the list, fail safely by
         returning an empty dict — we never silently use another city's
         weather.
      3. If no station ID is configured (None), fall back to the first dict
         in the list (backward compatibility for tests and single-station
         responses).

    If the response is already a dict (single-station shape), it is
    returned unchanged so existing fixtures and tests continue to work.

    Returns an empty dict for None, empty list, or unexpected types so
    downstream .get() calls never raise.
    """
    if current_json is None:
        return {}
    if isinstance(current_json, dict):
        return current_json
    if isinstance(current_json, list):
        if not current_json:
            logger.warning("IMD current_wx returned an empty list.")
            return {}

        # Read the configured station ID from settings at call time
        # so tests can patch it and production picks up .env values.
        from app.config import settings as _s
        configured_station_id = _s.IMD_STATION_ID

        # ── If a station ID is configured, select the matching station ──
        if configured_station_id:
            target_id = str(configured_station_id).strip()
            for item in current_json:
                if not isinstance(item, dict):
                    continue
                item_id = _safe_str(item.get("Station Id"))
                if item_id is not None and item_id == target_id:
                    return item
            # Configured station not found — fail safely
            available = [
                _safe_str(item.get("Station Id"))
                for item in current_json
                if isinstance(item, dict)
            ]
            logger.warning(
                "IMD current_wx list did not contain station Id='%s'. "
                "Available station IDs: %s. "
                "Returning empty response — will NOT use another city's weather.",
                target_id,
                available,
            )
            return {}

        # ── No station ID configured — fall back to first dict ──
        for item in current_json:
            if isinstance(item, dict):
                return item
        logger.warning("IMD current_wx list contained no dict objects.")
        return {}

    logger.warning(
        "IMD current_wx response was neither a dict nor a list (got %s).",
        type(current_json).__name__,
    )
    return {}


def map_current_weather(
    current_json: dict | list | None,
    forecast_json: dict | None = None,
    warnings_json: dict | None = None,
    nowcast_json: dict | None = None,
) -> WeatherResponse:
    """
    Build a WeatherResponse from one or more raw IMD API responses.

    Parameters
    ----------
    current_json   : Parsed JSON from current_wx endpoint.
                     May be a dict (single station) or a list of station
                     dicts (official array response). A list is normalized
                     to the station whose "Station Id" matches the configured
                     IMD_STATION_ID, with safe fallback to an empty response
                     if the configured station is not found.
    forecast_json  : Parsed JSON from cityforecastloc endpoint (optional).
    warnings_json  : Parsed JSON from districtwarning endpoint (optional).
    nowcast_json   : Parsed JSON from districtnowcast endpoint (optional).

    Returns
    -------
    WeatherResponse populated with all available fields.
    Missing fields are None / empty list — never raises.

    Field name strategy
    -------------------
    We try the official current_wx field names first (from the IMD API
    reference), then fall back to the older invented names so that
    existing test fixtures continue to work.

    Official names  → fallback names
    "Station"       → "Station_Name"
    "Temperature"   → "Temp"
    "Humidity"      → "RH"
    "Wind Speed"    → "Wind_Speed"
    "Wind Direction"→ "Wind_Dir"   (official is a numeric code; converted)
    "Last 24 hrs Rainfall" → "Rainfall"
    "M.S.L.P"      → "Pressure"
    "Weather Code"  → "Weather_Code"  (same key in both)
    "Date of Observation" + "Time of Observation" → "Obs_Time"
    "Nebulosity"    → "Cloud_Cover"

    Fields NOT in the official current_wx spec (no official fallback):
      Feels_Like, Visibility, UV_Index, District, State, Lat, Lon
    These remain supported if present in the response (some stations
    may return extended fields), but are not required.
    """
    # ── Normalize: official current_wx returns a list of station objects ─
    # Select the station whose "Station Id" matches the configured
    # IMD_STATION_ID, with safe fallback if not found. If the response is
    # already a single dict it is used as-is.
    current_json = _normalize_current_response(current_json)

    # ── Parse current weather fields ──────────────────────────
    # Try official field names first, fall back to legacy names.

    # Station name: official "Station", fallback "Station_Name"
    city = (
        _safe_str(current_json.get("Station"))
        or _safe_str(current_json.get("Station_Name"))
        or "Unknown"
    )

    # Not in official spec — may be present in extended responses
    district = _safe_str(current_json.get("District"))
    state    = _safe_str(current_json.get("State"))
    lat      = _safe_float(current_json.get("Lat") or current_json.get("Latitude"))
    lon      = _safe_float(current_json.get("Lon") or current_json.get("Longitude"))

    # Temperature: official "Temperature", fallback "Temp"
    _temp_official = _safe_float(current_json.get("Temperature"))
    _temp_legacy   = _safe_float(current_json.get("Temp"))
    temperature = _temp_official if _temp_official is not None else _temp_legacy

    # Humidity: official "Humidity", fallback "RH"
    _hum_official = _safe_float(current_json.get("Humidity"))
    _hum_legacy   = _safe_float(current_json.get("RH"))
    humidity = _hum_official if _hum_official is not None else _hum_legacy

    # Wind speed: official "Wind Speed", fallback "Wind_Speed"
    _ws_official = _safe_float(current_json.get("Wind Speed"))
    _ws_legacy   = _safe_float(current_json.get("Wind_Speed"))
    wind_speed = _ws_official if _ws_official is not None else _ws_legacy

    # Wind direction: official field is a numeric code ("Wind Direction"),
    # legacy field is a compass string ("Wind_Dir").
    raw_wind_dir = current_json.get("Wind Direction") or current_json.get("Wind_Dir")
    if raw_wind_dir is not None:
        # Try to parse as numeric code first (official), fall back to string
        code_val = _safe_int(raw_wind_dir)
        if code_val is not None:
            wind_dir = _wind_dir_to_compass(code_val)
        else:
            wind_dir = _safe_str(raw_wind_dir)
    else:
        wind_dir = None

    # Rainfall: official "Last 24 hrs Rainfall", fallback "Rainfall"
    # IMPORTANT: use explicit None check, not `or`, because 0.0 is falsy
    _rain_official = _safe_float(current_json.get("Last 24 hrs Rainfall"))
    _rain_legacy   = _safe_float(current_json.get("Rainfall"))
    rainfall_mm = _rain_official if _rain_official is not None else _rain_legacy

    # Nebulosity / cloud cover: official "Nebulosity" (0-8 scale),
    # fallback "Cloud_Cover"
    _neb_official = _safe_float(current_json.get("Nebulosity"))
    _neb_legacy   = _safe_float(current_json.get("Cloud_Cover"))
    nebulosity_raw = _neb_official if _neb_official is not None else _neb_legacy
    # Convert Nebulosity (0–8) to percentage (0–100) if it looks like a
    # 0–8 scale value; otherwise keep as-is (legacy may already be %).
    if nebulosity_raw is not None and nebulosity_raw <= 8:
        cloud_cover = round(nebulosity_raw / 8.0 * 100, 1)
    else:
        cloud_cover = nebulosity_raw

    # Pressure: official "M.S.L.P", fallback "Pressure"
    _pres_official = _safe_float(current_json.get("M.S.L.P"))
    _pres_legacy   = _safe_float(current_json.get("Pressure"))
    pressure = _pres_official if _pres_official is not None else _pres_legacy

    # Visibility — NOT in official current_wx spec; may exist in extended
    visibility = _safe_float(current_json.get("Visibility"))

    # UV index — NOT in official current_wx spec
    uv_index = _safe_int(current_json.get("UV_Index"))

    # Feels like — NOT in official current_wx spec
    feels_like = _safe_float(current_json.get("Feels_Like"))

    # Weather code: same key in both official and legacy
    weather_code = _safe_str(current_json.get("Weather Code") or current_json.get("Weather_Code"))

    # Condition description from weather code
    condition = _weather_code_to_desc(weather_code) or _safe_str(current_json.get("Weather_Desc")) or "Unknown"

    # Observation time: combine Date + Time (official) or use legacy "Obs_Time"
    obs_date = _safe_str(current_json.get("Date of Observation"))
    obs_time_utc = _safe_str(current_json.get("Time of Observation"))
    if obs_date and obs_time_utc:
        obs_time = f"{obs_date}T{obs_time_utc}Z"
    else:
        obs_time = _safe_str(current_json.get("Obs_Time"))

    # Guard: log warnings for missing critical fields
    if temperature is None:
        logger.warning(
            "IMD current weather response missing temperature for station '%s'. "
            "Ranking engine will skip temperature context adjustments.",
            city,
        )
    if humidity is None:
        logger.warning(
            "IMD current weather response missing humidity for station '%s'.", city,
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
        aqi=None,   # IMD current_wx does not include AQI
        visibility_km=visibility,
        condition=condition,
    )

    # ── Map supplementary data ────────────────────────────────
    forecast = _map_forecast(forecast_json) if forecast_json else []
    warnings = _map_warnings(warnings_json) if warnings_json else []
    nowcast  = _map_nowcast(nowcast_json)   if nowcast_json  else []

    return WeatherResponse(
        city=city,
        temperature=temperature if temperature is not None else 0.0,
        humidity=humidity if humidity is not None else 0.0,
        wind_speed=wind_speed if wind_speed is not None else 0.0,
        condition=condition,
        cards=cards,
        source="IMD",
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


def _weather_code_to_desc(code: str | None) -> str | None:
    """
    Convert an IMD weather code (01–99) to a short human-readable description.
    Based on the official Weather Code Description table in the IMD API docs.
    Returns None if the code is unknown.
    """
    if code is None:
        return None
    _MAP = {
        "01": "Clouds dissolving", "02": "Sky unchanged", "03": "Clouds forming",
        "05": "Haze", "10": "Mist",
        "17": "Thunderstorm (no precipitation)", "20": "Drizzle or snow grains",
        "21": "Rain (not shower)", "22": "Snow", "25": "Rain showers",
        "28": "Fog or ice fog", "29": "Thunderstorm",
        "41": "Fog patches", "45": "Fog (sky invisible)",
        "50": "Drizzle slight intermittent", "51": "Drizzle slight continuous",
        "52": "Drizzle moderate intermittent", "53": "Drizzle moderate continuous",
        "60": "Rain slight intermittent", "61": "Rain slight continuous",
        "62": "Rain moderate intermittent", "63": "Rain moderate continuous",
        "64": "Rain heavy intermittent", "65": "Rain heavy continuous",
        "80": "Rain shower (slight)", "81": "Rain shower (moderate/heavy)",
        "95": "Thunderstorm with rain/snow",
        "99": "Thunderstorm heavy with hail",
    }
    return _MAP.get(str(code).strip().zfill(2))


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
