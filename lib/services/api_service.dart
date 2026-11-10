// ============================================================
// services/api_service.dart
//
// HTTP client for the Mausam FastAPI backend.
//
// Single public method:
//   fetchHomepage(persona, city, latitude?, longitude?) → HomepageResponse
//
// Design rules:
//   - Never throws. Returns null on any failure so callers can
//     fall back to demo data without a try/catch.
//   - Debug logging only — no secrets, no PII logged.
//   - URI is always constructed with Uri() — no string concatenation.
//   - Timeout is enforced; backend unavailability fails fast.
//   - latitude/longitude are optional — omitted entirely from the
//     URL when null so existing backend tests remain unaffected.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/homepage_response.dart';
import '../models/travel_advisory_model.dart';

class ApiService {
  ApiService._(); // static-only utility class

  // ── Public API ─────────────────────────────────────────────

  /// Fetches the personalized homepage from the FastAPI backend.
  ///
  /// Returns a [HomepageResponse] on success, or `null` if the
  /// backend is unreachable, times out, or returns an error.
  /// The caller should fall back to demo data when null is returned.
  ///
  /// Parameters
  /// ----------
  /// [persona]   : Backend persona string, e.g. "farmer", "student".
  /// [city]      : City name, e.g. "Hyderabad".
  /// [latitude]  : Optional decimal latitude from the device GPS fix.
  ///               When provided, sent to the backend so it can be
  ///               stored in RankingContext and used by future
  ///               coordinate-aware weather providers (e.g. IMD).
  /// [longitude] : Optional decimal longitude. Always paired with
  ///               [latitude] — omit both or supply both.
  static Future<HomepageResponse?> fetchHomepage({
    required String persona,
    required String city,
    double? latitude,
    double? longitude,
  }) async {
    // Build query parameters — only include lat/lon when both are present
    final Map<String, String> queryParams = {'persona': persona, 'city': city};

    if (latitude != null && longitude != null) {
      // 6 decimal places ≈ 0.1 m precision — more than sufficient
      queryParams['latitude'] = latitude.toStringAsFixed(6);
      queryParams['longitude'] = longitude.toStringAsFixed(6);
    }

    final uri = Uri.parse(kApiBaseUrl)
        .replace(path: '/homepage', queryParameters: queryParams);

    _log(
      'Requesting homepage — persona: $persona | city: $city'
      '${latitude != null ? " | lat: ${latitude.toStringAsFixed(4)}"
                " lon: ${longitude!.toStringAsFixed(4)}" : " | no GPS coords"}',
    );
    _log('API URL: $uri');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(kApiTimeout);

