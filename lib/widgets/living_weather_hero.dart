// ============================================================
// widgets/living_weather_hero.dart
//
// LivingWeatherHero — the animated weather centrepiece.
//
// The hero fills the top third of the screen with an atmospheric
// backdrop whose colour, texture, and motion reflect the current
// WeatherExperienceState.  Weather information is layered on top
// using a strong typographic hierarchy.
//
// Architecture:
//   - Receives WeatherExperience + WeatherData — does NO analysis.
//   - Three AnimationControllers: main loop, cloud drift, lightning.
//   - CustomPainter classes from weather_painter.dart do all drawing.
//   - No external assets, no packages.
// ============================================================

import 'package:flutter/material.dart';

import '../models/weather_data.dart';
import '../models/weather_experience.dart';
import 'weather_painter.dart';

class LivingWeatherHero extends StatefulWidget {
  final WeatherExperience experience;
  final WeatherData weather;

  const LivingWeatherHero({
    super.key,
    required this.experience,
    required this.weather,
  });

  @override
  State<LivingWeatherHero> createState() => _LivingWeatherHeroState();
}

class _LivingWeatherHeroState extends State<LivingWeatherHero>
    with TickerProviderStateMixin {
  // Main atmosphere loop (rain streaks, wind particles, heat wave)
  late final AnimationController _mainCtrl;
  // Cloud drift — slower
  late final AnimationController _cloudCtrl;
  // Lightning — very slow periodic
  late final AnimationController _lightningCtrl;

  @override
  void initState() {
    super.initState();

    _mainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _cloudCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _lightningCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _cloudCtrl.dispose();
    _lightningCtrl.dispose();
    super.dispose();
  }

  // ── Atmosphere palette ────────────────────────────────────
  static _AtmosPalette _palette(WeatherExperienceState state) {
    switch (state) {
      case WeatherExperienceState.clear:
        return const _AtmosPalette(
          top:    Color(0xFF1565C0),
          bottom: Color(0xFF42A5F5),
          hasCloud: false, hasRain: false, hasWind: false,
          hasFog: false,   hasHeat: false, hasLightning: false,
          cloudOpacity: 0, rainIntensity: 0,
        );
      case WeatherExperienceState.cloudy:
        return const _AtmosPalette(
          top:    Color(0xFF546E7A),
          bottom: Color(0xFF78909C),
          hasCloud: true, cloudOpacity: 0.5,
          hasRain: false, hasWind: false,
          hasFog: false,  hasHeat: false, hasLightning: false,
          rainIntensity: 0,
        );
      case WeatherExperienceState.rain:
        return const _AtmosPalette(
          top:    Color(0xFF1565C0),
          bottom: Color(0xFF0288D1),
          hasCloud: true, cloudOpacity: 0.35,
          hasRain: true,  rainIntensity: 0.4,
          hasWind: false, hasFog: false,
          hasHeat: false, hasLightning: false,
        );
      case WeatherExperienceState.heavyRain:
        return const _AtmosPalette(
          top:    Color(0xFF0D47A1),
          bottom: Color(0xFF01579B),
          hasCloud: true, cloudOpacity: 0.55,
          hasRain: true,  rainIntensity: 0.85,
          hasWind: false, hasFog: false,
          hasHeat: false, hasLightning: false,
        );
      case WeatherExperienceState.thunderstorm:
        return const _AtmosPalette(
          top:    Color(0xFF1A237E),
          bottom: Color(0xFF311B92),
          hasCloud: true, cloudOpacity: 0.6,
          hasRain: true,  rainIntensity: 0.7,
          hasWind: false, hasFog: false,
          hasHeat: false, hasLightning: true,
        );
      case WeatherExperienceState.extremeHeat:
        return const _AtmosPalette(
          top:    Color(0xFFBF360C),
          bottom: Color(0xFFFF6F00),
          hasCloud: false, cloudOpacity: 0,
          hasRain: false,  rainIntensity: 0,
          hasWind: false,  hasFog: false,
          hasHeat: true,   hasLightning: false,
        );
      case WeatherExperienceState.poorAirQuality:
        return const _AtmosPalette(
          top:    Color(0xFF4E342E),
          bottom: Color(0xFF795548),
          hasCloud: true, cloudOpacity: 0.3,
          hasRain: false, rainIntensity: 0,
          hasWind: false, hasFog: true,
          hasHeat: false, hasLightning: false,
        );
      case WeatherExperienceState.fog:
        return const _AtmosPalette(
          top:    Color(0xFF455A64),
          bottom: Color(0xFF90A4AE),
          hasCloud: false, cloudOpacity: 0,
          hasRain: false,  rainIntensity: 0,
          hasWind: false,  hasFog: true,
          hasHeat: false,  hasLightning: false,
        );
      case WeatherExperienceState.strongWind:
        return const _AtmosPalette(
          top:    Color(0xFF00695C),
          bottom: Color(0xFF26A69A),
          hasCloud: true, cloudOpacity: 0.25,
          hasRain: false, rainIntensity: 0,
          hasWind: true,  hasFog: false,
          hasHeat: false, hasLightning: false,
        );
      case WeatherExperienceState.severeWeather:
        return const _AtmosPalette(
          top:    Color(0xFF880E4F),
          bottom: Color(0xFFAD1457),
          hasCloud: true, cloudOpacity: 0.6,
          hasRain: true,  rainIntensity: 0.9,
          hasWind: true,  hasFog: false,
          hasHeat: false, hasLightning: true,
        );
    }
  }

  // ── State icon ────────────────────────────────────────────
  static IconData _stateIcon(WeatherExperienceState state) {
    switch (state) {
      case WeatherExperienceState.clear:          return Icons.wb_sunny_outlined;
      case WeatherExperienceState.cloudy:         return Icons.cloud_outlined;
      case WeatherExperienceState.rain:           return Icons.grain;
      case WeatherExperienceState.heavyRain:      return Icons.water_drop;
      case WeatherExperienceState.thunderstorm:   return Icons.bolt;
      case WeatherExperienceState.extremeHeat:    return Icons.thermostat;
      case WeatherExperienceState.poorAirQuality: return Icons.air;
      case WeatherExperienceState.fog:            return Icons.blur_on;
      case WeatherExperienceState.strongWind:     return Icons.wind_power;
      case WeatherExperienceState.severeWeather:  return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final w       = widget.weather;
    final exp     = widget.experience;
    final pal     = _palette(exp.state);
    final icon    = _stateIcon(exp.state);
    final screenW = MediaQuery.of(context).size.width;
    final heroH   = screenW * 0.72; // proportional height

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      width: double.infinity,
      height: heroH,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [pal.top, pal.bottom],
        ),
      ),
      child: ClipRect(
        child: Stack(
          children: [
            // ── Atmosphere layer 1: clouds ──────────────────
            if (pal.hasCloud)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _cloudCtrl,
                  builder: (context, child) => CustomPaint(
                    painter: CloudPainter(
                      animValue: _cloudCtrl.value,
                      opacity: pal.cloudOpacity,
                    ),
                  ),
                ),
              ),

            // ── Atmosphere layer 2: rain ─────────────────────
            if (pal.hasRain)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _mainCtrl,
                  builder: (context, child) => CustomPaint(
                    painter: RainPainter(
                      animValue: _mainCtrl.value,
                      intensity: pal.rainIntensity,
                    ),
                  ),
                ),
              ),

            // ── Atmosphere layer 3: heat waves ───────────────
            if (pal.hasHeat)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _mainCtrl,
                  builder: (context, child) => CustomPaint(
                    painter: HeatWavePainter(animValue: _mainCtrl.value),
                  ),
                ),
              ),

            // ── Atmosphere layer 4: wind particles ───────────
            if (pal.hasWind)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _mainCtrl,
                  builder: (context, child) => CustomPaint(
                    painter: WindParticlePainter(animValue: _mainCtrl.value),
                  ),
                ),
              ),

            // ── Atmosphere layer 5: fog ───────────────────────
            if (pal.hasFog)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _cloudCtrl,
                  builder: (context, child) => CustomPaint(
                    painter: FogPainter(animValue: _cloudCtrl.value),
                  ),
                ),
              ),

            // ── Atmosphere layer 6: lightning ─────────────────
            if (pal.hasLightning)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _lightningCtrl,
                  builder: (context, child) => CustomPaint(
                    painter: LightningPainter(animValue: _lightningCtrl.value),
                  ),
                ),
              ),

            // ── Bottom fade for readability of content below ──
            Positioned(
              bottom: 0, left: 0, right: 0,
              height: heroH * 0.25,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.18),
                    ],
                  ),
                ),
              ),
            ),

            // ── Weather information overlay ───────────────────
            Positioned.fill(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Condition icon + label
                      Row(
                        children: [
                          Icon(icon,
                              color: Colors.white.withValues(alpha: 0.9),
                              size: 18),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              w.weatherCondition,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),

                      // TEMPERATURE — dominant element
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${w.tempInt}°',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 78,
                              fontWeight: FontWeight.w200,
                              height: 1.0,
                              letterSpacing: -3,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 14),
                            child: Text(
                              'C',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 22,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Feels-like + condition detail
                      Text(
                        'Feels ${w.feelsLikeInt}°C  ·  ${w.weatherConditionDetail}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),

                      // Two key values — chosen by experience state
                      Row(
                        children: _keyValues(exp.state, w)
                            .map((kv) => Flexible(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 18),
                                    child: _heroKV(kv[0], kv[1]),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Two key values surfaced based on what the state makes important.
  // Uses only WeatherData fields — no invented values.
  static List<List<String>> _keyValues(
    WeatherExperienceState state,
    WeatherData w,
  ) {
    switch (state) {
      case WeatherExperienceState.rain:
      case WeatherExperienceState.heavyRain:
      case WeatherExperienceState.thunderstorm:
      case WeatherExperienceState.severeWeather:
        return [
          ['Rain', '${w.rainfallProbability.toInt()}%'],
          ['Wind', '${w.windSpeedInt} km/h'],
        ];
      case WeatherExperienceState.extremeHeat:
        return [
          ['Humidity', '${w.humidity}%'],
          if (w.uvIndex != null) ['UV', '${w.uvIndex}']
          else ['Wind', '${w.windSpeedInt} km/h'],
        ];
      case WeatherExperienceState.poorAirQuality:
        return [
          ['AQI', w.aqi != null ? '${w.aqi}' : 'N/A'],
          ['Humidity', '${w.humidity}%'],
        ];
      case WeatherExperienceState.fog:
        return [
          ['Visibility', '${w.visibilityStr} km'],
          ['Humidity', '${w.humidity}%'],
        ];
      case WeatherExperienceState.strongWind:
        return [
          ['Wind', '${w.windSpeedInt} km/h'],
          ['Visibility', '${w.visibilityStr} km'],
        ];
      case WeatherExperienceState.clear:
      case WeatherExperienceState.cloudy:
        return [
          ['Humidity', '${w.humidity}%'],
          ['Rain', '${w.rainfallProbability.toInt()}%'],
        ];
    }
  }

  Widget _heroKV(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.65),
          fontSize: 10.5,
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────
// _AtmosPalette — atmosphere configuration for each state
// ─────────────────────────────────────────────────────────────
class _AtmosPalette {
  final Color  top;
  final Color  bottom;
  final bool   hasCloud;
  final double cloudOpacity;
  final bool   hasRain;
  final double rainIntensity;
  final bool   hasWind;
  final bool   hasFog;
  final bool   hasHeat;
  final bool   hasLightning;

  const _AtmosPalette({
    required this.top,
    required this.bottom,
    required this.hasCloud,
    required this.cloudOpacity,
    required this.hasRain,
    required this.rainIntensity,
    required this.hasWind,
    required this.hasFog,
    required this.hasHeat,
    required this.hasLightning,
  });
}
