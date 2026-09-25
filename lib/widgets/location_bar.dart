// ============================================================
// widgets/location_bar.dart
//
// Compact pill/strip shown just below the MAUSAM header on the
// Home screen. Displays the detected GPS coordinates and handles
// all location states with appropriate feedback.
//
// States rendered:
//   idle     → "Detect my location" tap target
//   loading  → spinner + "Detecting location…"
//   success  → GPS icon + coordinate string + accuracy
//   denied   → warning icon + message + retry/settings button
//   disabled → warning icon + message + open-settings button
//   error    → warning icon + message + retry button
// ============================================================

import 'package:flutter/material.dart';
import '../models/location_data.dart';
import '../state/location_notifier.dart';

class LocationBar extends StatelessWidget {
  final LocationNotifier locationNotifier;

  const LocationBar({super.key, required this.locationNotifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LocationState>(
      valueListenable: locationNotifier,
      builder: (context, state, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _buildForState(context, state),
        );
      },
    );
  }

  Widget _buildForState(BuildContext context, LocationState state) {
    switch (state.status) {
      case LocationStatus.idle:
        return _IdleBar(
          key: const ValueKey('idle'),
          onTap: locationNotifier.requestLocation,
        );

      case LocationStatus.loading:
        return const _LoadingBar(key: ValueKey('loading'));

      case LocationStatus.success:
        return _SuccessBar(
          key: const ValueKey('success'),
          data: state.data!,
          onRefresh: locationNotifier.requestLocation,
        );

      case LocationStatus.permissionDenied:
      case LocationStatus.error:
        return _ActionBar(
          key: ValueKey(state.status),
          message: state.errorMessage ?? 'Tap to retry',
          actionLabel: 'Retry',
          icon: Icons.location_off_outlined,
          isWarning: true,
          onAction: locationNotifier.requestLocation,
        );

      case LocationStatus.permissionPermanentlyDenied:
      case LocationStatus.serviceDisabled:
        return _ActionBar(
          key: ValueKey(state.status),
          message: state.errorMessage ?? 'Tap to open settings',
          actionLabel: 'Settings',
          icon: Icons.location_disabled_outlined,
          isWarning: true,
          onAction: locationNotifier.openSettings,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────
// _IdleBar — invite the user to detect location
// ─────────────────────────────────────────────────────────────
class _IdleBar extends StatelessWidget {
  final VoidCallback onTap;
  const _IdleBar({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: primary.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.my_location, size: 13, color: primary),
            const SizedBox(width: 5),
            Text(
              'Detect my location',
              style: TextStyle(
                fontSize: 12,
                color: primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _LoadingBar — spinner while GPS fix is in progress
// ─────────────────────────────────────────────────────────────
class _LoadingBar extends StatelessWidget {
  const _LoadingBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 11,
            height: 11,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Detecting location…',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SuccessBar — shows coordinates + accuracy
// ─────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────
// _SuccessBar — shows detected place + GPS coordinates
// ─────────────────────────────────────────────────────────────
class _SuccessBar extends StatelessWidget {
  final LocationData data;
  final VoidCallback onRefresh;

  const _SuccessBar({
    super.key,
    required this.data,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF388E3C);

    final accuracy = data.accuracyMeters != null
        ? ' · ±${data.accuracyMeters!.toStringAsFixed(0)} m'
        : '';

    // Build a readable location name from reverse geocoding.
    final placeParts = [
      data.city,
      data.state,
      data.country,
    ].where((value) => value != null && value.trim().isNotEmpty).map(
          (value) => value!.trim(),
        );

    final placeName = placeParts.join(', ');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),

          Flexible(
            child: Text(
              placeName.isNotEmpty
                  ? '$placeName · ${data.coordinateLabel}$accuracy'
                  : '${data.coordinateLabel}$accuracy',
              style: TextStyle(
                fontSize: 11.5,
                color: color,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(width: 5),

          GestureDetector(
            onTap: onRefresh,
            child: Icon(
              Icons.refresh,
              size: 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _ActionBar — error / denied / disabled states
// ─────────────────────────────────────────────────────────────
class _ActionBar extends StatelessWidget {
  final String message;
  final String actionLabel;
  final IconData icon;
  final bool isWarning;
  final VoidCallback onAction;

  const _ActionBar({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.icon,
    required this.isWarning,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFE64A19);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 11.5,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
