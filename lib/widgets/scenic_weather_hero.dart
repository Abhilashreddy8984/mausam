import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/weather_code_system.dart';
export '../models/weather_code_system.dart';

/// Distinct visual states required for the dynamic Weather Hero.
enum WeatherVisualState {
  sunny,
  partlyCloudy,
  cloudy,
  drizzle,
  rain,
  heavyRain,
  thunderstorm,
  fog,
  snow,
  extremeHeat,
  unknown,
}

/// Standard asset mapping for weather visual states.
const Map<WeatherVisualState, String> kWeatherAssetMap = {
  WeatherVisualState.sunny: 'assets/images/sunny.png',
  WeatherVisualState.partlyCloudy: 'assets/images/partly_cloudy.png',
  WeatherVisualState.cloudy: 'assets/images/foggy.png',
  WeatherVisualState.drizzle: 'assets/images/foggy.png',
  WeatherVisualState.rain: 'assets/images/rainy.png',
  WeatherVisualState.heavyRain: 'assets/images/rainy.png',
  WeatherVisualState.thunderstorm: 'assets/images/thunderstorm.png',
  WeatherVisualState.fog: 'assets/images/foggy.png',
  WeatherVisualState.snow: 'assets/images/snowy.png',
  WeatherVisualState.extremeHeat: 'assets/images/sunny.png',
  WeatherVisualState.unknown: 'assets/images/foggy.png',
};

/// Returns the asset path for a given [WeatherVisualState].
String weatherImageAsset(WeatherVisualState state) {
  return kWeatherAssetMap[state] ?? 'assets/images/foggy.png';
}

/// Resolves a condition string or weather parameters to its weather image asset.
String weatherImageAssetFor({
  required String condition,
  String? weatherCode,
  WeatherCodeSystem? codeSystem,
  double? tempC,
  double? rainProb,
  double? rainMm,
  double? visibilityKm,
}) {
  final state = resolveWeatherVisualState(
    condition: condition,
    weatherCode: weatherCode,
    codeSystem: codeSystem,
    tempC: tempC,
    rainProb: rainProb,
    rainMm: rainMm,
    visibilityKm: visibilityKm,
  );
  return weatherImageAsset(state);
}

extension WeatherVisualStateInfo on WeatherVisualState {
  String get displayName {
    switch (this) {
      case WeatherVisualState.sunny:
        return 'Sunny';
      case WeatherVisualState.partlyCloudy:
        return 'Partly Cloudy';
      case WeatherVisualState.cloudy:
        return 'Cloudy';
      case WeatherVisualState.drizzle:
        return 'Drizzle';
      case WeatherVisualState.rain:
        return 'Rain';
      case WeatherVisualState.heavyRain:
        return 'Heavy Rain';
      case WeatherVisualState.thunderstorm:
        return 'Thunderstorm';
      case WeatherVisualState.fog:
        return 'Fog / Mist';
      case WeatherVisualState.snow:
        return 'Snow';
      case WeatherVisualState.extremeHeat:
        return 'Extreme Heat';
      case WeatherVisualState.unknown:
        return 'Weather Update';
    }
  }

  IconData get icon {
    switch (this) {
      case WeatherVisualState.sunny:
        return Icons.wb_sunny_rounded;
      case WeatherVisualState.partlyCloudy:
        return Icons.wb_cloudy_rounded;
      case WeatherVisualState.cloudy:
        return Icons.cloud_rounded;
      case WeatherVisualState.drizzle:
        return Icons.grain_rounded;
      case WeatherVisualState.rain:
        return Icons.water_drop_rounded;
      case WeatherVisualState.heavyRain:
        return Icons.thunderstorm_rounded;
      case WeatherVisualState.thunderstorm:
        return Icons.bolt_rounded;
      case WeatherVisualState.fog:
        return Icons.blur_on_rounded;
      case WeatherVisualState.snow:
        return Icons.ac_unit_rounded;
      case WeatherVisualState.extremeHeat:
        return Icons.thermostat_rounded;
      case WeatherVisualState.unknown:
        return Icons.cloud_queue_rounded;
    }
  }
}

