// ============================================================
// models/homepage_response.dart
//
// Dart model for the FastAPI /homepage endpoint response.
//
// Mirrors the Python WeatherCard + WeatherResponse Pydantic models
// in backend/app/models/weather.py.
//
// The Flutter app uses this to obtain both the ranked card ORDER
// and the live weather values (temperature, wind, feels-like,
// pressure, etc.) from the backend.
// ============================================================

/// A single ranked weather card as returned by the backend.
class BackendWeatherCard {
  final String type; // e.g. "rain_alert", "temperature"
  final String title; // e.g. "Rain Alert"
  final String value; // e.g. "Possible showers in the evening"
  final String unit; // e.g. "°C", "%", ""
  final String severity; // "low" | "medium" | "high"
  final double score; // ranking score, higher = more relevant

  const BackendWeatherCard({
    required this.type,
    required this.title,
    required this.value,
    required this.unit,
    required this.severity,
    required this.score,
  });

  factory BackendWeatherCard.fromJson(Map<String, dynamic> json) {
    return BackendWeatherCard(
      type: json['type'] as String,
      title: json['title'] as String,
      value: json['value'] as String,
      unit: json['unit'] as String,
      severity: json['severity'] as String,
      score: (json['score'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'title': title,
    'value': value,
    'unit': unit,
    'severity': severity,
    'score': score,
  };

  @override
  String toString() =>
      'BackendWeatherCard(type: $type, score: $score, severity: $severity)';
}

/// A single weather warning entry as returned by the backend.
class BackendWeatherWarning {
  final String? warningType;
  final String? severity;
  final String? title;
  final String? description;
  final String? district;
  final String? validFrom;
  final String? validUntil;
  final String? source;

  const BackendWeatherWarning({
    this.warningType,
    this.severity,
    this.title,
    this.description,
    this.district,
    this.validFrom,
    this.validUntil,
    this.source,
  });

  factory BackendWeatherWarning.fromJson(Map<String, dynamic> json) {
    return BackendWeatherWarning(
      warningType: json['warning_type'] as String?,
      severity: json['severity'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      district: json['district'] as String?,
      validFrom: json['valid_from'] as String?,
      validUntil: json['valid_until'] as String?,
      source: json['source'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'warning_type': warningType,
    'severity': severity,
    'title': title,
    'description': description,
    'district': district,
    'valid_from': validFrom,
    'valid_until': validUntil,
    'source': source,
  };
}

/// Full response from `GET /homepage?persona=<p>&city=<c>`.
/// Cards are already sorted by the backend's ranking service.
class HomepageResponse {
  final String city;
  final double temperature;
  final double humidity;
  final double windSpeed;
  final String condition;
  final List<BackendWeatherCard> cards;

  // ── Rich fields from the backend WeatherResponse ──────────
  // These are optional — the backend may or may not populate them
  // depending on the active weather provider. When present they
  // are used to build a live WeatherData for the HomeScreen.
  final String? source;
  final String? state;
  final String? district;
  final double? latitude;
  final double? longitude;
  final double? feelsLike;
  final double? pressureHpa;
  final String? windDirection;
  final double? rainfallMm;
  final double? cloudCoverPct;
  final int? uvIndex;
  final int? aqi;
  final double? visibilityKm;
  final String? observationTime;
  final String? weatherCode;
  final List<BackendWeatherWarning> warnings;

  const HomepageResponse({
    required this.city,
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.condition,
    required this.cards,
    this.source,
    this.state,
    this.district,
    this.latitude,
    this.longitude,
    this.feelsLike,
    this.pressureHpa,
    this.windDirection,
    this.rainfallMm,
    this.cloudCoverPct,
    this.uvIndex,
    this.aqi,
    this.visibilityKm,
    this.observationTime,
    this.weatherCode,
    this.warnings = const [],
  });

  factory HomepageResponse.fromJson(Map<String, dynamic> json) {
    final rawCards = json['cards'] as List<dynamic>;
    final rawWarnings = json['warnings'] as List<dynamic>?;
    return HomepageResponse(
      city: json['city'] as String,
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      windSpeed: (json['wind_speed'] as num).toDouble(),
      condition: json['condition'] as String,
      cards: rawCards
          .map((c) => BackendWeatherCard.fromJson(c as Map<String, dynamic>))
          .toList(),
      // Rich fields — all optional, null if absent in the response
      source: json['source'] as String?,
      state: json['state'] as String?,
      district: json['district'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      feelsLike: (json['feels_like'] as num?)?.toDouble(),
      pressureHpa: (json['pressure_hpa'] as num?)?.toDouble(),
      windDirection: json['wind_direction'] as String?,
      rainfallMm: (json['rainfall_mm'] as num?)?.toDouble(),
      cloudCoverPct: (json['cloud_cover_pct'] as num?)?.toDouble(),
      uvIndex: (json['uv_index'] as num?)?.toInt(),
      aqi: json['aqi'] as int?,
      visibilityKm: (json['visibility_km'] as num?)?.toDouble(),
      observationTime: json['observation_time'] as String?,
      weatherCode: json['weather_code'] as String?,
      warnings: rawWarnings != null
          ? rawWarnings
              .map((w) => BackendWeatherWarning.fromJson(w as Map<String, dynamic>))
              .toList()
          : const [],
    );
  }

  /// Ordered list of card type strings as ranked by the backend.
  /// e.g. `["rain_alert", "humidity", "temperature", ...]`
  /// Used by HomeScreen to reorder the Flutter card catalogue.
  List<String> get rankedCardTypes =>
      cards.map((c) => c.type).toList(growable: false);

  @override
  String toString() =>
      'HomepageResponse(city: $city, condition: $condition, '
      'cards: ${cards.length}, source: $source)';
}
