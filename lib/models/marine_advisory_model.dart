// ============================================================
// models/marine_advisory_model.dart
//
// Structured domain model for Indian Coastal & Marine Advisories.
//
// Core Design Rules:
// 1. Geographic Relevance: Distinguishes Arabian Sea (West Coast)
//    from Bay of Bengal (East Coast) and Inland locations.
// 2. Truthful Inland Handling: Does not present coastal conditions
//    as local to inland users (e.g. Hyderabad, Delhi).
// 3. No Fabricated Data: When tide timings or sea surface temperature
//    sensors are unavailable, clearly marks them as unavailable.
// ============================================================

import 'package:flutter/material.dart';

/// Maritime ocean basins surrounding India.
enum MarineBasin {
  arabianSea,
  bayOfBengal,
  andamanSea,
  indianOcean,
}

extension MarineBasinProps on MarineBasin {
  String get label {
    switch (this) {
      case MarineBasin.arabianSea:
        return 'Arabian Sea (West Coast)';
      case MarineBasin.bayOfBengal:
        return 'Bay of Bengal (East Coast)';
      case MarineBasin.andamanSea:
        return 'Andaman Sea (Island Territory)';
      case MarineBasin.indianOcean:
        return 'Indian Ocean (Tri-Sea Confluence / Gulf of Mannar)';
    }
  }

  String get shortLabel {
    switch (this) {
      case MarineBasin.arabianSea:
        return 'Arabian Sea';
      case MarineBasin.bayOfBengal:
        return 'Bay of Bengal';
      case MarineBasin.andamanSea:
        return 'Andaman Sea';
      case MarineBasin.indianOcean:
        return 'Indian Ocean';
    }
  }

  Color get color {
    switch (this) {
      case MarineBasin.arabianSea:
        return const Color(0xFF0F766E); // Teal
      case MarineBasin.bayOfBengal:
        return const Color(0xFF0369A1); // Ocean Blue
      case MarineBasin.andamanSea:
        return const Color(0xFF0891B2); // Cyan / Island Blue
      case MarineBasin.indianOcean:
        return const Color(0xFF4338CA); // Deep Indigo
    }
  }
}

/// A verified Indian coastal station or major port.
class CoastalStation {
  final String id;
  final String name;
  final String coastalZone;
  final MarineBasin basin;
  final String state;
  final double latitude;
  final double longitude;
  final bool isMajorPort;
  final bool hasTideTelemetry;

  const CoastalStation({
    required this.id,
    required this.name,
    required this.coastalZone,
    required this.basin,
    required this.state,
    required this.latitude,
    required this.longitude,
    this.isMajorPort = false,
    this.hasTideTelemetry = false,
  });

  String get fullDisplayName => '$name ($coastalZone)';
}

/// A single tide schedule entry.
class TideEntry {
  final String type; // 'High Tide' or 'Low Tide'
  final String time; // e.g. '12:38 IST'
  final double? heightMeters;

  const TideEntry({
    required this.type,
    required this.time,
    this.heightMeters,
  });

  String get formattedHeight =>
      heightMeters != null ? '${heightMeters!.toStringAsFixed(1)} m' : '--';
}

/// Severity classification of coastal & marine sea risks.
enum MarineRiskLevel {
  normal,   // Waves < 1.0 m, Wind < 25 km/h
  caution,  // Waves 1.0–2.0 m, Wind 25–40 km/h (Small crafts exercise caution)
  warning,  // Waves 2.0–3.5 m, Wind 40–55 km/h (Squally weather / Fishing ban)
  severe,   // Waves > 3.5 m, Wind > 55 km/h (Gale / Cyclone Warning)
}

extension MarineRiskLevelProps on MarineRiskLevel {
  String get label {
    switch (this) {
      case MarineRiskLevel.normal:
        return 'Normal Sea State';
      case MarineRiskLevel.caution:
        return 'Coastal Sea Caution';
      case MarineRiskLevel.warning:
        return 'Rough Sea Warning';
      case MarineRiskLevel.severe:
        return 'Gale / Cyclone Alert';
    }
  }

  Color get color {
    switch (this) {
      case MarineRiskLevel.normal:
        return const Color(0xFF059669); // Green
      case MarineRiskLevel.caution:
        return const Color(0xFFD97706); // Amber
      case MarineRiskLevel.warning:
        return const Color(0xFFEA580C); // Orange
      case MarineRiskLevel.severe:
        return const Color(0xFFDC2626); // Red
    }
  }

  Color get bgColor {
    switch (this) {
      case MarineRiskLevel.normal:
        return const Color(0xFFECFDF5);
      case MarineRiskLevel.caution:
        return const Color(0xFFFFFBEB);
      case MarineRiskLevel.warning:
        return const Color(0xFFFFF7ED);
      case MarineRiskLevel.severe:
        return const Color(0xFFFEF2F2);
    }
  }
}

/// Full Marine Advisory domain data.
class MarineAdvisoryData {
  final CoastalStation station;
  final bool isUserInland;
  final double? distanceKmToUser;
  final String userLocationName;
  final double windSpeedKmh;
  final String windDirection;
  final double? waveHeightMeters;
  final bool isWaveHeightEstimated;
  final String seaConditions;
  final bool isSeaConditionsEstimated;
  final double? seaSurfaceTempC;
  final String? sstSource;
  final List<TideEntry> tides;
  final bool hasLiveTideData;
  final MarineRiskLevel riskLevel;
  final String? marineWarning;
  final List<String> precautions;
  final String sourceCitation;
  final DateTime? observationTime;

  const MarineAdvisoryData({
    required this.station,
    required this.isUserInland,
    this.distanceKmToUser,
    required this.userLocationName,
    required this.windSpeedKmh,
    required this.windDirection,
    this.waveHeightMeters,
    this.isWaveHeightEstimated = true,
    required this.seaConditions,
    this.isSeaConditionsEstimated = true,
    this.seaSurfaceTempC,
    this.sstSource,
    this.tides = const [],
    this.hasLiveTideData = false,
    required this.riskLevel,
    this.marineWarning,
    required this.precautions,
    required this.sourceCitation,
    this.observationTime,
  });

  /// Compatibility getter for legacy callers.
  bool get hasVerifiedTides => hasLiveTideData;

  String get waveHeightDisplay => waveHeightMeters != null
      ? (isWaveHeightEstimated
          ? '${waveHeightMeters!.toStringAsFixed(1)} m (Estimated)'
          : '${waveHeightMeters!.toStringAsFixed(1)} m')
      : 'Data unavailable';

  String get sstDisplay =>
      seaSurfaceTempC != null ? '${seaSurfaceTempC!.toStringAsFixed(1)} °C' : 'Data unavailable';

  String get windDisplay => windSpeedKmh > 0
      ? '${windSpeedKmh.toInt()} km/h $windDirection'.trim()
      : 'Calm winds';
}
