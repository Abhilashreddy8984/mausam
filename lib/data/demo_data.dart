// ============================================================
// data/demo_data.dart
//
// WeatherCardData — the display model for a single summary card.
// WeatherCardType — enum key linking cards to persona priorities
//                   and detail screens.
//
// buildWeatherCardCatalogue(WeatherData) — builds the 11 cards
// from a WeatherData snapshot. Previously read DemoWeather
// static constants directly; now accepts WeatherData so any
// provider (demo or real API) produces the same card set.
//
// DemoWeather — KEPT as a thin compatibility shim.
// It is no longer imported by any screen. Its only remaining
// purpose is to avoid breaking any future references during
// the transition period. It will be removed once
// demo_weather_provider.dart is the sole demo source.
// ============================================================

import 'package:flutter/material.dart';

import '../models/marine_advisory_model.dart';
import '../models/persona.dart';
import '../models/weather_data.dart';
import '../services/advisory_service.dart';
import '../services/marine_advisory_service.dart';

// ─────────────────────────────────────────────────────────────
// WeatherCardData — display model for one summary card
// ─────────────────────────────────────────────────────────────
class WeatherCardData {
  final WeatherCardType type;
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color accentColor;
  final bool isAlert;

  const WeatherCardData({
    required this.type,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.accentColor,
    this.isAlert = false,
  });
}

