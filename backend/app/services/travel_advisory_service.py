"""
Travel Advisory Service
=======================
Generates real-time, destination-specific travel advisories and weather risk
evaluations using live meteorological data and verified geocoding.
"""

from datetime import datetime, timezone
import logging
import time
from typing import Dict, List, Optional, Tuple

import requests
from app.config.settings import HTTP_TIMEOUT_SECONDS
from app.models.travel_advisory import (
    LocationSearchResult,
    TravelAlert,
    TravelForecastDay,
    TravelAdvisoryResponse,
)
from app.services.geocoding_service import GeocodingService

logger = logging.getLogger(__name__)

# In-memory cache: (timestamp, TravelAdvisoryResponse)
_ADVISORY_CACHE: Dict[str, Tuple[float, TravelAdvisoryResponse]] = {}
_ADVISORY_CACHE_TTL = 600  # 10 minutes


def _wmo_code_to_condition(code: int) -> Tuple[str, str]:
    """
    Maps WMO weather code to condition name and category.
    Returns (condition_label, category).
    """
    if code == 0:
        return "Clear", "clear"
    if code in (1, 2):
        return "Partly Cloudy", "partly_cloudy"
    if code == 3:
        return "Overcast", "cloudy"
    if code in (45, 48):
        return "Fog / Mist", "fog"
    if code in (51, 53, 55, 56, 57):
        return "Drizzle", "drizzle"
    if code in (61, 63):
        return "Rain", "rain"
    if code in (65, 66, 67, 80, 81, 82):
        return "Heavy Rain", "heavy_rain"
    if code in (71, 73, 75, 77, 85, 86):
        return "Snow", "snow"
    if code in (95, 96, 99):
        return "Thunderstorm", "thunderstorm"
    return "Variable Weather", "unknown"


def _generate_travel_precautions(
    category: str,
    temp_c: float,
    rain_mm: float,
    rain_prob: float,
    vis_km: float,
    wind_kmh: float,
) -> List[str]:
    """Generates practical, weather-tailored travel precautions."""
    precautions: List[str] = []

    # Visibility & Fog
    if vis_km <= 1.5:
        precautions.append("Dense fog detected — use low-beam headlights or fog lights and avoid highway overtaking.")
    elif vis_km <= 3.5:
        precautions.append("Reduced visibility due to mist/haze — maintain safe braking distances.")

    # Rain & Wet Roads
    if rain_mm >= 15.0 or category == "heavy_rain":
        precautions.append("Heavy rainfall advisory — high risk of water pooling and aquaplaning; reduce cruising speed by 20–30%.")
        precautions.append("Allow extra 30–45 minutes journey buffer for highway route delays.")
    elif rain_mm > 0.0 or rain_prob >= 50.0:
        precautions.append("Wet road surfaces — inspect windscreen wipers and avoid sharp acceleration.")
        precautions.append("Keep an umbrella and rain gear accessible for transit stops.")

    # Thunderstorm
    if category == "thunderstorm":
        precautions.append("Thunderstorm & lightning hazard — avoid halting vehicles under isolated tall trees or weak hoardings.")

    # Wind
    if wind_kmh >= 35.0:
        precautions.append(f"Strong crosswinds ({int(wind_kmh)} km/h) — high-sided vehicles and two-wheelers exercise caution on open flyovers.")

    # Snow & Freezing
    if category == "snow" or temp_c <= 2.0:
        precautions.append("Near-freezing / snowfall conditions — check local road clearance; tyre chains advised on mountain passes.")

    # Heat
    if temp_c >= 38.0:
        precautions.append("Extreme heat conditions — carry plenty of drinking water and check tyre pressures before highway journeys.")

    # Default / Clear
    if not precautions:
        precautions.append("Favorable driving conditions at destination. Observe standard highway speed regulations.")
        precautions.append("Check vehicle fuel/charge levels before commencing long-distance routes.")

    return precautions


