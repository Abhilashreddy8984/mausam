"""
Pydantic models for weather data.

WeatherCard  - a single ranked card shown on the homepage.
WeatherResponse - the full weather payload for a city.
"""

from typing import List, Optional
from pydantic import BaseModel


class WeatherCard(BaseModel):
    """
    Represents one weather information card on the personalized homepage.

    Fields
    ------
    type     : Internal identifier, e.g. "temperature", "rain_alert".
    title    : Human-readable card title shown in the UI.
    value    : The numeric or textual measurement value.
    unit     : Unit of measurement, e.g. "°C", "%", "km/h".
    severity : One of "low" | "medium" | "high" — drives UI colour coding.
    score    : Relevance score assigned by the ranking service (higher = more relevant).
               Flutter UI uses this to order cards. Not shown to the user directly.
    """

    type: str
    title: str
    value: str
    unit: str
    severity: str          # "low" | "medium" | "high"
    score: float = 0.0     # assigned by RankingService; default 0


class WeatherResponse(BaseModel):
    """
    Complete weather response returned by the /weather and /homepage endpoints.

    Fields
    ------
    city        : Name of the city.
    temperature : Current temperature in °C.
    humidity    : Relative humidity percentage.
    wind_speed  : Wind speed in km/h.
    condition   : Short text description, e.g. "Partly Cloudy".
    cards       : List of WeatherCards, ordered by relevance for the requested persona.
    """

    city: str
    temperature: float
    humidity: float
    wind_speed: float
    condition: str
    cards: List[WeatherCard]
