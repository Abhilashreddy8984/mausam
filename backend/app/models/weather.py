"""
Pydantic models for weather data.

WeatherCard     - a single ranked card shown on the homepage.
WeatherResponse - the full weather payload for a city.

Change log
----------
v0.2  Added optional `source` field to WeatherResponse.
v0.3  Added optional `ranking_reasons` field to WeatherCard.
      Both new fields are Optional with None defaults so that:
        - existing Flutter code is completely unaffected
        - development tools can inspect scoring explanations
"""

from typing import List, Optional
from pydantic import BaseModel


class WeatherCard(BaseModel):
    """
    Represents one weather information card on the personalized homepage.

    Fields
    ------
    type             : Internal identifier, e.g. "temperature", "rain_alert".
    title            : Human-readable card title shown in the UI.
    value            : The numeric or textual measurement value.
    unit             : Unit of measurement, e.g. "°C", "%", "km/h".
    severity         : One of "low" | "medium" | "high" — drives UI colour.
    score            : Relevance score assigned by the ranking service.
                       Flutter UI uses this to order cards.
    ranking_reasons  : (optional, development only) Human-readable list
                       explaining why this card received its score.
                       Flutter ignores unknown JSON fields — fully
                       backward-compatible with the existing Flutter model.
                       Not shown in the production UI.
    """

    type: str
    title: str
    value: str
    unit: str
    severity: str                            # "low" | "medium" | "high"
    score: float = 0.0                       # assigned by RankingService
    ranking_reasons: Optional[List[str]] = None  # debug only; Flutter ignores


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
    cards       : List of WeatherCards, ordered by relevance for the persona.
    source      : (optional) Which weather provider produced this response.
                  "demo" for DemoWeatherProvider.
                  "IMD"  for the future IMDWeatherProvider.
                  Flutter ignores unknown / missing fields — fully
                  backward-compatible with the existing Flutter model.
    """

    city: str
    temperature: float
    humidity: float
    wind_speed: float
    condition: str
    cards: List[WeatherCard]
    source: Optional[str] = None  # backward-compatible; Flutter ignores it