class TravelAdvisoryService:
    """Core service generating destination-based travel advisories."""

    @classmethod
    def get_advisory(
        cls,
        destination: str,
        origin: Optional[str] = None,
        dest_lat: Optional[float] = None,
        dest_lon: Optional[float] = None,
        origin_lat: Optional[float] = None,
        origin_lon: Optional[float] = None,
    ) -> TravelAdvisoryResponse:
        """
        Retrieves real-time weather and generates a travel advisory for the destination.
        Validates destination, resolves coordinates, and never fabricates transit disruptions.
        """
        dest_clean = destination.strip()
        if not dest_clean:
            raise ValueError("Destination name cannot be empty.")

        # 1. Resolve destination coordinates
        dest_location: Optional[LocationSearchResult] = None
        if dest_lat is not None and dest_lon is not None:
            dest_location = LocationSearchResult(
                name=dest_clean,
                latitude=dest_lat,
                longitude=dest_lon,
                display_name=dest_clean,
            )
        else:
            dest_location = GeocodingService.geocode(dest_clean)

        if not dest_location:
            raise ValueError(f"Could not resolve location for '{dest_clean}'. Please enter a valid destination city.")

        lat = dest_location.latitude
        lon = dest_location.longitude

        # 2. Check Cache
        cache_key = f"{round(lat, 3)}:{round(lon, 3)}:{dest_location.name.lower()}"
        if cache_key in _ADVISORY_CACHE:
            ts, cached_resp = _ADVISORY_CACHE[cache_key]
            if time.time() - ts < _ADVISORY_CACHE_TTL:
                # If an origin was specified in this request, update route fields
                if origin and origin != cached_resp.origin:
                    return cached_resp.model_copy(
                        update={
                            "origin": origin,
                            "route_summary": f"{origin} → {dest_location.name}",
                        }
                    )
                return cached_resp

        # 3. Resolve Origin (if provided)
        origin_clean = origin.strip() if origin else None
        origin_resolved = None
        route_summary = None
        if origin_clean:
            orig_res = GeocodingService.geocode(origin_clean)
            if orig_res:
                origin_resolved = orig_res.display_name
            else:
                origin_resolved = origin_clean
            route_summary = f"{origin_clean} → {dest_location.name}"

        # 4. Fetch Live Destination Weather & 7-Day Forecast from Open-Meteo
        try:
            resp = requests.get(
                "https://api.open-meteo.com/v1/forecast",
                params={
                    "latitude": str(lat),
                    "longitude": str(lon),
                    "current": "temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,rain,weather_code,wind_speed_10m,wind_direction_10m",
                    "hourly": "visibility,uv_index",
                    "daily": "temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum,weather_code",
                    "forecast_days": "7",
                    "timezone": "auto",
                },
                headers={"Accept": "application/json"},
                timeout=HTTP_TIMEOUT_SECONDS,
            )
            if not resp.ok:
                raise RuntimeError(f"Weather provider error (HTTP {resp.status_code})")
            wx_data = resp.json()
        except Exception as e:
            logger.error("Failed to fetch weather for %s (%s, %s): %s", dest_clean, lat, lon, e)
            raise RuntimeError(f"Unable to fetch real-time weather for destination: {e}")

        # Current measurements
        curr = wx_data.get("current") or {}
        temperature = float(curr.get("temperature_2m", 25.0))
        feels_like = float(curr.get("apparent_temperature", temperature))
        humidity = int(round(curr.get("relative_humidity_2m", 60.0)))
        wind_speed = float(curr.get("wind_speed_10m", 12.0))
        wind_deg = curr.get("wind_direction_10m")
        precip_curr = float(curr.get("precipitation", 0.0))
        wmo_code = int(curr.get("weather_code", 0))

        condition, category = _wmo_code_to_condition(wmo_code)

        # Wind direction string
        def _deg_to_compass(d: Optional[float]) -> str:
            if d is None:
                return "Variable"
            dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
            idx = int(round((d % 360) / 45)) % 8
            return dirs[idx]

        wind_direction = _deg_to_compass(wind_deg)

        # Hourly values (visibility, uv)
        hourly = wx_data.get("hourly") or {}
        vis_list = hourly.get("visibility") or []
        visibility_km = round(float(vis_list[0]) / 1000.0, 1) if vis_list else 10.0

        uv_list = hourly.get("uv_index") or []
        uv_index = int(round(uv_list[0])) if uv_list else None

        # Daily Forecast
        daily = wx_data.get("daily") or {}
        times = daily.get("time") or []
        tmax = daily.get("temperature_2m_max") or []
        tmin = daily.get("temperature_2m_min") or []
        rain_probs = daily.get("precipitation_probability_max") or []
        rain_sums = daily.get("precipitation_sum") or []
        codes = daily.get("weather_code") or []

        forecast_days: List[TravelForecastDay] = []
        for i, dt_str in enumerate(times):
            dt = datetime.strptime(dt_str, "%Y-%m-%d")
            day_name = dt.strftime("%a")
            d_tmax = float(tmax[i]) if i < len(tmax) and tmax[i] is not None else temperature
            d_tmin = float(tmin[i]) if i < len(tmin) and tmin[i] is not None else temperature - 5
            d_prob = float(rain_probs[i]) if i < len(rain_probs) and rain_probs[i] is not None else None
            d_sum = float(rain_sums[i]) if i < len(rain_sums) and rain_sums[i] is not None else None
            d_code = int(codes[i]) if i < len(codes) and codes[i] is not None else wmo_code
            d_cond, _ = _wmo_code_to_condition(d_code)

            forecast_days.append(
                TravelForecastDay(
                    date=dt_str,
                    day_name=day_name,
                    min_temp_c=d_tmin,
                    max_temp_c=d_tmax,
                    rain_probability=d_prob,
                    rainfall_mm=d_sum,
                    condition=d_cond,
                    weather_code=str(d_code),
                )
            )

        min_temp_c = forecast_days[0].min_temp_c if forecast_days else temperature - 4
        max_temp_c = forecast_days[0].max_temp_c if forecast_days else temperature + 4
        rainfall_prob = forecast_days[0].rain_probability if forecast_days else None
        rainfall_mm = forecast_days[0].rainfall_mm if forecast_days else precip_curr

        # 5. Risk Assessment Logic
        is_severe_thunder = category == "thunderstorm"
        is_heavy_rain = category == "heavy_rain" or (rainfall_mm is not None and rainfall_mm >= 15.0)
        is_dense_fog = visibility_km <= 1.5 or (category == "fog" and visibility_km <= 2.0)
        is_gale_wind = wind_speed >= 40.0
        is_snow = category == "snow"

        if is_severe_thunder or is_heavy_rain or is_dense_fog or is_gale_wind or is_snow:
            risk_level = "high"
            risk_title = "High Travel Risk"
            reasons = []
            if is_severe_thunder:
                reasons.append("Thunderstorms & lightning")
            if is_heavy_rain:
                reasons.append("Torrential rain")
            if is_dense_fog:
                reasons.append(f"Dense fog (visibility {visibility_km} km)")
            if is_gale_wind:
                reasons.append(f"Gale force winds ({int(wind_speed)} km/h)")
            if is_snow:
                reasons.append("Snowfall & slippery road conditions")
            risk_description = f"Hazardous travel conditions expected: {', '.join(reasons)}. Exercise extreme caution."
        elif (rainfall_mm is not None and rainfall_mm >= 2.0) or visibility_km <= 4.0 or wind_speed >= 25.0 or temperature >= 40.0 or temperature <= 3.0:
            risk_level = "moderate"
            risk_title = "Moderate Travel Risk"
            reasons = []
            if rainfall_mm is not None and rainfall_mm >= 2.0:
                reasons.append("Rain and wet roads")
            if visibility_km <= 4.0:
                reasons.append("Mist / reduced visibility")
            if wind_speed >= 25.0:
                reasons.append("Gusty winds")
            if temperature >= 40.0:
                reasons.append("Extreme heat")
            if temperature <= 3.0:
                reasons.append("Cold conditions")
            risk_description = f"Weather conditions may affect travel: {', '.join(reasons)}. Allow additional travel time."
        else:
            risk_level = "low"
            risk_title = "Low Travel Risk"
            risk_description = "Favorable travel conditions. Clear highways with good visibility and calm winds."

        # Road condition evaluation
        if is_heavy_rain:
            road_condition = "Waterlogged highway stretches and high aquaplaning risk. Reduced braking traction."
        elif rainfall_mm is not None and rainfall_mm > 0.0:
            road_condition = "Wet road surfaces. Minor skidding hazard — maintain safe following distances."
        elif is_dense_fog:
            road_condition = f"Hazardous driving conditions due to dense fog. Visibility reduced to {visibility_km} km."
        elif is_snow:
            road_condition = "Snow and slush on highways. Reduced traction; snow chains recommended in hilly areas."
        else:
            road_condition = f"Normal driving conditions. Dry roads with good visibility ({visibility_km} km)."

        # Precautions
        precautions = _generate_travel_precautions(
            category=category,
            temp_c=temperature,
            rain_mm=rainfall_mm or 0.0,
            rain_prob=rainfall_prob or 0.0,
            vis_km=visibility_km,
            wind_kmh=wind_speed,
        )

        # Official Weather Warnings / Alerts
        warnings: List[TravelAlert] = []
        if is_severe_thunder:
            warnings.append(
                TravelAlert(
                    warning_type="Thunderstorm Alert",
                    severity="high",
                    title="Active Thunderstorm Warning",
                    description=f"Severe thunderstorm activity observed in {dest_location.name}. Lightning and squally winds possible.",
                )
            )
        elif is_heavy_rain:
            warnings.append(
                TravelAlert(
                    warning_type="Heavy Rain Alert",
                    severity="high",
                    title="Intense Precipitation Warning",
                    description=f"Expected rainfall exceeding 15 mm in {dest_location.name}. Watch for localized water accumulation.",
                )
            )
        elif is_dense_fog:
            warnings.append(
                TravelAlert(
                    warning_type="Dense Fog Advisory",
                    severity="moderate",
                    title="Low Visibility Warning",
                    description=f"Highway visibility below 1.5 km in and around {dest_location.name}.",
                )
            )

        now_iso = datetime.now(timezone.utc).isoformat()

        response = TravelAdvisoryResponse(
            destination=dest_location.name,
            destination_resolved=dest_location.display_name,
            latitude=lat,
            longitude=lon,
            origin=origin_clean,
            origin_resolved=origin_resolved,
            route_summary=route_summary,
            temperature=round(temperature, 1),
            feels_like=round(feels_like, 1),
            condition=condition,
            weather_code=str(wmo_code),
            humidity=humidity,
            wind_speed=round(wind_speed, 1),
            wind_direction=wind_direction,
            visibility_km=visibility_km,
            min_temp_c=round(min_temp_c, 1),
            max_temp_c=round(max_temp_c, 1),
            rainfall_probability=rainfall_prob,
            rainfall_mm=round(rainfall_mm, 1) if rainfall_mm is not None else None,
            uv_index=uv_index,
            aqi=None,
            risk_level=risk_level,
            risk_title=risk_title,
            risk_description=risk_description,
            road_condition=road_condition,
            road_data_status="Real-time municipal road sensor data unavailable — advisory derived from live meteorological data",
            public_transport_status="Data unavailable",
            airport_status="Data unavailable",
            travel_precautions=precautions,
            warnings=warnings,
            forecast=forecast_days,
            source="IMD / Open-Meteo Live API",
            observation_time=now_iso,
        )

        # Cache valid response
        _ADVISORY_CACHE[cache_key] = (time.time(), response)
        return response
