import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../models/persona.dart';
import '../models/weather_data.dart';
import '../theme/mausam_theme.dart';
import '../widgets/farmer_advisory_content.dart';
import '../widgets/marine_advisory_content.dart';
import '../widgets/scenic_weather_hero.dart';
import '../widgets/travel_advisory_content.dart';

/// WeatherDetailScreen — primary detail routing container.
/// Dynamically renders dedicated views for each advisory type:
/// - Yellow Alert ([WeatherCardType.weatherAlert])
/// - Marine Advisory ([WeatherCardType.marineTide])
/// - Farmer Advisory ([WeatherCardType.farmAdvisory])
/// - Travel Advisory ([WeatherCardType.travelAdvisory])
/// - General Weather Metrics (when [card] is null or a standard metric card)
class WeatherDetailScreen extends StatelessWidget {
  final WeatherCardData? card;
  final WeatherData weather;

  const WeatherDetailScreen({
    super.key,
    this.card,
    required this.weather,
  });

  @override
  Widget build(BuildContext context) {
    if (card != null) {
      switch (card!.type) {
        case WeatherCardType.weatherAlert:
          return _buildYellowAlertView(context);
        case WeatherCardType.marineTide:
          return _buildMarineAdvisoryView(context);
        case WeatherCardType.farmAdvisory:
          return _buildFarmAdvisoryView(context);
        case WeatherCardType.travelAdvisory:
          return _buildTravelAdvisoryView(context);
        default:
          break;
      }
    }

    return _buildGeneralDetailView(context);
  }

