// ============================================================
// models/travel_advisory_model.dart
//
// Dart models for destination-based weather and travel advisories.
// Mirrors the backend TravelAdvisoryResponse model.
// ============================================================

class LocationSuggestion {
  final String name;
  final String? state;
  final String? country;
  final double latitude;
  final double longitude;
  final String displayName;

  const LocationSuggestion({
    required this.name,
    this.state,
    this.country,
    required this.latitude,
    required this.longitude,
    required this.displayName,
  });

  factory LocationSuggestion.fromJson(Map<String, dynamic> json) {
    return LocationSuggestion(
      name: json['name'] as String? ?? '',
      state: json['state'] as String?,
      country: json['country'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      displayName: json['display_name'] as String? ?? (json['name'] as String? ?? ''),
    );
  }
}

class TravelAlertModel {
  final String warningType;
  final String severity;
  final String title;
  final String description;
  final String? validFrom;
  final String? validUntil;

  const TravelAlertModel({
    required this.warningType,
    required this.severity,
    required this.title,
    required this.description,
    this.validFrom,
    this.validUntil,
  });

  factory TravelAlertModel.fromJson(Map<String, dynamic> json) {
    return TravelAlertModel(
      warningType: json['warning_type'] as String? ?? 'Advisory',
      severity: json['severity'] as String? ?? 'low',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      validFrom: json['valid_from'] as String?,
      validUntil: json['valid_until'] as String?,
    );
  }
}

class TravelForecastDayModel {
  final String date;
  final String dayName;
  final double minTempC;
  final double maxTempC;
  final double? rainProbability;
  final double? rainfallMm;
  final String condition;
  final String? weatherCode;

  const TravelForecastDayModel({
    required this.date,
    required this.dayName,
    required this.minTempC,
    required this.maxTempC,
    this.rainProbability,
    this.rainfallMm,
    required this.condition,
    this.weatherCode,
  });

  factory TravelForecastDayModel.fromJson(Map<String, dynamic> json) {
    return TravelForecastDayModel(
      date: json['date'] as String? ?? '',
      dayName: json['day_name'] as String? ?? '',
      minTempC: (json['min_temp_c'] as num?)?.toDouble() ?? 0.0,
      maxTempC: (json['max_temp_c'] as num?)?.toDouble() ?? 0.0,
      rainProbability: (json['rain_probability'] as num?)?.toDouble(),
      rainfallMm: (json['rainfall_mm'] as num?)?.toDouble(),
      condition: json['condition'] as String? ?? 'Fair',
      weatherCode: json['weather_code'] as String?,
    );
  }
}

class TravelAdvisoryModel {
  final String destination;
  final String destinationResolved;
  final double latitude;
  final double longitude;
  final String? origin;
  final String? originResolved;
  final String? routeSummary;

  final double temperature;
  final double feelsLike;
  final String condition;
  final String? weatherCode;
  final int humidity;
  final double windSpeed;
  final String windDirection;
  final double visibilityKm;

  final double? minTempC;
  final double? maxTempC;
  final double? rainfallProbability;
  final double? rainfallMm;
  final int? uvIndex;
  final int? aqi;

  final String riskLevel; // "low" | "moderate" | "high"
  final String riskTitle;
  final String riskDescription;

  final String roadCondition;
  final String roadDataStatus;
  final String publicTransportStatus;
  final String airportStatus;

  final List<String> travelPrecautions;
  final List<TravelAlertModel> warnings;
  final List<TravelForecastDayModel> forecast;

  final String source;
  final String observationTime;

  const TravelAdvisoryModel({
    required this.destination,
    required this.destinationResolved,
    required this.latitude,
    required this.longitude,
    this.origin,
    this.originResolved,
    this.routeSummary,
    required this.temperature,
    required this.feelsLike,
    required this.condition,
    this.weatherCode,
    required this.humidity,
    required this.windSpeed,
    required this.windDirection,
    required this.visibilityKm,
    this.minTempC,
    this.maxTempC,
    this.rainfallProbability,
    this.rainfallMm,
    this.uvIndex,
    this.aqi,
    required this.riskLevel,
    required this.riskTitle,
    required this.riskDescription,
    required this.roadCondition,
    required this.roadDataStatus,
    required this.publicTransportStatus,
    required this.airportStatus,
    required this.travelPrecautions,
    this.warnings = const [],
    this.forecast = const [],
    required this.source,
    required this.observationTime,
  });

  factory TravelAdvisoryModel.fromJson(Map<String, dynamic> json) {
    final rawWarnings = json['warnings'] as List<dynamic>? ?? [];
    final rawForecast = json['forecast'] as List<dynamic>? ?? [];
    final rawPrecautions = json['travel_precautions'] as List<dynamic>? ?? [];

    return TravelAdvisoryModel(
      destination: json['destination'] as String? ?? '',
      destinationResolved: json['destination_resolved'] as String? ?? (json['destination'] as String? ?? ''),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      origin: json['origin'] as String?,
      originResolved: json['origin_resolved'] as String?,
      routeSummary: json['route_summary'] as String?,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      feelsLike: (json['feels_like'] as num?)?.toDouble() ?? 0.0,
      condition: json['condition'] as String? ?? 'Clear',
      weatherCode: json['weather_code'] as String?,
      humidity: (json['humidity'] as num?)?.toInt() ?? 50,
      windSpeed: (json['wind_speed'] as num?)?.toDouble() ?? 0.0,
      windDirection: json['wind_direction'] as String? ?? '--',
      visibilityKm: (json['visibility_km'] as num?)?.toDouble() ?? 10.0,
      minTempC: (json['min_temp_c'] as num?)?.toDouble(),
      maxTempC: (json['max_temp_c'] as num?)?.toDouble(),
      rainfallProbability: (json['rainfall_probability'] as num?)?.toDouble(),
      rainfallMm: (json['rainfall_mm'] as num?)?.toDouble(),
      uvIndex: (json['uv_index'] as num?)?.toInt(),
      aqi: (json['aqi'] as num?)?.toInt(),
      riskLevel: json['risk_level'] as String? ?? 'low',
      riskTitle: json['risk_title'] as String? ?? 'Travel Advisory',
      riskDescription: json['risk_description'] as String? ?? '',
      roadCondition: json['road_condition'] as String? ?? 'Normal driving conditions',
      roadDataStatus: json['road_data_status'] as String? ?? 'Real-time municipal road sensor data unavailable — advisory derived from live meteorological data',
      publicTransportStatus: json['public_transport_status'] as String? ?? 'Data unavailable',
      airportStatus: json['airport_status'] as String? ?? 'Data unavailable',
      travelPrecautions: rawPrecautions.map((p) => p.toString()).toList(),
      warnings: rawWarnings.map((w) => TravelAlertModel.fromJson(w as Map<String, dynamic>)).toList(),
      forecast: rawForecast.map((f) => TravelForecastDayModel.fromJson(f as Map<String, dynamic>)).toList(),
      source: json['source'] as String? ?? 'IMD / Open-Meteo Live API',
      observationTime: json['observation_time'] as String? ?? DateTime.now().toIso8601String(),
    );
  }
}
