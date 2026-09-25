"""
Weather Service
===============
All weather data originates here — nowhere else.

DemoWeatherService
------------------
Returns hard-coded demo values for Hyderabad.
This is the ONLY place demo values live.

To switch to a real IMD API later:
  1. Create a new class, e.g.  IMDWeatherService
  2. Implement the same  get_weather(city: str) -> WeatherResponse  interface
  3. Swap the import in routes.py — zero other changes needed.
"""

from app.models.weather import WeatherCard, WeatherResponse


class DemoWeatherService:
    """
    Demo implementation that returns static weather data.
    Fulfils the WeatherService contract so it can be swapped
    for a real API service without touching routes or the Flutter UI.
    """

    # ------------------------------------------------------------------ #
    # Demo weather values — edit ONLY here, never in routes or models.    #
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

    def get_weather(self, city: str) -> WeatherResponse:
        """
        Return weather data for the requested city.

        Falls back to Hyderabad demo data for any unknown city so the
        app always returns a valid response during the MVP phase.
        """
        city_key = city.strip().title()
        data = self._DEMO_DATA.get(city_key, self._DEMO_DATA["Hyderabad"])

        # Build fresh WeatherCard list (copies, not shared references)
        cards = [card.model_copy() for card in data["cards"]]

        return WeatherResponse(
            city=city_key if city_key in self._DEMO_DATA else f"{city} (demo: Hyderabad)",
            temperature=data["temperature"],
            humidity=data["humidity"],
            wind_speed=data["wind_speed"],
            condition=data["condition"],
            cards=cards,
        )
