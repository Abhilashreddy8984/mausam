"""
Demo Weather Provider
=====================
Implements WeatherProvider using hard-coded demo values for Hyderabad.

This is the DEFAULT provider for local development and the SIH prototype.

⚠  ALL demo weather values live only in this file.
   Do not scatter hard-coded weather values anywhere else in the backend.

Replacing this provider with a real API
----------------------------------------
  1. Create a new class (e.g. IMDWeatherProvider) in its own file.
  2. Implement the same WeatherProvider interface (get_weather method).
  3. Register the new class in app/services/provider_factory.py.
  4. Set WEATHER_PROVIDER=imd (or the chosen key) in your environment.
  5. Routes, ranking, and Flutter require zero changes.
"""

from app.models.weather import WeatherCard, WeatherResponse
from app.services.weather_provider import LocationQuery, WeatherProvider


class DemoWeatherProvider(WeatherProvider):
    """
    Returns static demo weather data.

    Falls back to Hyderabad data for any unknown city so the app always
    returns a valid response during development.

    source = "demo" is set on every response so callers can identify
    that the data is not live.
    """

    # ------------------------------------------------------------------ #
    # Demo weather values                                                  #
    # Edit ONLY here — never in routes, models, or ranking.               #
    # ------------------------------------------------------------------ #
    _DEMO_DATA: dict = {
        "Hyderabad": {
            "temperature": 32.5,
            "humidity": 68.0,
            "wind_speed": 14.0,
            "condition": "Partly Cloudy",
            "cards": [
                WeatherCard(
                    type="temperature",
                    title="Temperature",
                    value="32.5",
                    unit="°C",
                    severity="medium",
                ),
                WeatherCard(
                    type="humidity",
                    title="Humidity",
                    value="68",
                    unit="%",
                    severity="medium",
                ),
                WeatherCard(
                    type="wind_speed",
                    title="Wind Speed",
                    value="14",
                    unit="km/h",
                    severity="low",
                ),
                WeatherCard(
                    type="rain_alert",
                    title="Rain Alert",
                    value="Possible showers in the evening",
                    unit="",
                    severity="medium",
                ),
                WeatherCard(
                    type="uv_index",
                    title="UV Index",
                    value="7",
                    unit="",
                    severity="high",
                ),
                WeatherCard(
                    type="air_quality",
                    title="Air Quality Index",
                    value="142",
                    unit="AQI",
                    severity="medium",
                ),
                WeatherCard(
                    type="visibility",
                    title="Visibility",
                    value="8",
                    unit="km",
                    severity="low",
                ),
                WeatherCard(
                    type="feels_like",
                    title="Feels Like",
                    value="36",
                    unit="°C",
                    severity="medium",
                ),
                WeatherCard(
                    type="sunrise_sunset",
                    title="Sunrise / Sunset",
                    value="06:08 / 18:22",
                    unit="",
                    severity="low",
                ),
                WeatherCard(
                    type="pollen",
                    title="Pollen Level",
                    value="Moderate",
                    unit="",
                    severity="medium",
                ),
            ],
        }
    }

    def get_weather(self, location: LocationQuery) -> WeatherResponse:
        """
        Return demo weather data for the requested city.

        Falls back to Hyderabad demo data for any unknown city so the
        app always returns a valid response during the MVP phase.
        """
        city_key = location.city.strip().title()
        data = self._DEMO_DATA.get(city_key, self._DEMO_DATA["Hyderabad"])

        # Build fresh WeatherCard list (copies, not shared references)
        cards = [card.model_copy() for card in data["cards"]]

        display_city = (
            city_key
            if city_key in self._DEMO_DATA
            else f"{location.city} (demo: Hyderabad)"
        )

        return WeatherResponse(
            city=display_city,
            temperature=data["temperature"],
            humidity=data["humidity"],
            wind_speed=data["wind_speed"],
            condition=data["condition"],
            cards=cards,
            source="demo",  # identifies this as demo data
        )
