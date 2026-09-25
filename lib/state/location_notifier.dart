// ============================================================
// state/location_notifier.dart
//
// LocationState       — immutable snapshot of location UI state.
// LocationNotifier    — ValueNotifier<LocationState> that drives
//                       the location UI via ValueListenableBuilder.
//
// Usage:
//   Trigger a fetch : notifier.requestLocation()
//   Read state      : notifier.value.status / .data / .errorMessage
// ============================================================

import 'package:flutter/foundation.dart';
import '../models/location_data.dart';
import '../services/location_service.dart';

// ─────────────────────────────────────────────────────────────
// LocationState — immutable; one instance per UI state change
// ─────────────────────────────────────────────────────────────
class LocationState {
  final LocationStatus status;
  final LocationData? data;
  final String? errorMessage;

  const LocationState({
    required this.status,
    this.data,
    this.errorMessage,
  });

  // Initial state — nothing requested yet.
  static const idle = LocationState(status: LocationStatus.idle);
}

// ─────────────────────────────────────────────────────────────
// LocationNotifier
// ─────────────────────────────────────────────────────────────
class LocationNotifier extends ValueNotifier<LocationState> {
  LocationNotifier() : super(LocationState.idle);

  /// Triggers a single GPS fetch. Safe to call multiple times —
  /// ignored while a fetch is already in progress.
  Future<void> requestLocation() async {
    if (value.status == LocationStatus.loading) return; // already fetching

    // Show loading state immediately
    value = const LocationState(status: LocationStatus.loading);

    final result = await LocationService.fetchCurrentLocation();

    if (result.isSuccess) {
      value = LocationState(
        status: LocationStatus.success,
        data: result.data,
      );
    } else {
      value = LocationState(
        status: result.status,
        errorMessage: _messageFor(result.status),
      );
    }
  }

  /// Opens the appropriate settings screen based on current status.
  Future<void> openSettings() async {
    if (value.status == LocationStatus.permissionPermanentlyDenied) {
      await LocationService.openAppSettings();
    } else if (value.status == LocationStatus.serviceDisabled) {
      await LocationService.openLocationSettings();
    }
  }

  // ── Helpers ──────────────────────────────────────────────
  static String _messageFor(LocationStatus status) {
    switch (status) {
      case LocationStatus.permissionDenied:
        return 'Location permission denied. Tap to try again.';
      case LocationStatus.permissionPermanentlyDenied:
        return 'Permission permanently denied. Open Settings to enable.';
      case LocationStatus.serviceDisabled:
        return 'Location services are off. Tap to open Settings.';
      case LocationStatus.error:
        return 'Could not determine location. Tap to retry.';
      default:
        return 'Unknown error.';
    }
  }
}
