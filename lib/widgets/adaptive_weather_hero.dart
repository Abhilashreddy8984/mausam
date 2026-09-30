// ============================================================
// widgets/adaptive_weather_hero.dart
//
// AdaptiveWeatherHero — the main weather hero card on HomeScreen.
//
// WHAT THIS WIDGET DOES
// ---------------------
// Renders the weather hero panel that sits between the app
// header + location bar and the persona strip.  It visually
// adapts its colour palette based on the active
// WeatherExperienceState so users immediately sense the current
// weather character on opening the app.
//
// The widget:
//   • Contains all the existing temperature / metrics content
//     that was in HomeScreen._buildCurrentWeatherHero().
//   • Adds an experience banner (title, description, action).
//   • Uses AnimatedContainer for smooth colour transitions when
//     the state changes (e.g. when live data updates).
//   • Uses NO external image assets and NO new packages.
//
// WHAT THIS WIDGET DOES NOT DO
// ----------------------------
// • Does not call WeatherExperienceAnalyzer — analysis is done
//   by HomeScreen and the result is passed in.
// • Does not hold any business logic.
// • Does not navigate anywhere.
// • Does not change WeatherData or persona state.
// ============================================================

import 'package:flutter/material.dart';

import '../models/persona.dart';
import '../models/weather_data.dart';
import '../models/weather_experience.dart';

class AdaptiveWeatherHero extends StatelessWidget {
  final WeatherExperience experience;
  final WeatherData weather;
  final Persona persona;

  const AdaptiveWeatherHero({
    super.key,
    required this.experience,
    required this.weather,
    required this.persona,
  });

  // ── Atmosphere palette lookup ─────────────────────────────
  // Returns [gradientStart, gradientEnd] for each experience state.
  // Colours are deliberately subdued so the UI feels native rather
  // than garish — they tint the existing primary-blue gradient rather
  // than replacing it entirely.
  static List<Color> _gradientFor(WeatherExperienceState state) {
    switch (state) {
      case WeatherExperienceState.clear:
        return [const Color(0xFF1565C0), const Color(0xFF1E88E5)];
      case WeatherExperienceState.cloudy:
        return [const Color(0xFF546E7A), const Color(0xFF78909C)];
      case WeatherExperienceState.rain:
        return [const Color(0xFF1976D2), const Color(0xFF0288D1)];
      case WeatherExperienceState.heavyRain:
        return [const Color(0xFF0D47A1), const Color(0xFF01579B)];
      case WeatherExperienceState.thunderstorm:
        return [const Color(0xFF1A237E), const Color(0xFF311B92)];
      case WeatherExperienceState.extremeHeat:
        return [const Color(0xFFBF360C), const Color(0xFFE64A19)];
      case WeatherExperienceState.poorAirQuality:
        return [const Color(0xFF4E342E), const Color(0xFF6D4C41)];
      case WeatherExperienceState.fog:
        return [const Color(0xFF455A64), const Color(0xFF607D8B)];
      case WeatherExperienceState.strongWind:
        return [const Color(0xFF00695C), const Color(0xFF00838F)];
      case WeatherExperienceState.severeWeather:
        return [const Color(0xFF880E4F), const Color(0xFFAD1457)];
    }
  }

  // ── State icon ────────────────────────────────────────────
  static IconData _iconFor(WeatherExperienceState state) {
    switch (state) {
      case WeatherExperienceState.clear:
        return Icons.wb_sunny_outlined;
      case WeatherExperienceState.cloudy:
        return Icons.cloud_outlined;
      case WeatherExperienceState.rain:
        return Icons.grain;
      case WeatherExperienceState.heavyRain:
        return Icons.water;
      case WeatherExperienceState.thunderstorm:
        return Icons.bolt_outlined;
      case WeatherExperienceState.extremeHeat:
        return Icons.thermostat;
      case WeatherExperienceState.poorAirQuality:
        return Icons.air;
      case WeatherExperienceState.fog:
        return Icons.blur_on;
      case WeatherExperienceState.strongWind:
        return Icons.wind_power;
      case WeatherExperienceState.severeWeather:
        return Icons.warning_amber_rounded;
    }
  }