/// Resolves an integer weather code to a visual state based on the code system.
WeatherVisualState? _resolveWeatherCode(int code, WeatherCodeSystem? system) {
  if (system == WeatherCodeSystem.imd) {
    switch (code) {
      case 1:
        return WeatherVisualState.sunny;
      case 2:
        return WeatherVisualState.partlyCloudy;
      case 3:
        return WeatherVisualState.cloudy;
      case 4:
      case 17:
      case 29:
      case 95:
      case 99:
        return WeatherVisualState.thunderstorm;
      case 5: // Haze
      case 6: // Dust
      case 10: // Mist
      case 28: // Fog
      case 41:
      case 45:
        return WeatherVisualState.fog;
      case 7: // Snow
      case 22:
        return WeatherVisualState.snow;
      case 8: // Light rain
      case 20: // Drizzle
        return WeatherVisualState.drizzle;
      case 9: // Heavy rain
      case 64:
      case 65:
      case 81:
        return WeatherVisualState.heavyRain;
      case 21:
      case 25:
      case 80:
        return WeatherVisualState.rain;
      default:
        if (code >= 50 && code <= 55) return WeatherVisualState.drizzle;
        if (code >= 60 && code <= 63) return WeatherVisualState.rain;
        return null;
    }
  }

  if (system == WeatherCodeSystem.wmo) {
    switch (code) {
      case 0:
      case 1:
        return WeatherVisualState.sunny;
      case 2:
        return WeatherVisualState.partlyCloudy;
      case 3:
        return WeatherVisualState.cloudy;
      case 45:
      case 48:
        return WeatherVisualState.fog;
      case 65:
      case 81:
      case 82:
        return WeatherVisualState.heavyRain;
      case 61:
      case 63:
      case 66:
      case 67:
      case 80:
        return WeatherVisualState.rain;
      case 95:
      case 96:
      case 99:
        return WeatherVisualState.thunderstorm;
      default:
        if (code >= 51 && code <= 57) return WeatherVisualState.drizzle;
        if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
          return WeatherVisualState.snow;
        }
        return null;
    }
  }

  // When system is unspecified, infer according to unambiguous code definitions:
  // 1. Single-digit IMD codes (4..9)
  if (code == 4) return WeatherVisualState.thunderstorm;
  if (code == 5 || code == 6) return WeatherVisualState.fog;
  if (code == 7) return WeatherVisualState.snow;
  if (code == 8) return WeatherVisualState.drizzle;
  if (code == 9) return WeatherVisualState.heavyRain;

  // 2. WMO specific code 0
  if (code == 0) return WeatherVisualState.sunny;

  // 3. Shared codes (1: Sunny, 2: Partly Cloudy, 3: Overcast/Cloudy)
  if (code == 1) return WeatherVisualState.sunny;
  if (code == 2) return WeatherVisualState.partlyCloudy;
  if (code == 3) return WeatherVisualState.cloudy;

  // 4. Two-digit IMD & WMO codes
  if (code == 17 || code == 29 || code == 95 || code == 96 || code == 99) {
    return WeatherVisualState.thunderstorm;
  }
  if (code == 22 || (code >= 71 && code <= 77) || code == 85 || code == 86) {
    return WeatherVisualState.snow;
  }
  if (code == 64 || code == 65 || code == 81 || code == 82) {
    return WeatherVisualState.heavyRain;
  }
  if (code == 20 || (code >= 50 && code <= 57)) {
    return WeatherVisualState.drizzle;
  }
  if (code == 21 ||
      code == 25 ||
      (code >= 60 && code <= 63) ||
      code == 66 ||
      code == 67 ||
      code == 80) {
    return WeatherVisualState.rain;
  }
  if (code == 10 || code == 28 || code == 41 || code == 45 || code == 48) {
    return WeatherVisualState.fog;
  }

  return null;
}

