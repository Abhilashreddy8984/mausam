// ============================================================
// models/weather_experience.dart
//
// High-level weather experience state derived from WeatherData.
//
// PURPOSE
// -------
// WeatherData holds raw measurements (temperature, AQI, wind speed,
// etc.). This file converts those raw values into a single human-
// readable experience state — one answer to "what is the weather
// LIKE right now?" — suitable for driving UI banners, badges, or
// accessibility descriptions.
//
// DESIGN RULES
// ------------
// - Uses ONLY fields that already exist in WeatherData.
//   No new API fields are invented or assumed.
// - Thresholds are application-level UX triggers, NOT official IMD
//   advisory thresholds or scientifically validated values.
// - Priority order is documented inline so it can be reviewed and
//   adjusted independently of any UI code.
// - WeatherExperience is immutable and has no dependencies beyond
//   WeatherData — trivial to unit-test.
// - WeatherExperienceAnalyzer is a pure-function utility class
//   (all static methods, no state) so tests need no setup.
//
// WHAT THIS FILE DOES NOT DO
// --------------------------
// - Does not modify WeatherData.
// - Does not modify any screen, widget, or navigator.
// - Does not connect to any network or backend.
// - Does not affect persona selection or ranking logic.
// ============================================================

import 'weather_data.dart';

// ─────────────────────────────────────────────────────────────
// WeatherExperienceState
// ─────────────────────────────────────────────────────────────

/// A discrete, human-readable classification of current weather.
///
/// States are ordered from most severe to least severe in the
/// enum declaration — this order is NOT used for priority; see
/// [WeatherExperienceAnalyzer._evaluate] for the actual priority chain.
enum WeatherExperienceState {
  /// Severe weather: official alerts, or condition strings that
  /// indicate dangerous conditions beyond standard thunderstorms.
  severeWeather,

  /// Thunderstorm conditions detected.
  thunderstorm,

  /// Heavy rain — high probability or significant rainfall amount.
  heavyRain,

  /// Extreme heat — temperature at or above 40 °C.
  extremeHeat,

  /// Poor air quality — AQI at or above 150.
  poorAirQuality,

  /// Low visibility — visibility at or below 1 km.
  fog,

  /// Strong winds — wind speed at or above 40 km/h.
  strongWind,

  /// Moderate rain — probability is elevated or condition indicates rain.
  rain,

  /// Significant cloud cover with no precipitation or severe conditions.
  cloudy,

  /// Default calm / clear state.
  clear,
}

// ─────────────────────────────────────────────────────────────
// WeatherExperience
// ─────────────────────────────────────────────────────────────

/// Immutable result of [WeatherExperienceAnalyzer.analyze].
///
/// Contains everything a UI element needs to communicate the
/// current weather experience to the user — in plain language.
class WeatherExperience {
  /// The classified weather state.
  final WeatherExperienceState state;

  /// Short headline shown to the user, e.g. "Heavy rain".
  final String title;

  /// One-sentence description of current conditions.
  final String description;

  /// Short action advice for the user.
  final String recommendedAction;

  /// Normalised severity in the range 0.0 (calm) – 1.0 (extreme).
  /// Useful for driving visual intensity (e.g. badge colour, icon weight).
  final double severity;

  const WeatherExperience({
    required this.state,
    required this.title,
    required this.description,
    required this.recommendedAction,
    required this.severity,
  });

  @override
  String toString() =>
      'WeatherExperience(state: $state, severity: $severity, title: "$title")';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeatherExperience &&
          other.state == state &&
          other.title == title &&
          other.severity == severity;

  @override
  int get hashCode => Object.hash(state, title, severity);
}

// ─────────────────────────────────────────────────────────────
// WeatherExperienceAnalyzer
// ─────────────────────────────────────────────────────────────

/// Converts a [WeatherData] snapshot into a [WeatherExperience].
///
/// All methods are static — no instance needed.
///
/// Usage
/// -----
/// ```dart
/// final experience = WeatherExperienceAnalyzer.analyze(weatherData);
/// print(experience.title);          // "Heavy rain"
/// print(experience.recommendedAction); // "Plan travel carefully..."
/// ```
///
/// Testing
/// -------
/// Because [analyze] is a pure function of its [WeatherData] input,
/// it can be tested by constructing WeatherData with specific field
/// values and asserting the returned [WeatherExperienceState]:
///
/// ```dart
/// final data = WeatherData(temperatureC: 42, ...);
/// expect(WeatherExperienceAnalyzer.analyze(data).state,
///        WeatherExperienceState.extremeHeat);
/// ```
class WeatherExperienceAnalyzer {
  WeatherExperienceAnalyzer._(); // not instantiated

  // ── Application-level thresholds ─────────────────────────
  // These are UX triggers, not official IMD advisory values.
  // Adjust here — no other file needs to change.

  /// Rain probability (%) at or above which "rain" is flagged.
  static const double _rainProbabilityThreshold = 60.0;

  /// Rain probability (%) at or above which "heavy rain" is flagged.
  static const double _heavyRainProbabilityThreshold = 80.0;

