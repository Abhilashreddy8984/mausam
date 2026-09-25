// ============================================================
// services/location_service.dart
//
// Handles GPS location + reverse geocoding.
// GPS coordinates are converted into a readable city/state/country.
// ============================================================

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../models/location_data.dart';

class LocationService {
  LocationService._(); // not instantiated

  // ── Public API ───────────────────────────────────────────

  /// Checks permissions, requests them if needed, then fetches
  /// a single GPS fix and reverse-geocodes it.
  ///
  /// Returns a [LocationResult] that is always one of:
  ///   LocationResult.success(data)
  ///   LocationResult.failure(status)
  ///
  /// This method never throws — all exceptions are caught and
  /// mapped to a [LocationStatus].
  static Future<LocationResult> fetchCurrentLocation() async {
    try {
      // 1. Check if device location services are on
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        return LocationResult.failure(
          LocationStatus.serviceDisabled,
        );
      }

      // 2. Check current permission state
      LocationPermission permission =
          await Geolocator.checkPermission();

      // 3. Request if not yet decided
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // 4. Map the final permission state
      if (permission == LocationPermission.denied) {
        return LocationResult.failure(
          LocationStatus.permissionDenied,
        );
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult.failure(
          LocationStatus.permissionPermanentlyDenied,
        );
      }

      // 5. Fetch a single GPS position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      // 6. Reverse-geocode GPS coordinates
      String? city;
      String? state;
      String? country;

      try {
        final geocoding = Geocoding();
        final placemarks = await geocoding.placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;

          city = _firstNonEmpty([
            place.locality,
            place.subAdministrativeArea,
          ]);

          state = _firstNonEmpty([
            place.administrativeArea,
          ]);

          country = _firstNonEmpty([
            place.country,
          ]);
        }
      } catch (_) {
        // Reverse geocoding failure should NOT make GPS fail.
        // We can still use latitude/longitude.
      }

      // 7. Create our application's location data
      final data = LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        city: city,
        state: state,
        country: country,
      );

      return LocationResult.success(data);
    } on LocationServiceDisabledException {
      return LocationResult.failure(
        LocationStatus.serviceDisabled,
      );
    } catch (_) {
      return LocationResult.failure(
        LocationStatus.error,
      );
    }
  }

  /// Returns the first non-empty string from the supplied values.
  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return null;
  }

  /// Opens the device location settings screen.
  static Future<void> openLocationSettings() =>
      Geolocator.openLocationSettings();

  /// Opens the app's permission settings screen.
  static Future<void> openAppSettings() =>
      Geolocator.openAppSettings();
}

// ─────────────────────────────────────────────────────────────
// LocationResult
// ─────────────────────────────────────────────────────────────

class LocationResult {
  final LocationData? data;
  final LocationStatus status;

  const LocationResult._({
    required this.status,
    this.data,
  });

  factory LocationResult.success(LocationData data) =>
      LocationResult._(
        status: LocationStatus.success,
        data: data,
      );

  factory LocationResult.failure(LocationStatus status) =>
      LocationResult._(
        status: status,
      );

  bool get isSuccess => status == LocationStatus.success;
}