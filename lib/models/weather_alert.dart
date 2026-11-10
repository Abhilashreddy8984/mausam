// ============================================================
// models/weather_alert.dart
//
// Structured domain model for weather alerts, official IMD warnings,
// and persona-specific actionable advisories.
//
// Core Design Principles:
// 1. Condition Specificity: Each hazard type generates precautions
//    tailored strictly to that condition (e.g. Haze -> visibility precautions,
//    never thunderstorm precautions).
// 2. Provenance: Official IMD alerts are strictly distinguished from
//    application-calculated weather risks.
// 3. No Fabrication: Validity periods, rain/wind amounts, and timestamps
//    are only displayed when provided by the verified source.
// ============================================================

import 'package:flutter/material.dart';
import 'persona.dart';

/// Severity level of an alert or advisory.
enum AlertSeverity {
  low,
  medium,
  high,
  extreme,
}

extension AlertSeverityProps on AlertSeverity {
  String get label {
    switch (this) {
      case AlertSeverity.low:
        return 'Low (Advisory)';
      case AlertSeverity.medium:
        return 'Yellow (Watch)';
      case AlertSeverity.high:
        return 'Orange (Alert)';
      case AlertSeverity.extreme:
        return 'Red (Warning)';
    }
  }

  String get badgeText {
    switch (this) {
      case AlertSeverity.low:
        return 'ADVISORY';
      case AlertSeverity.medium:
        return 'YELLOW ALERT';
      case AlertSeverity.high:
        return 'ORANGE ALERT';
      case AlertSeverity.extreme:
        return 'RED ALERT';
    }
  }

  Color get color {
    switch (this) {
      case AlertSeverity.low:
        return const Color(0xFF0284C7); // Sky / Blue
      case AlertSeverity.medium:
        return const Color(0xFFD97706); // Amber / Yellow
      case AlertSeverity.high:
        return const Color(0xFFEA580C); // Orange
      case AlertSeverity.extreme:
        return const Color(0xFFDC2626); // Red
    }
  }

  Color get backgroundColor {
    switch (this) {
      case AlertSeverity.low:
        return const Color(0xFFF0F9FF);
      case AlertSeverity.medium:
        return const Color(0xFFFFFBEB);
      case AlertSeverity.high:
        return const Color(0xFFFFF7ED);
      case AlertSeverity.extreme:
        return const Color(0xFFFEF2F2);
    }
  }

  Color get borderColor {
    switch (this) {
      case AlertSeverity.low:
        return const Color(0xFFBAE6FD);
      case AlertSeverity.medium:
        return const Color(0xFFFDE68A);
      case AlertSeverity.high:
        return const Color(0xFFFED7AA);
      case AlertSeverity.extreme:
        return const Color(0xFFFECACA);
    }
  }
}

/// The origin of the alert.
enum AlertSource {
  /// Official warning from the India Meteorological Department (IMD)
  officialImd,

  /// Weather risk calculated internally from current sensor/forecast metrics
  calculated,

  /// Normal background conditions (no active severe hazard)
  normal,
}

/// Hazard category classification.
enum WeatherHazardType {
  hazeFog,
  heavyRain,
  thunderstorm,
  strongWind,
  heatwave,
  coldWave,
  poorAqi,
  normal,
}

/// A structured weather alert or advisory item.
class WeatherAlert {
  final String title;
  final String headline;
  final String condition;
  final AlertSeverity severity;
  final AlertSource source;
  final WeatherHazardType hazardType;
  final String? validPeriod;
  final String? issuedTime;
  final String affectedLocation;
  final String windImpact;
  final String rainImpact;
  final List<String> precautions;

  const WeatherAlert({
    required this.title,
    required this.headline,
    required this.condition,
    required this.severity,
    required this.source,
    required this.hazardType,
    this.validPeriod,
    this.issuedTime,
    required this.affectedLocation,
    required this.windImpact,
    required this.rainImpact,
    required this.precautions,
  });

  bool get isOfficial => source == AlertSource.officialImd;

  bool get isActive =>
      hazardType != WeatherHazardType.normal &&
      severity != AlertSeverity.low;

  String get severityLabel {
    if (hazardType == WeatherHazardType.normal) {
      return 'Normal Conditions';
    }
    switch (severity) {
      case AlertSeverity.low:
        return 'Advisory';
      case AlertSeverity.medium:
        return 'Yellow Alert';
      case AlertSeverity.high:
        return 'Orange Alert';
      case AlertSeverity.extreme:
        return 'Red Alert';
    }
  }

  Color get severityColor => severity.color;
  Color get severityBgColor => severity.backgroundColor;
  Color get severityBorderColor => severity.borderColor;
}

/// Persona-tailored advisory recommendations.
class PersonaAdvisory {
  final Persona persona;
  final String headline;
  final String recommendation;
  final String actionableTip;
  final String fieldSuitability;
  final IconData icon;
  final Color accentColor;

  const PersonaAdvisory({
    required this.persona,
    required this.headline,
    required this.recommendation,
    required this.actionableTip,
    required this.fieldSuitability,
    required this.icon,
    required this.accentColor,
  });
}