  /// Rainfall amount (mm) that confirms heavy-rain classification
  /// when probability alone is borderline.
  static const double _heavyRainAmountMm = 10.0;

  /// Temperature (°C) at or above which extreme heat is flagged.
  static const double _extremeHeatThreshold = 40.0;

  /// AQI at or above which poor air quality is flagged.
  static const int _poorAqiThreshold = 150;

  /// Visibility (km) at or below which fog / low-vis is flagged.
  static const double _fogVisibilityThreshold = 1.0;

  /// Wind speed (km/h) at or above which strong wind is flagged.
  static const double _strongWindThreshold = 40.0;

  // ── Condition keyword sets ────────────────────────────────
  // Matched case-insensitively against weatherCondition and
  // weatherConditionDetail strings already in WeatherData.

  static const List<String> _severeKeywords = [
    'severe',
    'cyclone',
    'tornado',
    'hurricane',
    'red alert',
    'orange alert',
    'extreme',
  ];

  static const List<String> _thunderstormKeywords = [
    'thunderstorm',
    'thunder',
    'lightning',
    'squall',
  ];

  static const List<String> _heavyRainKeywords = [
    'heavy rain',
    'heavy rainfall',
    'very heavy',
    'downpour',
    'torrential',
  ];

  static const List<String> _rainKeywords = [
    'rain',
    'shower',
    'drizzle',
    'precipitation',
  ];

  static const List<String> _fogKeywords = [
    'fog',
    'mist',
    'haze',
    'smog',
  ];

  static const List<String> _cloudyKeywords = [
    'cloud',
    'overcast',
    'partly cloudy',
    'mostly cloudy',
  ];

  // ─────────────────────────────────────────────────────────
  // Public entry point
  // ─────────────────────────────────────────────────────────

  /// Analyze [weather] and return the dominant [WeatherExperience].
  ///
  /// Priority chain (highest → lowest):
  ///   1. Severe weather keywords
  ///   2. Thunderstorm keywords
  ///   3. Heavy rain (high probability OR heavy-rain keyword
  ///      OR significant rainfall amount)
  ///   4. Extreme heat (≥ 40 °C)
  ///   5. Poor air quality (AQI ≥ 150)
  ///   6. Fog / low visibility (≤ 1 km)
  ///   7. Strong wind (≥ 40 km/h)
  ///   8. Rain (moderate probability OR rain keyword)
  ///   9. Cloudy (condition keyword)
  ///  10. Clear (default)
  static WeatherExperience analyze(WeatherData weather) {
    final state = _evaluate(weather);
    return _buildExperience(state, weather);
  }

  // ─────────────────────────────────────────────────────────
  // Priority evaluation
  // ─────────────────────────────────────────────────────────

  static WeatherExperienceState _evaluate(WeatherData w) {
    final condition = w.weatherCondition.toLowerCase();
    final detail    = w.weatherConditionDetail.toLowerCase();

    // 1 ── Severe weather ──────────────────────────────────
    if (_matchesAny(condition, _severeKeywords) ||
        _matchesAny(detail,    _severeKeywords)) {
      return WeatherExperienceState.severeWeather;
    }

    // 2 ── Thunderstorm ────────────────────────────────────
    if (_matchesAny(condition, _thunderstormKeywords) ||
        _matchesAny(detail,    _thunderstormKeywords)) {
      return WeatherExperienceState.thunderstorm;
    }

    // 3 ── Heavy rain ──────────────────────────────────────
    final isHeavyRainKeyword =
        _matchesAny(condition, _heavyRainKeywords) ||
        _matchesAny(detail,    _heavyRainKeywords);
    final isHeavyRainProb =
        w.rainfallProbability >= _heavyRainProbabilityThreshold;
    final isHeavyRainAmount =
        w.rainfallAmountMm != null &&
        w.rainfallAmountMm! >= _heavyRainAmountMm;

    if (isHeavyRainKeyword || isHeavyRainProb || isHeavyRainAmount) {
      return WeatherExperienceState.heavyRain;
    }

    // 4 ── Extreme heat ────────────────────────────────────
    if (w.temperatureC >= _extremeHeatThreshold) {
      return WeatherExperienceState.extremeHeat;
    }

    // 5 ── Poor air quality ────────────────────────────────
    if (w.aqi != null && w.aqi! >= _poorAqiThreshold) {
      return WeatherExperienceState.poorAirQuality;
    }

    // 6 ── Fog / low visibility ────────────────────────────
    final isFogKeyword =
        _matchesAny(condition, _fogKeywords) ||
        _matchesAny(detail,    _fogKeywords);
    if (w.visibilityKm <= _fogVisibilityThreshold || isFogKeyword) {
      return WeatherExperienceState.fog;
    }

    // 7 ── Strong wind ─────────────────────────────────────
    if (w.windSpeedKmh >= _strongWindThreshold) {
      return WeatherExperienceState.strongWind;
    }

    // 8 ── Rain ────────────────────────────────────────────
    final isRainKeyword =
        _matchesAny(condition, _rainKeywords) ||
        _matchesAny(detail,    _rainKeywords);
    if (w.rainfallProbability >= _rainProbabilityThreshold || isRainKeyword) {
      return WeatherExperienceState.rain;
    }

    // 9 ── Cloudy ──────────────────────────────────────────
    if (_matchesAny(condition, _cloudyKeywords) ||
        _matchesAny(detail,    _cloudyKeywords)) {
      return WeatherExperienceState.cloudy;
    }

    // 10 ── Clear (default) ────────────────────────────────
    return WeatherExperienceState.clear;
  }

