// ============================================================
// models/location_data.dart
//
// LocationData  — holds a resolved GPS fix.
// LocationStatus — all states the location flow can be in.
// ============================================================

// ─────────────────────────────────────────────────────────────
// LocationData — real coordinates + optional place labels
// ─────────────────────────────────────────────────────────────
class LocationData {
  /// WGS-84 latitude in decimal degrees.
  final double latitude;

  /// WGS-84 longitude in decimal degrees.
  final double longitude;

  /// Accuracy radius in metres reported by the device.
  final double? accuracyMeters;

  /// Human-readable city name.
  /// null until reverse-geocoding is implemented.
  final String? city;

  /// Human-readable state / region.
  /// null until reverse-geocoding is implemented.
  final String? state;

  /// ISO 3166-1 alpha-2 country code, e.g. "IN".
  /// null until reverse-geocoding is implemented.
  final String? country;

  const LocationData({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.city,
    this.state,
    this.country,
  });

  // ── Helpers ──────────────────────────────────────────────

  /// Short coordinate string shown in the UI, e.g. "17.3850° N, 78.4867° E".
  String get coordinateLabel {
    final latDir = latitude >= 0 ? 'N' : 'S';
    final lonDir = longitude >= 0 ? 'E' : 'W';
    final lat = latitude.abs().toStringAsFixed(4);
    final lon = longitude.abs().toStringAsFixed(4);
    return '$lat° $latDir, $lon° $lonDir';
  }

  /// Display name: city if available, otherwise raw coordinates.
  String get displayName => city ?? coordinateLabel;

  /// True when at least the coordinates are populated.
  bool get isResolved => true; // always true — object only created on success

  @override
  String toString() =>
      'LocationData(lat: $latitude, lon: $longitude, city: $city)';
}

// ─────────────────────────────────────────────────────────────
// LocationStatus — every state the location pipeline can be in
// ─────────────────────────────────────────────────────────────
enum LocationStatus {
  /// Initial state — no request has been made yet.
  idle,

  /// Actively fetching the GPS fix.
  loading,

  /// GPS fix obtained successfully.
  success,

  /// User denied the permission when asked.
  permissionDenied,

  /// User denied and checked "Don't ask again" — must go to Settings.
  permissionPermanentlyDenied,

  /// Location services (GPS switch) are turned off in device settings.
  serviceDisabled,

  /// Any other unexpected error.
  error,
}
