// ============================================================
// models/homepage_response.dart
//
// Dart model for the FastAPI /homepage endpoint response.
//
// Mirrors the Python WeatherCard + WeatherResponse Pydantic models
// in backend/app/models/weather.py.
//
// The Flutter app only uses the ranked card ORDER from this
// response — it does not replace WeatherData with backend values
// in this MVP step. That wiring comes in a later step when the
// backend is connected to a real weather source.
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

/// Full response from `GET /homepage?persona=<p>&city=<c>`.
/// Cards are already sorted by the backend's ranking service.
class HomepageResponse {
  final String city;
  final double temperature;
  final double humidity;
  final double windSpeed;
  final String condition;
  final List<BackendWeatherCard> cards;

  const HomepageResponse({
    required this.city,
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.condition,
    required this.cards,
  });

  factory HomepageResponse.fromJson(Map<String, dynamic> json) {
    final rawCards = json['cards'] as List<dynamic>;
    return HomepageResponse(
      city: json['city'] as String,
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      windSpeed: (json['wind_speed'] as num).toDouble(),
      condition: json['condition'] as String,
      cards: rawCards
          .map((c) => BackendWeatherCard.fromJson(c as Map<String, dynamic>))
          .toList(),
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
      'cards: ${cards.length})';
}