  // ─────────────────────────────────────────────────────────────
  // 1. YELLOW / WEATHER ALERT VIEW
  // ─────────────────────────────────────────────────────────────
  Widget _buildYellowAlertView(BuildContext context) {
    final alert = weather.primaryAlert;
    final locationName = alert.affectedLocation;
    final validityText = alert.validPeriod ??
        (weather.timestamp != null
            ? 'Observed at ${weather.timestamp!.hour.toString().padLeft(2, '0')}:${weather.timestamp!.minute.toString().padLeft(2, '0')} IST'
            : 'Current Conditions');

    return Scaffold(
      backgroundColor: MausamTheme.background,
      appBar: AppBar(
        title: Text(alert.isOfficial ? 'Official Weather Alert' : 'Weather Advisory'),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning Hero Banner
            Container(
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(MausamTheme.radiusCard),
                boxShadow: MausamTheme.cardShadow,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: alert.isActive
                      ? [
                          alert.severityColor,
                          alert.severityColor.withValues(alpha: 0.85),
                        ]
                      : const [
                          Color(0xFF0D9488),
                          Color(0xFF0F766E),
                        ],
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(MausamTheme.radiusCard),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          alert.isActive ? Icons.warning_amber_rounded : Icons.shield_outlined,
                          size: 42,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                alert.isOfficial ? 'OFFICIAL IMD ALERT' : 'WEATHER ADVISORY',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              alert.severityLabel,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              alert.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Affected: $locationName',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Severity Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: alert.severityBgColor,
                borderRadius: BorderRadius.circular(MausamTheme.radiusCard),
                border: Border.all(color: alert.severityBorderColor),
                boxShadow: MausamTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: alert.severityColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.shield_outlined, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Severity: ${alert.severity.label}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: alert.severityColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: alert.severityBorderColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          alert.isActive ? 'ACTIVE' : 'NORMAL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: alert.severityColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: alert.severityBorderColor),
                  const SizedBox(height: 12),
                  _buildDetailRow('Condition', alert.condition, Icons.info_outline),
                  const SizedBox(height: 8),
                  _buildDetailRow('Validity Period', validityText, Icons.access_time),
                  const SizedBox(height: 8),
                  _buildDetailRow('Affected Location', locationName, Icons.location_on_outlined),
                  const SizedBox(height: 8),
                  _buildDetailRow('Wind & Rain Impact', '${alert.windImpact} · ${alert.rainImpact}', Icons.air),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Safety Precautions (Strictly condition-specific!)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: MausamTheme.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.health_and_safety_rounded, color: alert.severityColor, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Appropriate Safety Precautions',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: MausamTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...alert.precautions.map(_buildPrecautionItem),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Official Source Note vs Application-generated Note
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(MausamTheme.radiusCard),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(
                    alert.isOfficial ? Icons.verified_outlined : Icons.info_outline_rounded,
                    color: const Color(0xFF64748B),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      alert.isOfficial
                          ? 'Source: India Meteorological Department (IMD) Official Bulletin. Yellow Alert indicates "Be Updated" — monitor official bulletins.'
                          : 'Source: Mausam Weather Engine (calculated from live weather observations: Wind ${alert.windImpact}, Rain ${alert.rainImpact}, Visibility ${weather.visibilityStr} km). This is an application-generated safety advisory, not an official IMD alert.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF475569),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. MARINE ADVISORY VIEW
  // ─────────────────────────────────────────────────────────────
  Widget _buildMarineAdvisoryView(BuildContext context) {
    return Scaffold(
      backgroundColor: MausamTheme.background,
      appBar: AppBar(
        title: const Text('Marine Advisory'),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: MarineAdvisoryContent(weather: weather),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 3. FARMER ADVISORY VIEW
  // ─────────────────────────────────────────────────────────────
  Widget _buildFarmAdvisoryView(BuildContext context) {
    return Scaffold(
      backgroundColor: MausamTheme.background,
      appBar: AppBar(
        title: const Text('Farmer Advisory'),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: FarmerAdvisoryContent(weather: weather),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 4. TRAVEL ADVISORY VIEW
  // ─────────────────────────────────────────────────────────────
  Widget _buildTravelAdvisoryView(BuildContext context) {
    return Scaffold(
      backgroundColor: MausamTheme.background,
      appBar: AppBar(
        title: const Text('Travel Advisory'),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: TravelAdvisoryContent(
          currentWeather: weather,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 5. GENERAL WEATHER DETAIL VIEW
  // ─────────────────────────────────────────────────────────────
  Widget _buildGeneralDetailView(BuildContext context) {
    final visualState = resolveWeatherVisualState(
      condition: weather.weatherCondition,
      weatherCode: weather.weatherCode,
      codeSystem: weather.weatherCodeSystem,
      tempC: weather.temperatureC,
      rainProb: weather.rainfallProbability,
      rainMm: weather.rainfallAmountMm,
      visibilityKm: weather.visibilityKm,
    );

    final aqi = weather.aqi != null ? '${weather.aqi}' : '--';
    final aqiCat = weather.aqiCategory ?? (weather.aqi != null ? 'Good' : 'N/A');
    final uv = weather.uvIndex != null ? '${weather.uvIndex}' : '--';
    final uvCat = weather.uvCategory ?? (weather.uvIndex != null ? 'Moderate' : 'N/A');

    final metrics = [
      {
        'title': 'Humidity',
        'value': '${weather.humidity}%',
        'icon': Icons.water_drop_outlined,
        'color': const Color(0xFF3B82F6),
      },
      {
        'title': 'Wind Speed',
        'value': '${weather.windSpeedInt} km/h',
        'icon': Icons.air_rounded,
        'color': const Color(0xFF0EA5E9),
      },
      {
        'title': 'Wind Direction',
        'value': weather.windDirection.isNotEmpty ? weather.windDirection : 'NE',
        'icon': Icons.explore_outlined,
        'color': const Color(0xFF6366F1),
      },
      {
        'title': 'Visibility',
        'value': '${weather.visibilityStr} km',
        'icon': Icons.remove_red_eye_outlined,
        'color': const Color(0xFF0D9488),
      },
      {
        'title': 'Rainfall',
        'value': '${weather.rainfallAmountMm?.toInt() ?? 0} mm',
        'icon': Icons.grain_rounded,
        'color': const Color(0xFF2563EB),
      },
      {
        'title': 'UV Index',
        'value': weather.uvIndex != null ? '$uv ($uvCat)' : '--',
        'icon': Icons.wb_sunny_outlined,
        'color': const Color(0xFFF59E0B),
      },
      {
        'title': 'AQI',
        'value': weather.aqi != null ? '$aqi ($aqiCat)' : '--',
        'icon': Icons.eco_outlined,
        'color': const Color(0xFF10B981),
      },
      {
        'title': 'Pressure',
        'value': '1008 hPa',
        'icon': Icons.speed_rounded,
        'color': const Color(0xFF8B5CF6),
      },
    ];

    final bannerImage = weatherImageAsset(visualState);

    return Scaffold(
      backgroundColor: MausamTheme.background,
      appBar: AppBar(
        title: Text(card?.title ?? 'Weather Details'),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // Atmospheric Banner
            Container(
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(MausamTheme.radiusCard),
                boxShadow: MausamTheme.cardShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(MausamTheme.radiusCard),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      bannerImage,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF38BDF8), Color(0xFFBAE6FD), Color(0xFFE0F2FE)],
                          ),
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.15),
                            Colors.black.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Icon(visualState.icon, size: 48, color: Colors.white),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${weather.tempInt}°C',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.1,
                                    shadows: [Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1))],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  weather.weatherCondition,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    shadows: [Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1))],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Feels like ${weather.feelsLikeInt}°C',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.9)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 2-column x 4-row Metric Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.85,
              ),
              itemCount: metrics.length,
              itemBuilder: (context, idx) {
                final m = metrics[idx];
                final color = m['color'] as Color;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: MausamTheme.cardDecoration(),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(m['icon'] as IconData, color: color, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              m['title'] as String,
                              style: const TextStyle(
                                fontSize: 11,
                                color: MausamTheme.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              m['value'] as String,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: MausamTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Helper Widgets
  // ─────────────────────────────────────────────────────────────
  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: MausamTheme.primaryBlue),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, color: MausamTheme.textSecondary),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MausamTheme.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildPrecautionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF0D9488)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Standalone Yellow Alert Screen for direct named navigation.
class YellowAlertDetailScreen extends StatelessWidget {
  final WeatherData weather;
  final WeatherCardData? card;

  const YellowAlertDetailScreen({super.key, required this.weather, this.card});

  @override
  Widget build(BuildContext context) {
    return WeatherDetailScreen(
      weather: weather,
      card: card ?? const WeatherCardData(
        type: WeatherCardType.weatherAlert,
        title: 'Weather Alert',
        value: '⚠ Yellow Alert',
        subtitle: 'Thunderstorm warning · Avoid open areas 3–8 PM',
        icon: Icons.warning_amber_rounded,
        accentColor: Color(0xFFF57F17),
        isAlert: true,
      ),
    );
  }
}

/// Standalone Marine Advisory Screen for direct named navigation.
class MarineAdvisoryDetailScreen extends StatelessWidget {
  final WeatherData weather;
  final WeatherCardData? card;

  const MarineAdvisoryDetailScreen({super.key, required this.weather, this.card});

  @override
  Widget build(BuildContext context) {
    return WeatherDetailScreen(
      weather: weather,
      card: card ?? const WeatherCardData(
        type: WeatherCardType.marineTide,
        title: 'Marine / Tide',
        value: 'Moderate sea',
        subtitle: 'High tide 12:38 · Waves 1.2 m · Fishing advisory',
        icon: Icons.waves,
        accentColor: Color(0xFF00695C),
      ),
    );
  }
}

/// Standalone Farmer Advisory Screen for direct named navigation.
class FarmerAdvisoryDetailScreen extends StatelessWidget {
  final WeatherData weather;
  final WeatherCardData? card;

  const FarmerAdvisoryDetailScreen({super.key, required this.weather, this.card});

  @override
  Widget build(BuildContext context) {
    return WeatherDetailScreen(
      weather: weather,
      card: card ?? const WeatherCardData(
        type: WeatherCardType.farmAdvisory,
        title: 'Farm Advisory',
        value: 'Hold irrigation',
        subtitle: '8–10 mm rain tonight · Harvest before evening',
        icon: Icons.grass,
        accentColor: Color(0xFF388E3C),
      ),
    );
  }
}

/// Standalone Travel Advisory Screen for direct named navigation.
class TravelAdvisoryDetailScreen extends StatelessWidget {
  final WeatherData weather;
  final WeatherCardData? card;

  const TravelAdvisoryDetailScreen({super.key, required this.weather, this.card});

  @override
  Widget build(BuildContext context) {
    return WeatherDetailScreen(
      weather: weather,
      card: card ?? const WeatherCardData(
        type: WeatherCardType.travelAdvisory,
        title: 'Travel Advisory',
        value: 'Moderate disruption',
        subtitle: 'Fog on NH-44 · Waterlogging at Mehdipatnam',
        icon: Icons.directions_car,
        accentColor: Color(0xFF5E35B1),
      ),
    );
  }
}