/// Resolves the current weather to one of the 11 distinct visual states.
/// Accurately honors explicit condition descriptions, IMD/WMO codes, and measurements.
WeatherVisualState resolveWeatherVisualState({
  required String condition,
  String? weatherCode,
  WeatherCodeSystem? codeSystem,
  double? tempC,
  double? rainProb,
  double? rainMm,
  double? visibilityKm,
}) {
  final condClean = condition.trim().toLowerCase();

  // 1. Explicit textual condition keyword matching (highest priority over temperature & fallbacks)
  if (condClean.contains('thunder') ||
      condClean.contains('lightning') ||
      condClean.contains('squall')) {
    return WeatherVisualState.thunderstorm;
  }
  if (condClean.contains('snow') ||
      condClean.contains('blizzard') ||
      condClean.contains('flurry') ||
      condClean.contains('sleet') ||
      condClean.contains('hail')) {
    return WeatherVisualState.snow;
  }
  if (condClean.contains('heavy rain') ||
      condClean.contains('torrential') ||
      condClean.contains('downpour') ||
      condClean.contains('very heavy') ||
      condClean.contains('extreme rain')) {
    return WeatherVisualState.heavyRain;
  }
  if (condClean.contains('drizzle') ||
      condClean.contains('sprinkle') ||
      condClean.contains('light rain')) {
    return WeatherVisualState.drizzle;
  }
  if (condClean.contains('rain') || condClean.contains('shower')) {
    return WeatherVisualState.rain;
  }
  if (condClean.contains('fog') || condClean.contains('mist')) {
    return WeatherVisualState.fog;
  }
  if (condClean.contains('haze') ||
      condClean.contains('dust') ||
      condClean.contains('sand') ||
      condClean.contains('smoke') ||
      condClean.contains('smog')) {
    return WeatherVisualState.fog;
  }
  if (condClean.contains('partly cloudy') ||
      condClean.contains('few clouds') ||
      condClean.contains('scattered clouds') ||
      condClean.contains('partly sunny')) {
    return WeatherVisualState.partlyCloudy;
  }
  if (condClean.contains('cloud') || condClean.contains('overcast')) {
    return WeatherVisualState.cloudy;
  }
  if (condClean.contains('heat') || condClean.contains('hot')) {
    return WeatherVisualState.extremeHeat;
  }
  if (condClean.contains('clear') ||
      condClean.contains('sunny') ||
      condClean.contains('fine')) {
    return WeatherVisualState.sunny;
  }

  // 2. Weather Code mapping (IMD / WMO)
  if (weatherCode != null && weatherCode.isNotEmpty) {
    final codeInt = int.tryParse(weatherCode.trim());
    if (codeInt != null) {
      final codeState = _resolveWeatherCode(codeInt, codeSystem);
      if (codeState != null) {
        return codeState;
      }
    }
  }

  // 3. Physical measurement fallbacks (when condition is not explicitly identified)
  if (visibilityKm != null && visibilityKm <= 1.5) {
    return WeatherVisualState.fog;
  }

  final bool hasZeroRainfall = rainMm != null && rainMm <= 0.0;

  if (!hasZeroRainfall) {
    // Heavy rain measurement threshold (>= 10 mm rainfall)
    if (rainMm != null && rainMm >= 10.0) {
      return WeatherVisualState.heavyRain;
    }
    // High probability supported by substantial rainfall
    if (rainProb != null && rainProb >= 80.0 && rainMm != null && rainMm >= 5.0) {
      return WeatherVisualState.heavyRain;
    }
    // Drizzle inference: positive rainfall no greater than 10 mm AND non-zero rain probability
    if (rainMm != null &&
        rainMm > 0.0 &&
        rainMm <= 10.0 &&
        rainProb != null &&
        rainProb > 0.0) {
      return WeatherVisualState.drizzle;
    }
    // Rain fallback: positive rainfall > 0.5 mm or moderate probability with positive rainfall
    if (rainMm != null && rainMm > 0.5) {
      return WeatherVisualState.rain;
    }
    if (rainProb != null && rainProb >= 50.0 && (rainMm != null && rainMm > 0.0)) {
      return WeatherVisualState.rain;
    }
  }

  // 4. Extreme heat fallback (applied only when condition did not identify another weather state)
  if (tempC != null && tempC >= 35.0) {
    return WeatherVisualState.extremeHeat;
  }

  // 5. Conservative fallback for unknown / missing data
  return WeatherVisualState.unknown;
}