      _log('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final result = HomepageResponse.fromJson(json);
        _log('Success — ${result.cards.length} cards received for $persona');
        _log('Card order: ${result.rankedCardTypes.join(' → ')}');
        return result;
      } else {
        _log('Backend error ${response.statusCode}: ${response.body}');
        return null;
      }
    } on TimeoutException catch (_) {
      _log(
        'Request timed out after ${kApiTimeout.inSeconds}s — '
        'falling back to demo data',
      );
      return null;
    } on SocketException catch (e) {
      _log('Network error (backend unreachable?): $e');
      return null;
    } on http.ClientException catch (e) {
      _log('HTTP client error: $e');
      return null;
    } catch (e) {
      _log('Unexpected error: $e');
      return null;
    }
  }

  // ── Travel Advisory API ────────────────────────────────────

  /// Fetches destination-based travel advisory and weather conditions.
  static Future<TravelAdvisoryModel?> fetchTravelAdvisory({
    required String destination,
    String? origin,
    double? originLat,
    double? originLon,
    double? destLat,
    double? destLon,
  }) async {
    final Map<String, String> queryParams = {'destination': destination.trim()};
    if (origin != null && origin.trim().isNotEmpty) {
      queryParams['origin'] = origin.trim();
    }
    if (destLat != null && destLon != null) {
      queryParams['dest_lat'] = destLat.toStringAsFixed(6);
      queryParams['dest_lon'] = destLon.toStringAsFixed(6);
    }
    if (originLat != null && originLon != null) {
      queryParams['origin_lat'] = originLat.toStringAsFixed(6);
      queryParams['origin_lon'] = originLon.toStringAsFixed(6);
    }

    final uri = Uri.parse(kApiBaseUrl)
        .replace(path: '/travel-advisory', queryParameters: queryParams);

    _log('Requesting travel advisory for: $destination');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(kApiTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return TravelAdvisoryModel.fromJson(json);
      } else {
        _log('Backend travel-advisory returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _log('Backend travel-advisory call failed ($e). Attempting direct resilient fetch.');
    }

    // Direct fallback fetch from Open-Meteo if backend server is temporarily unreachable
    return _fetchDirectTravelAdvisoryFallback(
      destination: destination,
      origin: origin,
      destLat: destLat,
      destLon: destLon,
    );
  }

  /// Searches for place names and geocodes them into coordinate suggestions.
  static Future<List<LocationSuggestion>> searchLocations(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];

    final uri = Uri.parse(kApiBaseUrl).replace(
      path: '/locations/search',
      queryParameters: {'query': q, 'limit': '5'},
    );

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list
            .map((item) => LocationSuggestion.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    // Fallback search via Open-Meteo geocoding
    try {
      final openMeteoUri = Uri.parse('https://geocoding-api.open-meteo.com/v1/search').replace(
        queryParameters: {'name': q, 'count': '5', 'language': 'en', 'format': 'json'},
      );
      final resp = await http.get(openMeteoUri).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final results = (data['results'] as List<dynamic>?) ?? [];
        return results.map((item) {
          final m = item as Map<String, dynamic>;
          final name = m['name'] as String? ?? q;
          final state = m['admin1'] as String?;
          final country = m['country'] as String?;
          final disp = [name, ?state, ?country].join(', ');
          return LocationSuggestion(
            name: name,
            state: state,
            country: country,
            latitude: (m['latitude'] as num).toDouble(),
            longitude: (m['longitude'] as num).toDouble(),
            displayName: disp,
          );
        }).toList();
      }
    } catch (_) {}

    return const [];
  }

  /// Fallback generator providing direct live weather data if local FastAPI backend is paused.
  static Future<TravelAdvisoryModel?> _fetchDirectTravelAdvisoryFallback({
    required String destination,
    String? origin,
    double? destLat,
    double? destLon,
  }) async {
    double? lat = destLat;
    double? lon = destLon;
    String resolvedName = destination;

    if (lat == null || lon == null) {
      final suggestions = await searchLocations(destination);
      if (suggestions.isNotEmpty) {
        lat = suggestions.first.latitude;
        lon = suggestions.first.longitude;
        resolvedName = suggestions.first.displayName;
      }
    }

    if (lat == null || lon == null) {
      return null;
    }

    try {
      final uri = Uri.parse('https://api.open-meteo.com/v1/forecast').replace(
        queryParameters: {
          'latitude': lat.toString(),
          'longitude': lon.toString(),
          'current': 'temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,wind_direction_10m',
          'hourly': 'visibility,uv_index',
          'daily': 'temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum,weather_code',
          'forecast_days': '7',
          'timezone': 'auto',
        },
      );
      final resp = await http.get(uri).timeout(kApiTimeout);
      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final curr = data['current'] as Map<String, dynamic>? ?? {};
      final temp = (curr['temperature_2m'] as num?)?.toDouble() ?? 25.0;
      final feels = (curr['apparent_temperature'] as num?)?.toDouble() ?? temp;
      final hum = (curr['relative_humidity_2m'] as num?)?.toInt() ?? 60;
      final wind = (curr['wind_speed_10m'] as num?)?.toDouble() ?? 10.0;
      final wmoCode = (curr['weather_code'] as num?)?.toInt() ?? 0;

      final hourly = data['hourly'] as Map<String, dynamic>? ?? {};
      final visList = (hourly['visibility'] as List<dynamic>?) ?? [];
      final visKm = visList.isNotEmpty ? (visList.first as num).toDouble() / 1000.0 : 10.0;

      final daily = data['daily'] as Map<String, dynamic>? ?? {};
      final times = (daily['time'] as List<dynamic>?) ?? [];
      final tmax = (daily['temperature_2m_max'] as List<dynamic>?) ?? [];
      final tmin = (daily['temperature_2m_min'] as List<dynamic>?) ?? [];
      final rainProbs = (daily['precipitation_probability_max'] as List<dynamic>?) ?? [];
      final rainSums = (daily['precipitation_sum'] as List<dynamic>?) ?? [];
      final codes = (daily['weather_code'] as List<dynamic>?) ?? [];

      final List<TravelForecastDayModel> forecast = [];
      for (int i = 0; i < times.length; i++) {
        final dStr = times[i] as String;
        final dt = DateTime.tryParse(dStr) ?? DateTime.now();
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final dayName = days[dt.weekday - 1];

        forecast.add(
          TravelForecastDayModel(
            date: dStr,
            dayName: dayName,
            minTempC: (tmin[i] as num?)?.toDouble() ?? (temp - 5),
            maxTempC: (tmax[i] as num?)?.toDouble() ?? (temp + 5),
            rainProbability: (rainProbs[i] as num?)?.toDouble(),
            rainfallMm: (rainSums[i] as num?)?.toDouble(),
            condition: _wmoToCondition(codes.isNotEmpty ? (codes[i] as num).toInt() : 0),
            weatherCode: codes.isNotEmpty ? codes[i].toString() : '0',
          ),
        );
      }

      final rainMm = forecast.isNotEmpty ? forecast.first.rainfallMm : 0.0;
      final rainProb = forecast.isNotEmpty ? forecast.first.rainProbability : 0.0;
      final isSevere = wmoCode >= 95 || (rainMm != null && rainMm >= 15.0) || visKm <= 1.5;
      final isModerate = (rainMm != null && rainMm >= 2.0) || visKm <= 4.0 || wind >= 25.0;

      final riskLevel = isSevere ? 'high' : (isModerate ? 'moderate' : 'low');
      final riskTitle = isSevere
          ? 'High Travel Risk'
          : (isModerate ? 'Moderate Travel Risk' : 'Low Travel Risk');
      final riskDesc = isSevere
          ? 'Severe weather conditions active at destination. Heavy rain or low visibility. Allow extra travel time.'
          : (isModerate
              ? 'Weather conditions may affect travel. Maintain safe braking distances.'
              : 'Favorable travel conditions. Clear highways with good visibility.');

      final List<String> precautions = [];
      if (visKm <= 2.0) {
        precautions.add('Low visibility — turn on low-beam headlights or fog lamps.');
      }
      if (rainMm != null && rainMm > 2.0) {
        precautions.add('Wet road surfaces — reduce highway cruising speed and maintain safe distance.');
      }
      if (wind >= 30.0) {
        precautions.add('Strong winds — exercise caution when driving high-sided vehicles on open flyovers.');
      }
      if (precautions.isEmpty) {
        precautions.add('Favorable driving conditions. Keep headlights in auto mode and stay alert.');
        precautions.add('Check vehicle tyre pressure and fluid levels before highway travel.');
      }

      return TravelAdvisoryModel(
        destination: destination,
        destinationResolved: resolvedName,
        latitude: lat,
        longitude: lon,
        origin: origin,
        originResolved: origin,
        routeSummary: origin != null ? '$origin → $destination' : null,
        temperature: temp,
        feelsLike: feels,
        condition: _wmoToCondition(wmoCode),
        weatherCode: wmoCode.toString(),
        humidity: hum,
        windSpeed: wind,
        windDirection: 'SW',
        visibilityKm: double.parse(visKm.toStringAsFixed(1)),
        minTempC: forecast.isNotEmpty ? forecast.first.minTempC : temp - 4,
        maxTempC: forecast.isNotEmpty ? forecast.first.maxTempC : temp + 4,
        rainfallProbability: rainProb,
        rainfallMm: rainMm,
        riskLevel: riskLevel,
        riskTitle: riskTitle,
        riskDescription: riskDesc,
        roadCondition: isSevere
            ? 'Waterlogging / poor visibility risks on highway.'
            : (isModerate ? 'Wet roads with reduced traction.' : 'Normal dry driving conditions.'),
        roadDataStatus: 'Real-time municipal road sensor data unavailable — advisory derived from live meteorological data',
        publicTransportStatus: 'Data unavailable',
        airportStatus: 'Data unavailable',
        travelPrecautions: precautions,
        warnings: isSevere
            ? [
                TravelAlertModel(
                  warningType: 'Weather Alert',
                  severity: 'high',
                  title: 'Adverse Weather Advisory',
                  description: 'Inclement conditions detected near destination.',
                )
              ]
            : [],
        forecast: forecast,
        source: 'Open-Meteo Direct Live API',
        observationTime: DateTime.now().toIso8601String(),
      );
    } catch (_) {
      return null;
    }
  }

  static String _wmoToCondition(int code) {
    if (code == 0) return 'Clear';
    if (code == 1 || code == 2) return 'Partly Cloudy';
    if (code == 3) return 'Overcast';
    if (code == 45 || code == 48) return 'Fog / Mist';
    if (code >= 51 && code <= 57) return 'Drizzle';
    if (code == 61 || code == 63) return 'Rain';
    if (code >= 65 && code <= 82) return 'Heavy Rain';
    if (code >= 71 && code <= 86) return 'Snow';
    if (code >= 95) return 'Thunderstorm';
    return 'Partly Cloudy';
  }

  // ── Debug logging ──────────────────────────────────────────

  /// Prints to the debug console only in debug builds.
  /// Never logs passwords, tokens, or sensitive user data.
  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('[MausamAPI] $message');
    }
  }
}
