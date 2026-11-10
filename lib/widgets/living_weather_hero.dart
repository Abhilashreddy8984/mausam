import 'package:flutter/material.dart';

import '../models/weather_data.dart';
import '../models/weather_experience.dart';
import '../theme/mausam_theme.dart';
import 'scenic_weather_hero.dart';

/// LivingWeatherHero — the central immersive atmospheric hero card.
/// Matches the reference design with dynamic scenic artwork, typography,
/// and live metrics bar.
class LivingWeatherHero extends StatefulWidget {
  final WeatherExperience experience;
  final WeatherData weather;
  final VoidCallback? onTap;

  const LivingWeatherHero({
    super.key,
    required this.experience,
    required this.weather,
    this.onTap,
  });

  @override
  State<LivingWeatherHero> createState() => _LivingWeatherHeroState();
}

class _LivingWeatherHeroState extends State<LivingWeatherHero>
    with SingleTickerProviderStateMixin {
  // Mapping of visual states to background asset paths
  static const Map<WeatherVisualState, String> _assetMap = {
    WeatherVisualState.sunny: 'assets/images/sunny.png',
    WeatherVisualState.partlyCloudy: 'assets/images/partly_cloudy.png',
    WeatherVisualState.cloudy: 'assets/images/foggy.png', // using foggy as placeholder for cloudy
    WeatherVisualState.drizzle: 'assets/images/foggy.png',
    WeatherVisualState.rain: 'assets/images/rainy.png',
    WeatherVisualState.heavyRain: 'assets/images/rainy.png',
    WeatherVisualState.thunderstorm: 'assets/images/thunderstorm.png',
    WeatherVisualState.fog: 'assets/images/foggy.png',
    WeatherVisualState.snow: 'assets/images/snowy.png',
    WeatherVisualState.extremeHeat: 'assets/images/sunny.png',
    WeatherVisualState.unknown: 'assets/images/foggy.png',
  };

  String _assetForState(WeatherVisualState state) {
    return _assetMap[state] ?? weatherImageAsset(state);


  }

  // ── Rest of the class remains unchanged ──
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weather = widget.weather;

    // Resolve the visual state accurately from live data
    final visualState = resolveWeatherVisualState(
      condition: weather.weatherCondition,
      weatherCode: weather.weatherCode,
      codeSystem: weather.weatherCodeSystem,
      tempC: weather.temperatureC,
      rainProb: weather.rainfallProbability,
      rainMm: weather.rainfallAmountMm,
      visibilityKm: weather.visibilityKm,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MausamTheme.radiusHero),
        boxShadow: MausamTheme.cardShadow,
        border: Border.all(color: MausamTheme.border, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MausamTheme.radiusHero),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: null,
            child: SizedBox(
              height: 228,
              child: Stack(
                children: [
// ── Background image based on visual state ──
                  Positioned.fill(
                    child: Image.asset(
                      _assetForState(visualState),
                      fit: BoxFit.cover,
                    ),
                  ),

                  // ── Soft ambient gradient for text contrast ──
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.black.withValues(alpha: 0.12),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.35),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Hero Content Overlay ──
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Giant Temperature
                        Text(
                          '${weather.tempInt}°',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.05,
                            letterSpacing: -1,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Condition Label
                        Text(
                          weather.weatherCondition.isNotEmpty
                              ? weather.weatherCondition
                              : visualState.displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.2,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 6,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),

                        // Feels Like Text
                        Text(
                          'Feels like ${weather.feelsLikeInt}°',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.95),
                            shadows: const [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // ── Bottom Metric Sub-Bar ──
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildSubMetric(
                                  icon: Icons.water_drop_outlined,
                                  label: 'Humidity',
                                  value: '${weather.humidity}%',
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 16,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                              Expanded(
                                child: _buildSubMetric(
                                  icon: Icons.air,
                                  label: 'Wind',
                                  value: '${weather.windSpeedInt} km/h',
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 16,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                              Expanded(
                                child: _buildSubMetric(
                                  icon: Icons.grain,
                                  label: 'Rain',
                                  value:
                                      '${weather.rainfallAmountMm?.toInt() ?? 0} mm',
                                ),
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
        ),
      ),
    );
  }

  Widget _buildSubMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 13),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            '$label $value',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
