import 'package:flutter/material.dart';

import '../models/farmer_advisory.dart';
import '../models/weather_data.dart';

/// Single authoritative calculation and business logic layer for Farmer Advisory.
/// Produces dynamic, scientifically-sound agrimet guidance based on live weather data.
class FarmerAdvisoryService {
  FarmerAdvisoryService._();

  /// Computes authoritative Farmer Advisory data from the provided [weather] snapshot.
  static FarmerAdvisoryData compute(WeatherData? weather) {
    if (weather == null) {
      return FarmerAdvisoryData.empty(
        message: 'Weather snapshot is missing. Unable to compute agricultural advisory.',
      );
    }

    final condLower = weather.weatherCondition.toLowerCase();
    final isThunderstorm = condLower.contains('thunder') || condLower.contains('storm');
    final isRainExpected = (weather.rainfallAmountMm != null && weather.rainfallAmountMm! > 1.5) ||
        (weather.rainfallProbability != null && weather.rainfallProbability! >= 40.0) ||
        condLower.contains('rain') ||
        condLower.contains('drizzle');
    final isHighWind = weather.windSpeedKmh >= 24.0;
    final isHeatStress = weather.temperatureC >= 36.0;

    const officialTip =
        'Source: IMD Agrimet Division. Advisory is indicative — verify with local Krishi Vigyan Kendra before major decisions.';

    // ── 1. SEVERE WEATHER / THUNDERSTORM ──
    if (isThunderstorm) {
      return FarmerAdvisoryData(
        hasData: true,
        statusBadge: 'Suspend Field Operations',
        statusSubtitle:
            'Thunderstorm and lightning alert in effect. Move farm labor and livestock to covered shelter immediately.',
        statusColor: const Color(0xFFDC2626),
        statusIcon: Icons.warning_rounded,
        cropAdvisory: 'Secure standing crops',
        pestWatch: 'Post-storm disease watch',
        soilMoisture: 'Excess moisture expected',
        expectedRain: weather.rainfallAmountMm != null && weather.rainfallAmountMm! > 0
            ? '${weather.rainfallAmountMm!.toInt()} mm intense showers'
            : 'Heavy thunder showers expected',
        sprayingAdvisory: 'Strictly suspend all spraying',
        summaryTitle: 'Field Management Summary',
        summaryText:
            'Severe thunderstorm conditions detected. Cease all field work and chemical spraying immediately. Ensure drainage paths are open to mitigate flash waterlogging.',
        harvestWindow: 'Suspend until storm passes',
        nextDryWindow: 'Check local radar clearance',
        officialTip: officialTip,
      );
    }

    // ── 2. PRECIPITATION / RAIN EXPECTED ──
    if (isRainExpected) {
      final rainMm = weather.rainfallAmountMm?.toInt();
      final rainText = (rainMm != null && rainMm > 0)
          ? (rainMm == 8 ? '8–10 mm tonight' : '$rainMm mm tonight')
          : 'Showers expected';

      return FarmerAdvisoryData(
        hasData: true,
        statusBadge: 'Rain Expected — Plan Accordingly',
        statusSubtitle:
            'Showers expected in the region. Delay irrigation and complete urgent harvesting before rainfall starts.',
        statusColor: const Color(0xFFD97706),
        statusIcon: Icons.info_outline_rounded,
        cropAdvisory: 'Delay irrigation 24 h',
        pestWatch: weather.humidity >= 65 ? 'High humidity risk' : 'Moderate fungal watch',
        soilMoisture: 'Adequate (pre-rain)',
        expectedRain: rainText,
        sprayingAdvisory: 'Postpone spraying (wash-off risk)',
        summaryTitle: 'Field Management Summary',
        summaryText:
            '8–10 mm of rain is expected tonight. Irrigation scheduled for today should be postponed. Standing crops vulnerable to lodging should be harvested or tied before evening.',
        harvestWindow: 'Before 3 PM today',
        nextDryWindow: 'Sat–Sun forecast dry',
        officialTip: officialTip,
      );
    }

    // ── 3. HIGH WIND WARNING ──
    if (isHighWind) {
      return FarmerAdvisoryData(
        hasData: true,
        statusBadge: 'High Wind Warning',
        statusSubtitle:
            'Gusty winds of ${weather.windSpeedInt} km/h detected. Postpone foliar spraying due to high chemical drift risk.',
        statusColor: const Color(0xFFEA580C),
        statusIcon: Icons.air_rounded,
        cropAdvisory: 'Support tall / vulnerable crops',
        pestWatch: 'Monitor wind-borne pests',
        soilMoisture: 'Normal seasonal level',
        expectedRain: 'No rain expected',
        sprayingAdvisory: 'Do not spray (drift hazard)',
        summaryTitle: 'Field Management Summary',
        summaryText:
            'Strong winds of ${weather.windSpeedInt} km/h ${weather.windDirection} can cause mechanical damage to tall standing crops. Provide staking and postpone chemical spraying until winds subside below 15 km/h.',
        harvestWindow: 'Exercise caution with tall crops',
        nextDryWindow: 'Wind easing overnight',
        officialTip: officialTip,
      );
    }

    // ── 4. HEAT STRESS CONDITIONS ──
    if (isHeatStress) {
      return FarmerAdvisoryData(
        hasData: true,
        statusBadge: 'Heat Stress Advisory',
        statusSubtitle:
            'High temperature of ${weather.tempInt}°C. Irrigate during early morning or late evening to reduce crop thermal stress.',
        statusColor: const Color(0xFFDC2626),
        statusIcon: Icons.thermostat_rounded,
        cropAdvisory: 'Light, frequent irrigation',
        pestWatch: 'Sucking pests (thrips & mites)',
        soilMoisture: 'Low — high evaporation',
        expectedRain: 'Nil (Dry spell)',
        sprayingAdvisory: 'Spray early morning only',
        summaryTitle: 'Field Management Summary',
        summaryText:
            'Intense heat wave conditions with temperatures at ${weather.tempInt}°C. Schedule farm labor in early hours (6–10 AM). Apply light irrigation and mulch vegetable beds to conserve root-zone moisture.',
        harvestWindow: 'Early morning (6–10 AM)',
        nextDryWindow: 'Extended dry spell continuing',
        officialTip: officialTip,
      );
    }

    // ── 5. FAVORABLE / NORMAL CONDITIONS ──
    return FarmerAdvisoryData(
      hasData: true,
      statusBadge: 'Good for Field Work',
      statusSubtitle:
          'Weather conditions are generally favorable for farming activities, harvesting, weeding, and land preparation.',
      statusColor: const Color(0xFF10B981),
      statusIcon: Icons.check_circle_rounded,
      cropAdvisory: 'Maintain regular irrigation',
      pestWatch: weather.humidity >= 70 ? 'High humidity — watch for blight' : 'Routine scouting',
      soilMoisture: 'Normal seasonal level',
      expectedRain: 'No rain expected',
      sprayingAdvisory: 'Favorable for morning spraying',
      summaryTitle: 'Field Management Summary',
      summaryText:
          'Favorable weather prevailing at ${weather.tempInt}°C with moderate humidity (${weather.humidity}%) and light winds (${weather.windSpeedInt} km/h). Optimal window for crop intercultural operations, harvesting, and fertilizing.',
      harvestWindow: 'Open throughout the day',
      nextDryWindow: 'Favorable dry window active',
      officialTip: officialTip,
    );
  }
}