  // ─────────────────────────────────────────────────────────
  // Experience builder
  // ─────────────────────────────────────────────────────────

  static WeatherExperience _buildExperience(
    WeatherExperienceState state,
    WeatherData w,
  ) {
    switch (state) {
      case WeatherExperienceState.severeWeather:
        return const WeatherExperience(
          state: WeatherExperienceState.severeWeather,
          title: 'Severe weather',
          description: 'Severe weather conditions require attention.',
          recommendedAction:
              'Follow official weather warnings and stay alert.',
          severity: 1.0,
        );

      case WeatherExperienceState.thunderstorm:
        return const WeatherExperience(
          state: WeatherExperienceState.thunderstorm,
          title: 'Thunderstorm',
          description: 'Thunderstorm conditions require extra caution.',
          recommendedAction:
              'Avoid exposed outdoor areas during the storm.',
          severity: 0.9,
        );

      case WeatherExperienceState.heavyRain:
        return const WeatherExperience(
          state: WeatherExperienceState.heavyRain,
          title: 'Heavy rain',
          description:
              'Rain conditions may affect travel and outdoor plans.',
          recommendedAction:
              'Plan travel carefully and stay alert.',
          severity: 0.75,
        );

      case WeatherExperienceState.extremeHeat:
        return WeatherExperience(
          state: WeatherExperienceState.extremeHeat,
          title: 'Extreme heat',
          description:
              'Very high temperatures are affecting current conditions.',
          recommendedAction:
              'Stay hydrated and avoid prolonged heat exposure.',
          // Severity scales linearly from 0.6 at 40 °C up to 1.0 at 48 °C
          severity: (0.6 +
                  ((w.temperatureC - _extremeHeatThreshold) / 8.0) * 0.4)
              .clamp(0.6, 1.0),
        );

      case WeatherExperienceState.poorAirQuality:
        return WeatherExperience(
          state: WeatherExperienceState.poorAirQuality,
          title: 'Poor air quality',
          description: 'Air quality may affect sensitive users.',
          recommendedAction:
              'Consider reducing prolonged outdoor activity.',
          // Severity scales from 0.5 at AQI 150 up to 1.0 at AQI 300
          severity: w.aqi != null
              ? ((w.aqi! - _poorAqiThreshold) / 150.0 * 0.5 + 0.5)
                    .clamp(0.5, 1.0)
              : 0.5,
        );

      case WeatherExperienceState.fog:
        return const WeatherExperience(
          state: WeatherExperienceState.fog,
          title: 'Low visibility',
          description: 'Visibility is currently reduced.',
          recommendedAction: 'Travel carefully and allow extra time.',
          severity: 0.65,
        );

      case WeatherExperienceState.strongWind:
        return WeatherExperience(
          state: WeatherExperienceState.strongWind,
          title: 'Strong winds',
          description: 'Strong winds may affect outdoor activities.',
          recommendedAction: 'Take care in exposed areas.',
          // Severity scales from 0.5 at 40 km/h up to 1.0 at 90 km/h
          severity: ((w.windSpeedKmh - _strongWindThreshold) / 50.0 * 0.5 +
                  0.5)
              .clamp(0.5, 1.0),
        );

      case WeatherExperienceState.rain:
        return const WeatherExperience(
          state: WeatherExperienceState.rain,
          title: 'Rain',
          description: 'Rain is affecting current conditions.',
          recommendedAction: 'Keep rain protection nearby.',
          severity: 0.5,
        );

      case WeatherExperienceState.cloudy:
        return const WeatherExperience(
          state: WeatherExperienceState.cloudy,
          title: 'Cloudy conditions',
          description: 'Cloud cover is currently significant.',
          recommendedAction:
              'Outdoor conditions remain generally manageable.',
          severity: 0.2,
        );

      case WeatherExperienceState.clear:
        return const WeatherExperience(
          state: WeatherExperienceState.clear,
          title: 'Clear skies',
          description: 'Weather conditions are calm right now.',
          recommendedAction: 'A good time for outdoor activities.',
          severity: 0.0,
        );
    }
  }

  // ─────────────────────────────────────────────────────────
  // Helper
  // ─────────────────────────────────────────────────────────

  /// Returns true if [text] contains any keyword from [keywords].
  /// Both [text] and the keywords are expected to be lower-case already.
  static bool _matchesAny(String text, List<String> keywords) {
    for (final kw in keywords) {
      if (text.contains(kw)) return true;
    }
    return false;
  }
}
