// ============================================================
// models/weather_data.dart
//
// Structured model representing a complete weather snapshot
// for one location at one point in time.
//
// Design rules:
//   - Fields that are ALWAYS available from any source are
//     non-nullable (city, state, temperatureC, condition).
//   - Fields that may be absent in partial API responses or
//     sensor failures are nullable (aqi, uvIndex, etc.).
//   - All fields are final — WeatherData is immutable.
//   - copyWith() allows creating updated snapshots without
//     mutating the original (useful for incremental API updates).
//
// To swap demo data for a real API later:
//   Replace DemoWeatherProvider.getWeatherData() in
//   lib/data/demo_weather_provider.dart with a call to
//   lib/services/weather_service.dart (to be created).
//   Nothing in this file or in any UI file needs to change.
// ============================================================

import '../services/advisory_service.dart';
import 'weather_alert.dart';
import 'weather_code_system.dart';
export 'weather_alert.dart';
export 'weather_code_system.dart';

class WeatherData {
  // ── Location ──────────────────────────────────────────────
  final String city;
  final String state;

  // ── Current conditions ────────────────────────────────────
  final double temperatureC;
  final double feelsLikeC;
  final int humidity; // percent (0-100)
  final String weatherCondition; // e.g. "Partly Cloudy"
  final String weatherConditionDetail; // one-line elaboration

  // ── Wind ──────────────────────────────────────────────────
  final double windSpeedKmh;
  final String windDirection; // e.g. "SW"

  // ── Precipitation ─────────────────────────────────────────
  final double? rainfallProbability; // percent (0-100), nullable
  final double? rainfallAmountMm; // nullable: may be absent in forecast
  final String? rainfallWindow; // e.g. "4 PM – 7 PM"

  // ── Air quality ───────────────────────────────────────────
  final int? aqi; // nullable: sensor may be offline
  final String? aqiCategory; // e.g. "Moderate"

  // ── Solar ─────────────────────────────────────────────────
  final int? uvIndex; // nullable: not available at night
  final String? uvCategory; // e.g. "High"

  // ── Visibility ────────────────────────────────────────────
  final double visibilityKm;

  // ── Astronomy ─────────────────────────────────────────────
  final String? sunrise; // e.g. "6:08 AM"
  final String? sunset; // e.g. "6:24 PM"

  // ── Metadata ──────────────────────────────────────────────
  /// Source identifier of the weather data (e.g. "IMD", "demo", "Open-Meteo").
  final String? source;

  /// When this snapshot was fetched/created.
  /// Null when using demo data (no real timestamp available).
  final DateTime? timestamp;

  // ── Weather code metadata ──────────────────────────────────
  /// Provider-specific weather condition code (e.g., IMD "5" for Haze).
  final String? weatherCode;

  /// Code authority system (IMD observation or WMO forecast).
  final WeatherCodeSystem? weatherCodeSystem;

  // ── Alerts & Advisories ───────────────────────────────────
  /// Active weather alerts or advisories for this snapshot.
  final List<WeatherAlert> alerts;

  const WeatherData({
    required this.city,
    required this.state,
    required this.temperatureC,
    required this.feelsLikeC,
    required this.humidity,
    required this.weatherCondition,
    required this.weatherConditionDetail,
    required this.windSpeedKmh,
    required this.windDirection,
    this.rainfallProbability,
    this.rainfallAmountMm,
    this.rainfallWindow,
    this.aqi,
    this.aqiCategory,
    this.uvIndex,
    this.uvCategory,
    required this.visibilityKm,
    this.sunrise,
    this.sunset,
    this.source,
    this.timestamp,
    this.weatherCode,
    this.weatherCodeSystem,
    this.alerts = const [],
  });

  /// The active primary alert. If no explicit alert was passed in,
  /// resolved dynamically via [AdvisoryService.resolveAlert].
  WeatherAlert get primaryAlert =>
      alerts.isNotEmpty ? alerts.first : AdvisoryService.resolveAlert(this);

  // ── Convenience display helpers ────────────────────────────

  /// Temperature as a rounded integer string, e.g. "32".
  String get tempInt => temperatureC.toInt().toString();

  /// Feels-like as a rounded integer string, e.g. "35".
  String get feelsLikeInt => feelsLikeC.toInt().toString();

  /// Wind speed as a rounded integer string, e.g. "14".
  String get windSpeedInt => windSpeedKmh.toInt().toString();

  /// Visibility formatted with one decimal, e.g. "8.5".
  String get visibilityStr =>
      visibilityKm == visibilityKm.roundToDouble()
          ? visibilityKm.toInt().toString()
          : visibilityKm.toStringAsFixed(1);

  /// Full location label, e.g. "Hyderabad, Telangana, India".
  String get fullLocation => '$city, $state';

  // ── copyWith ───────────────────────────────────────────────
  WeatherData copyWith({
    String? city,
    String? state,
    double? temperatureC,
    double? feelsLikeC,
    int? humidity,
    String? weatherCondition,
    String? weatherConditionDetail,
    double? windSpeedKmh,
    String? windDirection,
    double? rainfallProbability,
    double? rainfallAmountMm,
    String? rainfallWindow,
    int? aqi,
    String? aqiCategory,
    int? uvIndex,
    String? uvCategory,
    double? visibilityKm,
    String? sunrise,
    String? sunset,
    String? source,
    DateTime? timestamp,
    String? weatherCode,
    WeatherCodeSystem? weatherCodeSystem,
    List<WeatherAlert>? alerts,
  }) {
    return WeatherData(
      city: city ?? this.city,
      state: state ?? this.state,
      temperatureC: temperatureC ?? this.temperatureC,
      feelsLikeC: feelsLikeC ?? this.feelsLikeC,
      humidity: humidity ?? this.humidity,
      weatherCondition: weatherCondition ?? this.weatherCondition,
      weatherConditionDetail:
          weatherConditionDetail ?? this.weatherConditionDetail,
      windSpeedKmh: windSpeedKmh ?? this.windSpeedKmh,
      windDirection: windDirection ?? this.windDirection,
      rainfallProbability:
          rainfallProbability ?? this.rainfallProbability,
      rainfallAmountMm: rainfallAmountMm ?? this.rainfallAmountMm,
      rainfallWindow: rainfallWindow ?? this.rainfallWindow,
      aqi: aqi ?? this.aqi,
      aqiCategory: aqiCategory ?? this.aqiCategory,
      uvIndex: uvIndex ?? this.uvIndex,
      uvCategory: uvCategory ?? this.uvCategory,
      visibilityKm: visibilityKm ?? this.visibilityKm,
      sunrise: sunrise ?? this.sunrise,
      sunset: sunset ?? this.sunset,
      source: source ?? this.source,
      timestamp: timestamp ?? this.timestamp,
      weatherCode: weatherCode ?? this.weatherCode,
      weatherCodeSystem: weatherCodeSystem ?? this.weatherCodeSystem,
      alerts: alerts ?? this.alerts,
    );
  }
}
