// ============================================================
// services/api_service.dart
//
// HTTP client for the Mausam FastAPI backend.
//
// Single public method:
//   fetchHomepage(persona, city) → HomepageResponse
//
// Design rules:
//   - Never throws. Returns null on any failure so callers can
//     fall back to demo data without a try/catch.
//   - Debug logging only — no secrets, no PII logged.
//   - URI is always constructed with Uri() — no string concatenation.
//   - Timeout is enforced; backend unavailability fails fast.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/homepage_response.dart';

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
  /// [persona] : Backend persona string, e.g. "farmer", "student".
  /// [city]    : City name, e.g. "Hyderabad".
  static Future<HomepageResponse?> fetchHomepage({
    required String persona,
    required String city,
  }) async {
    final uri = Uri.parse(kApiBaseUrl).replace(
      path: '/homepage',
      queryParameters: {'persona': persona, 'city': city},
    );

    _log('Requesting homepage — persona: $persona | city: $city');
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
    } on SocketException catch (e) {
      _log('Network error (backend unreachable?): $e');
      return null;
    } on http.ClientException catch (e) {
      _log('HTTP client error: $e');
      return null;
    } on TimeoutException catch (_) {
      _log(
        'Request timed out after ${kApiTimeout.inSeconds}s — '
        'falling back to demo data',
      );
      return null;
    } catch (e) {
      _log('Unexpected error: $e');
      return null;
    }
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
