"""
Travel Advisory Models
======================
Pydantic models for destination-based weather and travel advisories.
"""

from typing import List, Optional
from pydantic import BaseModel


class TravelAlert(BaseModel):
    """Severe weather warning or alert for a travel location."""
    warning_type: str            # e.g. "Yellow Alert", "Dense Fog Advisory"
    severity: str                # "low" | "moderate" | "high"
    title: str
    description: str
    valid_from: Optional[str] = None
    valid_until: Optional[str] = None


class TravelForecastDay(BaseModel):
    """Daily forecast snapshot for a travel destination."""
    date: str                    # "YYYY-MM-DD"
    day_name: str                # "Mon", "Tue", etc.
    min_temp_c: float
    max_temp_c: float
    rain_probability: Optional[float] = None
    rainfall_mm: Optional[float] = None
    condition: str
    weather_code: Optional[str] = None


class LocationSearchResult(BaseModel):
    """Geocoded location result for destination search."""
    name: str
    state: Optional[str] = None
    country: Optional[str] = None
    latitude: float
    longitude: float
    display_name: str


class TravelAdvisoryResponse(BaseModel):
    """
    Structured destination-weather and travel advisory response.
    Never fabricates unavailable infrastructure / transit data.
    """
    destination: str
    destination_resolved: str
    latitude: float
    longitude: float

    # Optional origin / route information
    origin: Optional[str] = None
    origin_resolved: Optional[str] = None
    route_summary: Optional[str] = None

    # Current weather conditions at destination
    temperature: float
    feels_like: float
    condition: str
    weather_code: Optional[str] = None
    humidity: int
    wind_speed: float
    wind_direction: str
    visibility_km: float

    # Temperature extremes & precipitation
    min_temp_c: Optional[float] = None
    max_temp_c: Optional[float] = None
    rainfall_probability: Optional[float] = None
    rainfall_mm: Optional[float] = None
    uv_index: Optional[int] = None
    aqi: Optional[int] = None

    # Risk evaluation derived from actual weather
    risk_level: str              # "low" | "moderate" | "high"
    risk_title: str
    risk_description: str

    # Road & transit conditions (verified or explicitly marked unavailable)
    road_condition: str
    road_data_status: str        # e.g. "Real-time municipal road sensor data unavailable — advisory derived from live meteorological data"
    public_transport_status: str # "Data unavailable"
    airport_status: str          # "Data unavailable"

    # Contextual safety guidelines
    travel_precautions: List[str]

    # Alerts and multi-day forecast
    warnings: List[TravelAlert] = []
    forecast: List[TravelForecastDay] = []

    # Attribution
    source: str
    observation_time: str