// ─────────────────────────────────────────────────────────────
// buildWeatherCardCatalogue
//
// Builds all 11 weather cards from a WeatherData snapshot.
// The catalogue order here is irrelevant — persona ranking
// reorders cards at display time via Persona.cardPriority.
//
// To add new cards: add a WeatherCardType value in
// models/persona.dart, add a WeatherCardData entry here,
// and add it to every persona's cardPriority list.
// ─────────────────────────────────────────────────────────────
List<WeatherCardData> buildWeatherCardCatalogue(WeatherData weather) {
  // Derived display strings built from the structured model.
  // When a real API is connected, these strings update automatically
  // because they are derived from WeatherData fields.
  final rainChance = weather.rainfallProbability != null
      ? '${weather.rainfallProbability!.toInt()}% chance'
      : (weather.rainfallAmountMm != null ? '${weather.rainfallAmountMm!.toStringAsFixed(1)} mm' : '--');
  final rainSubtitle =
      weather.rainfallAmountMm != null && weather.rainfallWindow != null
      ? '~${weather.rainfallAmountMm!.toInt()} mm expected'
            ' · ${weather.rainfallWindow}'
      : null;

  final tempValue = '${weather.tempInt} °C';
  final tempSubtitle =
      'Feels like ${weather.feelsLikeInt} °C'
      ' · High ${(weather.temperatureC + 2).toInt()}'
      ' / Low ${(weather.temperatureC - 6).toInt()}';

  final aqiValue = weather.aqi != null
      ? '${weather.aqi} · ${weather.aqiCategory ?? ''}'
      : 'N/A';
  final aqiSubtitle = weather.aqi != null
      ? 'PM2.5 elevated · Sensitive groups avoid outdoors'
      : null;

  final uvValue = weather.uvIndex != null
      ? '${weather.uvIndex} · ${weather.uvCategory ?? ''}'
      : 'N/A';
  final uvSubtitle = weather.uvIndex != null
      ? 'Peak 11 AM – 2 PM · SPF 30+ recommended'
      : null;

  final windValue = '${weather.windSpeedInt} km/h ${weather.windDirection}';
  final windSubtitle =
      'Gusts up to ${(weather.windSpeedKmh * 2).toInt()}'
      ' km/h expected in evening';

  final visValue = '${weather.visibilityStr} km';

  final humidityValue = '${weather.humidity}%';

  return [
    WeatherCardData(
      type: WeatherCardType.rain,
      title: 'Rainfall',
      value: rainChance,
      subtitle: rainSubtitle,
      icon: Icons.water_drop,
      accentColor: const Color(0xFF1976D2),
    ),
    WeatherCardData(
      type: WeatherCardType.temperature,
      title: 'Temperature',
      value: tempValue,
      subtitle: tempSubtitle,
      icon: Icons.thermostat,
      accentColor: const Color(0xFFE64A19),
    ),
    WeatherCardData(
      type: WeatherCardType.aqi,
      title: 'Air Quality (AQI)',
      value: aqiValue,
      subtitle: aqiSubtitle,
      icon: Icons.air,
      accentColor: const Color(0xFFF9A825),
    ),
    WeatherCardData(
      type: WeatherCardType.uvIndex,
      title: 'UV Index',
      value: uvValue,
      subtitle: uvSubtitle,
      icon: Icons.wb_sunny,
      accentColor: const Color(0xFFFF6F00),
    ),
    WeatherCardData(
      type: WeatherCardType.wind,
      title: 'Wind',
      value: windValue,
      subtitle: windSubtitle,
      icon: Icons.wind_power,
      accentColor: const Color(0xFF00838F),
    ),
    () {
      final alert = weather.primaryAlert;
      final bool isAlertActive = alert.isActive;

      final cardTitle = alert.isOfficial ? 'IMD Alert' : 'Weather Alert';
      final cardValue = isAlertActive
          ? '⚠ ${alert.severityLabel}'
          : 'Normal Conditions';
      final cardSubtitle = isAlertActive
          ? '${alert.title} · ${alert.precautions.isNotEmpty ? alert.precautions.first : "Stay updated"}'
          : 'No severe weather alerts active';

      return WeatherCardData(
        type: WeatherCardType.weatherAlert,
        title: cardTitle,
        value: cardValue,
        subtitle: cardSubtitle,
        icon: isAlertActive
            ? (alert.severity == AlertSeverity.high || alert.severity == AlertSeverity.extreme
                ? Icons.warning_rounded
                : Icons.warning_amber_rounded)
            : Icons.shield_outlined,
        accentColor: alert.severityColor,
        isAlert: isAlertActive,
      );
    }(),
    () {
      final farmAdv = AdvisoryService.getPersonaAdvisory(
        Persona.farmer,
        weather,
        weather.primaryAlert,
      );
      return WeatherCardData(
        type: WeatherCardType.farmAdvisory,
        title: 'Farm Advisory',
        value: farmAdv.headline,
        subtitle: farmAdv.recommendation,
        icon: farmAdv.icon,
        accentColor: farmAdv.accentColor,
      );
    }(),
    () {
      final travelAdv = AdvisoryService.getPersonaAdvisory(
        Persona.traveller,
        weather,
        weather.primaryAlert,
      );
      return WeatherCardData(
        type: WeatherCardType.travelAdvisory,
        title: 'Travel Advisory',
        value: travelAdv.headline,
        subtitle: travelAdv.recommendation,
        icon: travelAdv.icon,
        accentColor: travelAdv.accentColor,
      );
    }(),
    WeatherCardData(
      type: WeatherCardType.visibility,
      title: 'Visibility',
      value: visValue,
      subtitle: 'Good conditions · May reduce after 4 PM',
      icon: Icons.visibility,
      accentColor: const Color(0xFF0288D1),
    ),
    () {
      final nearest = MarineAdvisoryService.resolveNearestStation(
        city: weather.city,
      );

      final isHighWind = weather.windSpeedKmh >= 40.0;
      final isModerateWind = weather.windSpeedKmh >= 25.0;
      final seaDesc = isHighWind
          ? 'Rough sea'
          : (isModerateWind ? 'Moderate sea' : 'Normal sea');

      final String cardValue;
      final String cardSubtitle;

      if (nearest.isUserInland) {
        cardValue = 'Inland Location';
        cardSubtitle =
            'Nearest Coast: ${nearest.station.name} (${nearest.station.basin.shortLabel}) · ${nearest.distanceKm.toInt()} km away';
      } else {
        cardValue = '${nearest.station.name} (${nearest.station.basin.shortLabel})';
        cardSubtitle =
            '${nearest.station.coastalZone} · Winds ${weather.windSpeedInt} km/h · $seaDesc';
      }

      return WeatherCardData(
        type: WeatherCardType.marineTide,
        title: 'Marine / Coastal',
        value: cardValue,
        subtitle: cardSubtitle,
        icon: Icons.waves,
        accentColor: isHighWind ? const Color(0xFFDC2626) : const Color(0xFF00695C),
      );
    }(),
    WeatherCardData(
      type: WeatherCardType.humidity,
      title: 'Humidity',
      value: humidityValue,
      subtitle: 'Humid · Dew point 24 °C',
      icon: Icons.water_drop_outlined,
      accentColor: const Color(0xFF1565C0),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────
// DemoWeather — legacy shim, no longer used by any screen.
// Retained temporarily to avoid breaking unused references.
// Remove once the full migration is verified stable.
// ─────────────────────────────────────────────────────────────
@Deprecated(
  'Use DemoWeatherProvider.getWeather() and WeatherData instead. '
  'DemoWeather will be removed in the next cleanup pass.',
)
class DemoWeather {
  static const String city = 'Hyderabad';
  static const String state = 'Telangana, India';
  static const double temperatureC = 32.0;
  static const double feelsLikeC = 35.0;
  static const String condition = 'Partly Cloudy';
  static const String conditionDetail =
      'Scattered clouds with chance of evening showers';
  static const int humidity = 68;
  static const double windSpeedKmh = 14.0;
  static const String windDirection = 'SW';
  static const double visibilityKm = 8.5;
  static const int aqiValue = 112;
  static const String aqiCategory = 'Moderate';
  static const int uvIndex = 7;
  static const String uvCategory = 'High';
  static const double rainChancePercent = 55.0;
  static const double expectedRainfallMm = 8.0;
  static const String rainWindow = '4 PM – 7 PM';
  static const bool hasAlert = true;
  static const String alertTitle = 'Yellow Alert';
  static const String alertBody =
      'Thunderstorm warning for Hyderabad district. '
      'Residents advised to avoid open areas between 3–8 PM.';
  static const String farmAdvisory =
      'Hold off irrigation — 8–10 mm rain expected tonight. '
      'Harvest standing crops before evening if possible.';
  static const String travelAdvisory =
      'Reduced visibility on NH-44 near Jadcherla due to fog patches. '
      'Waterlogging reported at Mehdipatnam underpass.';
  static const String marineTide =
      'Low tide at 06:14 · High tide at 12:38 · '
      'Sea state: Moderate (1.2 m waves). Fishing advisory in effect.';
  static const String sunrise = '6:08 AM';
  static const String sunset = '6:24 PM';
}