/// Canvas painter that renders dynamic atmospheric scenic illustrations.
class ScenicWeatherPainter extends CustomPainter {
  final WeatherVisualState state;
  final double animValue;

  ScenicWeatherPainter({
    required this.state,
    required this.animValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (state) {
      case WeatherVisualState.sunny:
        _paintSunny(canvas, size);
        break;
      case WeatherVisualState.partlyCloudy:
        _paintPartlyCloudy(canvas, size);
        break;
      case WeatherVisualState.cloudy:
        _paintCloudy(canvas, size);
        break;
      case WeatherVisualState.drizzle:
        _paintDrizzle(canvas, size);
        break;
      case WeatherVisualState.rain:
        _paintRain(canvas, size);
        break;
      case WeatherVisualState.heavyRain:
        _paintHeavyRain(canvas, size);
        break;
      case WeatherVisualState.thunderstorm:
        _paintThunderstorm(canvas, size);
        break;
      case WeatherVisualState.fog:
        _paintFog(canvas, size);
        break;
      case WeatherVisualState.snow:
        _paintSnow(canvas, size);
        break;
      case WeatherVisualState.extremeHeat:
        _paintExtremeHeat(canvas, size);
        break;
      case WeatherVisualState.unknown:
        _paintUnknown(canvas, size);
        break;
    }
  }

  // ── 1. SUNNY / CLEAR ───────────────────────────────────────
  void _paintSunny(Canvas canvas, Size size) {
    // Vibrant blue sky
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF29B6F6),
          Color(0xFF4FC3F7),
          Color(0xFFB3E5FC),
          Color(0xFFE1F5FE),
        ],
        stops: [0.0, 0.4, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // Sun at top right
    final sunCenter = Offset(size.width * 0.82, size.height * 0.22);
    final pulse = math.sin(animValue * math.pi * 2) * 0.06;

    // Outer glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFF9C4).withValues(alpha: 0.65),
          const Color(0xFFFFEE58).withValues(alpha: 0.25),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: 90 * (1 + pulse)));
    canvas.drawCircle(sunCenter, 90 * (1 + pulse), glowPaint);

    // Sun rays
    final rayPaint = Paint()
      ..color = const Color(0xFFFFFDE7).withValues(alpha: 0.35)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 12; i++) {
      final angle = (i * math.pi / 6) + (animValue * 0.2);
      final p1 = sunCenter + Offset(math.cos(angle) * 32, math.sin(angle) * 32);
      final p2 = sunCenter + Offset(math.cos(angle) * 58, math.sin(angle) * 58);
      canvas.drawLine(p1, p2, rayPaint);
    }

    // Sun core
    final corePaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFFFEE58), Color(0xFFFFB300)],
        stops: [0.0, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: 26));
    canvas.drawCircle(sunCenter, 26, corePaint);

    // Distant blue mountain ridge
    _drawMountainRidge(
      canvas,
      size,
      baseY: size.height * 0.68,
      height: 48,
      color: const Color(0xFF81D4FA).withValues(alpha: 0.55),
    );

    // Midground rolling green hills
    _drawRollingHills(
      canvas,
      size,
      baseY: size.height * 0.76,
      amplitude: 28,
      color: const Color(0xFF66BB6A),
    );

    // Foreground lush vibrant hills with tree clusters
    _drawRollingHills(
      canvas,
      size,
      baseY: size.height * 0.85,
      amplitude: 20,
      color: const Color(0xFF388E3C),
    );
    _drawTreeCluster(canvas, Offset(size.width * 0.15, size.height * 0.78), 18, const Color(0xFF2E7D32));
    _drawTreeCluster(canvas, Offset(size.width * 0.78, size.height * 0.82), 22, const Color(0xFF1B5E20));
  }

  // ── 2. PARTLY CLOUDY ───────────────────────────────────────
  void _paintPartlyCloudy(Canvas canvas, Size size) {
    // Sky
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF42A5F5), Color(0xFF90CAF9), Color(0xFFE3F2FD)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // Sun peeking
    final sunCenter = Offset(size.width * 0.75, size.height * 0.24);
    final corePaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFFFEE58)],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: 24));
    canvas.drawCircle(sunCenter, 24, corePaint);

    // Fluffy clouds drifting
    final drift = (animValue * 40);
    _drawFluffyCloud(canvas, Offset(size.width * 0.65 + drift % 60, size.height * 0.28), 38, Colors.white.withValues(alpha: 0.95));
    _drawFluffyCloud(canvas, Offset(size.width * 0.22, size.height * 0.20), 30, Colors.white.withValues(alpha: 0.85));

    // Green hills
    _drawMountainRidge(canvas, size, baseY: size.height * 0.68, height: 42, color: const Color(0xFF90A4AE).withValues(alpha: 0.6));
    _drawRollingHills(canvas, size, baseY: size.height * 0.77, amplitude: 26, color: const Color(0xFF4CAF50));
    _drawRollingHills(canvas, size, baseY: size.height * 0.86, amplitude: 18, color: const Color(0xFF2E7D32));
  }

  // ── 3. CLOUDY / OVERCAST ───────────────────────────────────
  void _paintCloudy(Canvas canvas, Size size) {
    // Overcast gray-slate sky
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF78909C), Color(0xFFB0BEC5), Color(0xFFECEFF1)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // Dense cloud layers
    _drawFluffyCloud(canvas, Offset(size.width * 0.25, size.height * 0.18), 50, const Color(0xFFCFD8DC));
    _drawFluffyCloud(canvas, Offset(size.width * 0.70, size.height * 0.22), 56, const Color(0xFFB0BEC5));
    _drawFluffyCloud(canvas, Offset(size.width * 0.45, size.height * 0.32), 48, Colors.white.withValues(alpha: 0.9));

    // Muted green hills
    _drawMountainRidge(canvas, size, baseY: size.height * 0.70, height: 40, color: const Color(0xFF78909C).withValues(alpha: 0.5));
    _drawRollingHills(canvas, size, baseY: size.height * 0.78, amplitude: 24, color: const Color(0xFF689F38));
    _drawRollingHills(canvas, size, baseY: size.height * 0.86, amplitude: 18, color: const Color(0xFF33691E));
  }

  // ── 4. DRIZZLE ─────────────────────────────────────────────
  void _paintDrizzle(Canvas canvas, Size size) {
    // Cool mist sky
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF607D8B), Color(0xFF90A4AE), Color(0xFFCFD8DC)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // Soft gray clouds
    _drawFluffyCloud(canvas, Offset(size.width * 0.35, size.height * 0.18), 46, const Color(0xFFB0BEC5));
    _drawFluffyCloud(canvas, Offset(size.width * 0.75, size.height * 0.22), 44, const Color(0xFF90A4AE));

    // Hills
    _drawRollingHills(canvas, size, baseY: size.height * 0.78, amplitude: 24, color: const Color(0xFF558B2F));
    _drawRollingHills(canvas, size, baseY: size.height * 0.86, amplitude: 18, color: const Color(0xFF2E7D32));

    // Gentle drizzle rain streaks
    _drawRainDrops(canvas, size, count: 40, length: 10, strokeWidth: 1.2, speed: 1.2, alpha: 0.45);
  }

  // ── 5. RAIN ────────────────────────────────────────────────
  void _paintRain(Canvas canvas, Size size) {
    // Stormy rain sky
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF37474F), Color(0xFF546E7A), Color(0xFF90A4AE)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // Dark rain clouds
    _drawFluffyCloud(canvas, Offset(size.width * 0.25, size.height * 0.16), 55, const Color(0xFF455A64));
    _drawFluffyCloud(canvas, Offset(size.width * 0.68, size.height * 0.20), 60, const Color(0xFF37474F));
    _drawFluffyCloud(canvas, Offset(size.width * 0.45, size.height * 0.26), 48, const Color(0xFF607D8B).withValues(alpha: 0.9));

    // Hills
    _drawRollingHills(canvas, size, baseY: size.height * 0.77, amplitude: 22, color: const Color(0xFF33691E));
    _drawRollingHills(canvas, size, baseY: size.height * 0.86, amplitude: 18, color: const Color(0xFF1B5E20));

    // Diagonal rain streaks
    _drawRainDrops(canvas, size, count: 70, length: 18, strokeWidth: 1.6, speed: 2.0, alpha: 0.65);
  }

  // ── 6. HEAVY RAIN ──────────────────────────────────────────
  void _paintHeavyRain(Canvas canvas, Size size) {
    // Dark ominous slate sky
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF212121), Color(0xFF37474F), Color(0xFF455A64)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // Deep storm clouds
    _drawFluffyCloud(canvas, Offset(size.width * 0.3, size.height * 0.14), 62, const Color(0xFF263238));
    _drawFluffyCloud(canvas, Offset(size.width * 0.75, size.height * 0.16), 68, const Color(0xFF212121));

    // Hills in storm
    _drawRollingHills(canvas, size, baseY: size.height * 0.78, amplitude: 20, color: const Color(0xFF2E4029));
    _drawRollingHills(canvas, size, baseY: size.height * 0.87, amplitude: 16, color: const Color(0xFF1B2A18));

    // Dense heavy rain sheets
    _drawRainDrops(canvas, size, count: 120, length: 26, strokeWidth: 2.2, speed: 3.2, alpha: 0.8);
  }

  // ── 7. THUNDERSTORM ────────────────────────────────────────
  void _paintThunderstorm(Canvas canvas, Size size) {
    // Purple twilight storm sky
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1A237E), Color(0xFF311B92), Color(0xFF263238)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // Thunderheads
    _drawFluffyCloud(canvas, Offset(size.width * 0.3, size.height * 0.15), 65, const Color(0xFF1E1B4B));
    _drawFluffyCloud(canvas, Offset(size.width * 0.7, size.height * 0.18), 70, const Color(0xFF1A1A2E));

    // Dynamic lightning flash
    final isFlashing = (animValue * 6).floor() % 3 == 0;
    if (isFlashing) {
      final boltPaint = Paint()
        ..color = const Color(0xFFFFF59D)
        ..strokeWidth = 2.8
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;

      final path = Path()
        ..moveTo(size.width * 0.65, size.height * 0.16)
        ..lineTo(size.width * 0.61, size.height * 0.34)
        ..lineTo(size.width * 0.67, size.height * 0.38)
        ..lineTo(size.width * 0.58, size.height * 0.62);
      canvas.drawPath(path, boltPaint);

      final glowPaint = Paint()
        ..color = const Color(0xFFE1BEE7).withValues(alpha: 0.4)
        ..strokeWidth = 7.0
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, glowPaint);
    }

    // Dark terrain
    _drawRollingHills(canvas, size, baseY: size.height * 0.80, amplitude: 22, color: const Color(0xFF1F2937));
    _drawRollingHills(canvas, size, baseY: size.height * 0.88, amplitude: 16, color: const Color(0xFF111827));

    // Heavy rain streaks
    _drawRainDrops(canvas, size, count: 90, length: 22, strokeWidth: 1.8, speed: 2.8, alpha: 0.75);
  }

  // ── 8. FOG / MIST ──────────────────────────────────────────
  void _paintFog(Canvas canvas, Size size) {
    // Silvery pale foggy sky
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF90A4AE), Color(0xFFCFD8DC), Color(0xFFECEFF1)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // Faded ghost mountains
    _drawMountainRidge(canvas, size, baseY: size.height * 0.70, height: 35, color: const Color(0xFFB0BEC5).withValues(alpha: 0.4));
    _drawRollingHills(canvas, size, baseY: size.height * 0.79, amplitude: 20, color: const Color(0xFF78909C).withValues(alpha: 0.6));

    // Layered drifting horizontal fog banks
    final fogPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.1),
          Colors.white.withValues(alpha: 0.75),
          Colors.white.withValues(alpha: 0.1),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final drift1 = (animValue * 30);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-30 + drift1, size.height * 0.45, size.width + 60, 24),
        const Radius.circular(12),
      ),
      fogPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width - drift1 * 1.2, size.height * 0.62, size.width * 0.8, 30),
        const Radius.circular(15),
      ),
      fogPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-20, size.height * 0.80, size.width + 40, 36),
        const Radius.circular(18),
        ),
      fogPaint,
    );
  }

  // ── 9. SNOW ────────────────────────────────────────────────
  void _paintSnow(Canvas canvas, Size size) {
    // Winter periwinkle sky
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF7986CB), Color(0xFF9FA8DA), Color(0xFFE8EAF6)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // Snow capped mountains
    _drawMountainRidge(canvas, size, baseY: size.height * 0.68, height: 45, color: const Color(0xFFC5CAE9));
    _drawRollingHills(canvas, size, baseY: size.height * 0.78, amplitude: 22, color: const Color(0xFFE0E0E0));
    _drawRollingHills(canvas, size, baseY: size.height * 0.87, amplitude: 16, color: Colors.white);

    // Pine trees with snow
    _drawPineTree(canvas, Offset(size.width * 0.20, size.height * 0.80), 24, const Color(0xFF37474F));
    _drawPineTree(canvas, Offset(size.width * 0.82, size.height * 0.84), 28, const Color(0xFF263238));

    // Floating snowflakes
    final flakePaint = Paint()..color = Colors.white.withValues(alpha: 0.9);
    for (int i = 0; i < 45; i++) {
      final seed = i * 137.5;
      final x = (seed % size.width + math.sin(animValue * math.pi * 2 + i) * 12) % size.width;
      final y = ((i * 19.3) + (animValue * size.height * 0.8)) % size.height;
      final radius = (i % 3) + 1.8;
      canvas.drawCircle(Offset(x, y), radius, flakePaint);
    }
  }

  // ── 10. EXTREME HEAT ───────────────────────────────────────
  void _paintExtremeHeat(Canvas canvas, Size size) {
    // Blazing amber-orange sky
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFD84315), Color(0xFFF4511E), Color(0xFFFFB74D)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // Giant blazing sun
    final sunCenter = Offset(size.width * 0.80, size.height * 0.25);
    final heatPulse = math.sin(animValue * math.pi * 4) * 0.08;

    final outerPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFCC80).withValues(alpha: 0.7),
          const Color(0xFFFF7043).withValues(alpha: 0.3),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: 100 * (1 + heatPulse)));
    canvas.drawCircle(sunCenter, 100 * (1 + heatPulse), outerPaint);

    final corePaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFFF9C4), Color(0xFFFFB300), Color(0xFFE64A19)],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: 36));
    canvas.drawCircle(sunCenter, 36, corePaint);

    // Arid golden brown hills
    _drawMountainRidge(canvas, size, baseY: size.height * 0.70, height: 42, color: const Color(0xFF8D6E63).withValues(alpha: 0.6));
    _drawRollingHills(canvas, size, baseY: size.height * 0.79, amplitude: 22, color: const Color(0xFFA1887F));
    _drawRollingHills(canvas, size, baseY: size.height * 0.88, amplitude: 16, color: const Color(0xFF6D4C41));
  }

  // ── 11. UNKNOWN / UNAVAILABLE ──────────────────────────────
  void _paintUnknown(Canvas canvas, Size size) {
    // Neutral calm slate indigo gradient
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF455A64), Color(0xFF546E7A), Color(0xFF90A4AE)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // Stylized atmospheric cloud with radar rings
    final center = Offset(size.width * 0.75, size.height * 0.26);
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, 28, ringPaint);
    canvas.drawCircle(center, 44, ringPaint);

    _drawFluffyCloud(canvas, center, 32, Colors.white.withValues(alpha: 0.85));

    // Neutral hills
    _drawMountainRidge(canvas, size, baseY: size.height * 0.70, height: 38, color: const Color(0xFF607D8B).withValues(alpha: 0.6));
    _drawRollingHills(canvas, size, baseY: size.height * 0.80, amplitude: 22, color: const Color(0xFF455A64));
    _drawRollingHills(canvas, size, baseY: size.height * 0.88, amplitude: 16, color: const Color(0xFF263238));
  }

  // ── Helper Drawing Primitives ──────────────────────────────
  void _drawMountainRidge(Canvas canvas, Size size, {required double baseY, required double height, required Color color}) {
    final paint = Paint()..color = color;
    final path = Path()..moveTo(0, baseY);

    path.lineTo(size.width * 0.25, baseY - height * 0.8);
    path.lineTo(size.width * 0.50, baseY - height * 0.4);
    path.lineTo(size.width * 0.75, baseY - height);
    path.lineTo(size.width, baseY - height * 0.5);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  void _drawRollingHills(Canvas canvas, Size size, {required double baseY, required double amplitude, required Color color}) {
    final paint = Paint()..color = color;
    final path = Path()..moveTo(0, baseY);

    path.quadraticBezierTo(size.width * 0.25, baseY - amplitude, size.width * 0.5, baseY);
    path.quadraticBezierTo(size.width * 0.75, baseY + amplitude * 0.7, size.width, baseY - amplitude * 0.5);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  void _drawFluffyCloud(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()..color = color;
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(Offset(center.dx - radius * 0.7, center.dy + radius * 0.2), radius * 0.65, paint);
    canvas.drawCircle(Offset(center.dx + radius * 0.7, center.dy + radius * 0.2), radius * 0.65, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - radius * 1.2, center.dy, radius * 2.4, radius * 0.8),
        Radius.circular(radius * 0.4),
      ),
      paint,
    );
  }

  void _drawTreeCluster(Canvas canvas, Offset pos, double size, Color color) {
    final paint = Paint()..color = color;
    canvas.drawCircle(pos, size, paint);
    canvas.drawCircle(Offset(pos.dx - size * 0.5, pos.dy + size * 0.2), size * 0.7, paint);
    canvas.drawCircle(Offset(pos.dx + size * 0.5, pos.dy + size * 0.2), size * 0.7, paint);
  }

  void _drawPineTree(Canvas canvas, Offset base, double height, Color color) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(base.dx, base.dy - height)
      ..lineTo(base.dx + height * 0.4, base.dy)
      ..lineTo(base.dx - height * 0.4, base.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawRainDrops(Canvas canvas, Size size, {required int count, required double length, required double strokeWidth, required double speed, required double alpha}) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < count; i++) {
      final seed = i * 47.0;
      final x = (seed * 11) % size.width;
      final y = ((seed * 17) + (animValue * size.height * speed)) % size.height;
      canvas.drawLine(Offset(x, y), Offset(x - 3, y + length), paint);
    }
  }

  @override
  bool shouldRepaint(covariant ScenicWeatherPainter oldDelegate) {
    return oldDelegate.state != state || oldDelegate.animValue != animValue;
  }
}
