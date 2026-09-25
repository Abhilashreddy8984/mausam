// ============================================================
// data/demo_weather_provider.dart
//
// Provides a WeatherData snapshot populated with hard-coded
// demo values for Hyderabad. This is the ONLY place in the
// codebase that contains demo weather constants.
//
// ┌─────────────────────────────────────────────────────────┐
// │  FUTURE API INTEGRATION POINT                           │
// │                                                         │
// │  To connect a real weather API:                         │
// │  1. Create lib/services/weather_service.dart            │
// │     with a method:                                      │
// │       Future<WeatherData> fetchWeather(String city)     │
// │     that calls IMD / OpenWeatherMap / any provider      │
// │     and maps the JSON response to WeatherData.          │
// │                                                         │
// │  2. In main.dart, replace:                              │
// │       final weather = DemoWeatherProvider.getWeather(); │
// │     with:                                               │
// │       final weather = await WeatherService().           │
// │                           fetchWeather('Hyderabad');    │
// │                                                         │
// │  3. Replace the GPS city string with a Geolocator call. │
// │                                                         │
// │  Nothing in any screen or widget file needs to change.  │
// └─────────────────────────────────────────────────────────┘
// ============================================================

import '../models/weather_data.dart';

class DemoWeatherProvider {
  // Private constructor — this class is never instantiated.
  DemoWeatherProvider._();

  /// Returns the current demo weather snapshot.
  /// Replace this call with a real service call when ready.
  static WeatherData getWeather() {
    return const WeatherData(
      // ── Location ──────────────────────────────────────────
      city: 'Hyderabad',
      state: 'Telangana, India',

      // ── Current conditions ────────────────────────────────
      temperatureC: 32.0,
      feelsLikeC: 35.0,
      humidity: 68,
      weatherCondition: 'Partly Cloudy',
      weatherConditionDetail:
          'Scattered clouds with chance of evening showers',

      // ── Wind ──────────────────────────────────────────────
      windSpeedKmh: 14.0,
      windDirection: 'SW',

      // ── Precipitation ─────────────────────────────────────
      rainfallProbability: 55.0,
      rainfallAmountMm: 8.0,
      rainfallWindow: '4 PM – 7 PM',

      // ── Air quality ───────────────────────────────────────
      aqi: 112,
      aqiCategory: 'Moderate',

      // ── Solar ─────────────────────────────────────────────
      uvIndex: 7,
      uvCategory: 'High',

      // ── Visibility ────────────────────────────────────────
      visibilityKm: 8.5,

      // ── Astronomy ─────────────────────────────────────────
      sunrise: '6:08 AM',
      sunset: '6:24 PM',

      // ── Metadata ──────────────────────────────────────────
      timestamp: null, // null = demo, no real fetch time
    );
  }
}