  // ── Severity indicator colour ─────────────────────────────
  // Shown as a small dot/bar next to the experience title.
  static Color _severityColor(double severity) {
    if (severity >= 0.85) return const Color(0xFFEF5350); // red
    if (severity >= 0.60) return const Color(0xFFFF9800); // orange
    if (severity >= 0.35) return const Color(0xFFFFEB3B); // yellow
    return Colors.white.withValues(alpha: 0.6);            // subtle white
  }

  @override
  Widget build(BuildContext context) {
    final colors = _gradientFor(experience.state);
    final w = weather;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors[0].withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: Condition label (unchanged content) ────────
            Row(
              children: [
                Icon(
                  Icons.wb_cloudy_outlined,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  w.weatherCondition,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Row 2: Temperature + sunrise/sunset ───────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${w.tempInt}°',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 72,
                    fontWeight: FontWeight.w300,
                    height: 1.0,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'C',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (w.sunrise != null)
                      _miniStat(Icons.wb_twilight, w.sunrise!, 'Sunrise'),
                    if (w.sunrise != null && w.sunset != null)
                      const SizedBox(height: 8),
                    if (w.sunset != null)
                      _miniStat(
                          Icons.nights_stay_outlined, w.sunset!, 'Sunset'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),

            // ── Row 3: Condition detail ───────────────────────────
            Text(
              w.weatherConditionDetail,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 16),

            // ── Row 4: Key metrics strip (unchanged) ─────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _heroMetric(
                    Icons.thermostat_outlined,
                    'Feels like',
                    '${w.feelsLikeInt}°C',
                  ),
                  _vDivider(),
                  _heroMetric(
                    Icons.water_drop_outlined,
                    'Humidity',
                    '${w.humidity}%',
                  ),
                  _vDivider(),
                  _heroMetric(
                    Icons.wind_power,
                    'Wind',
                    '${w.windSpeedInt} km/h',
                  ),
                  _vDivider(),
                  _heroMetric(
                    Icons.visibility_outlined,
                    'Visibility',
                    '${w.visibilityStr} km',
                  ),
                ],
              ),
            ),

            // ── Row 5: Experience banner (new) ───────────────────
            // Only shown when the state is not "clear" (clear is the
            // baseline — no banner needed for calm weather).
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOut,
              child: experience.state != WeatherExperienceState.clear
                  ? _buildExperienceBanner()
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Experience banner ─────────────────────────────────────
  Widget _buildExperienceBanner() {
    final stateIcon   = _iconFor(experience.state);
    final sevColor    = _severityColor(experience.severity);
    final severityPct = (experience.severity * 100).toInt();

    return Container(
      key: ValueKey(experience.state), // key drives AnimatedSwitcher
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row: icon + title + severity pill
          Row(
            children: [
              Icon(stateIcon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  experience.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // Severity indicator pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: sevColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: sevColor.withValues(alpha: 0.6),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: sevColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$severityPct%',
                      style: TextStyle(
                        color: sevColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Description
          Text(
            experience.description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.80),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),

          // Recommended action — slightly highlighted
          Container(
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 13,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    experience.recommendedAction,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.90),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared mini-helpers (mirrors HomeScreen originals) ────
  Widget _miniStat(IconData icon, String value, String label) => Row(
    children: [
      Icon(icon, color: Colors.white60, size: 13),
      const SizedBox(width: 4),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ],
  );

  Widget _heroMetric(IconData icon, String label, String value) => Column(
    children: [
      Icon(icon, color: Colors.white70, size: 16),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      Text(
        label,
        style: const TextStyle(color: Colors.white60, fontSize: 10),
      ),
    ],
  );

  Widget _vDivider() => Container(
    height: 28,
    width: 1,
    color: Colors.white.withValues(alpha: 0.25),
  );
}
