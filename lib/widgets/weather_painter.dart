// ============================================================
// widgets/weather_painter.dart
//
// High-performance Flutter CustomPainters that render the living
// atmospheric environment inside LivingWeatherHero.
//
// All drawing is performed using pure Canvas vector primitives
// (lines, arcs, paths, radial & linear gradients, and blurs).
// Zero external asset dependencies, zero heavy 3D rendering.
// Performant and responsive across all Android form factors.
// ============================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// SunGlowPainter
// Renders a radiant sun, solar corona, lens flares, and rays.
// Used for CLEAR and EXTREME HEAT atmospheres.
// ─────────────────────────────────────────────────────────────
class SunGlowPainter extends CustomPainter {
  final double animValue;
  final bool isExtremeHeat;

  const SunGlowPainter({
    required this.animValue,
    this.isExtremeHeat = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Position sun at top-right
    final center = Offset(size.width * 0.76, size.height * 0.28);
    final pulse = math.sin(animValue * math.pi * 2) * 0.08;

    final double baseRadius = isExtremeHeat ? 36.0 : 28.0;
    final double coreRadius = baseRadius * (1.0 + pulse * 0.5);

    // 1. Broad ambient atmospheric halo
    final haloRadius = isExtremeHeat ? size.width * 0.55 : size.width * 0.45;
    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: isExtremeHeat
            ? [
                const Color(0xFFFF9800).withValues(alpha: 0.35 + pulse * 0.05),
                const Color(0xFFFF5722).withValues(alpha: 0.18),
                const Color(0xFFBF360C).withValues(alpha: 0.06),
                Colors.transparent,
              ]
            : [
                const Color(0xFFFFF9C4).withValues(alpha: 0.38 + pulse * 0.04),
                const Color(0xFFFFE082).withValues(alpha: 0.20),
                const Color(0xFF64B5F6).withValues(alpha: 0.08),
                Colors.transparent,
              ],
        stops: const [0.0, 0.35, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: haloRadius));
    canvas.drawCircle(center, haloRadius, haloPaint);

    // 2. Radiant solar rays
    final rayCount = isExtremeHeat ? 16 : 12;
    final rayLength = (isExtremeHeat ? 85.0 : 65.0) * (1.0 + pulse);
    final rayPaint = Paint()
      ..color = (isExtremeHeat ? const Color(0xFFFFCC80) : Colors.white)
          .withValues(alpha: isExtremeHeat ? 0.22 : 0.16)
      ..strokeWidth = isExtremeHeat ? 2.5 : 1.8
      ..strokeCap = StrokeCap.round;

    final double baseAngle = animValue * math.pi * 0.25;
    for (int i = 0; i < rayCount; i++) {
      final angle = baseAngle + (i * 2 * math.pi / rayCount);
      final rayStart = center +
          Offset(math.cos(angle) * (coreRadius + 8),
              math.sin(angle) * (coreRadius + 8));
      final rayEnd = center +
          Offset(math.cos(angle) * rayLength, math.sin(angle) * rayLength);
      canvas.drawLine(rayStart, rayEnd, rayPaint);
    }

    // 3. Dense inner corona
    final coronaRadius = coreRadius * 2.2;
    final coronaPaint = Paint()
      ..shader = RadialGradient(
        colors: isExtremeHeat
            ? [
                const Color(0xFFFFE082).withValues(alpha: 0.65),
                const Color(0xFFFF7043).withValues(alpha: 0.35),
                Colors.transparent,
              ]
            : [
                Colors.white.withValues(alpha: 0.70),
                const Color(0xFFFFF59D).withValues(alpha: 0.35),
                Colors.transparent,
              ],
      ).createShader(Rect.fromCircle(center: center, radius: coronaRadius));
    canvas.drawCircle(center, coronaRadius, coronaPaint);

    // 4. Brilliant sun core
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: isExtremeHeat
            ? [
                Colors.white,
                const Color(0xFFFFF59D),
                const Color(0xFFFFB74D),
              ]
            : [
                Colors.white,
                const Color(0xFFFFFDE7),
                const Color(0xFFFFF176),
              ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: coreRadius));
    canvas.drawCircle(center, coreRadius, corePaint);
  }

  @override
  bool shouldRepaint(SunGlowPainter old) =>
      old.animValue != animValue || old.isExtremeHeat != isExtremeHeat;
}

// ─────────────────────────────────────────────────────────────
// CityLandmarkPainter
// Renders the iconic Hyderabad Charminar & skyline silhouette
// at the bottom-right of the hero, matching the design reference.
// ─────────────────────────────────────────────────────────────
class CityLandmarkPainter extends CustomPainter {
  final Color baseColor;
  final Color rimLightColor;
  final double opacity;
  final double flashIntensity; // For thunderstorm lightning lighting

  const CityLandmarkPainter({
    required this.baseColor,
    required this.rimLightColor,
    this.opacity = 0.55,
    this.flashIntensity = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Draw silhouette occupying bottom-right (from x ~ 0.42*w to 1.0*w)
    final double startX = w * 0.40;
    final double endX = w * 1.02;
    final double baseY = h;

    final path = Path();
    path.moveTo(startX, baseY);

    // Low skyline buildings / domes to the left of Charminar (Mecca Masjid)
    final double mLeft = w * 0.42;
    path.lineTo(mLeft, baseY - h * 0.07);
    path.quadraticBezierTo(
      mLeft + w * 0.03,
      baseY - h * 0.12,
      mLeft + w * 0.06,
      baseY - h * 0.07,
    ); // Low dome 1
    path.lineTo(mLeft + w * 0.07, baseY - h * 0.15); // Small minaret
    path.lineTo(mLeft + w * 0.08, baseY - h * 0.15);
    path.lineTo(mLeft + w * 0.09, baseY - h * 0.06);
    path.quadraticBezierTo(
      mLeft + w * 0.13,
      baseY - h * 0.14,
      mLeft + w * 0.17,
      baseY - h * 0.07,
    ); // Low dome 2
    path.lineTo(mLeft + w * 0.19, baseY - h * 0.07);

    // ── CHARMINAR ARCHITECTURE ──
    final double cWidth = w * 0.32;
    final double cLeft = w * 0.64;
    final double cRight = cLeft + cWidth;
    final double cHeight = h * 0.38;
    final double roofY = baseY - cHeight * 0.58;

    // Left outer minaret
    final double min1X = cLeft;
    final double minW = w * 0.032;
    final double minTopY = baseY - cHeight;

    path.lineTo(min1X, baseY - h * 0.07);
    path.lineTo(min1X, roofY);
    path.lineTo(min1X, minTopY + h * 0.04);
    // Minaret balcony 1
    path.lineTo(min1X - 2, minTopY + h * 0.04);
    path.lineTo(min1X - 2, minTopY + h * 0.032);
    path.lineTo(min1X, minTopY + h * 0.032);
    path.lineTo(min1X, minTopY + h * 0.015);
    // Minaret dome cap + spire
    path.quadraticBezierTo(
      min1X + minW * 0.5,
      minTopY - h * 0.012,
      min1X + minW,
      minTopY + h * 0.015,
    );
    path.lineTo(min1X + minW, minTopY + h * 0.032);
    path.lineTo(min1X + minW + 2, minTopY + h * 0.032);
    path.lineTo(min1X + minW + 2, minTopY + h * 0.04);
    path.lineTo(min1X + minW, minTopY + h * 0.04);
    path.lineTo(min1X + minW, roofY);

    // Upper parapet & central dome/gallery
    final double midX = (cLeft + cRight) * 0.5;
    path.lineTo(midX - w * 0.04, roofY);
    // Central ornamental crest
    path.quadraticBezierTo(
      midX,
      roofY - h * 0.035,
      midX + w * 0.04,
      roofY,
    );

    // Right outer minaret
    final double min2X = cRight - minW;
    path.lineTo(min2X, roofY);
    path.lineTo(min2X, minTopY + h * 0.04);
    path.lineTo(min2X - 2, minTopY + h * 0.04);
    path.lineTo(min2X - 2, minTopY + h * 0.032);
    path.lineTo(min2X, minTopY + h * 0.032);
    path.lineTo(min2X, minTopY + h * 0.015);
    // Right minaret dome cap
    path.quadraticBezierTo(
      min2X + minW * 0.5,
      minTopY - h * 0.012,
      min2X + minW,
      minTopY + h * 0.015,
    );
    path.lineTo(min2X + minW, minTopY + h * 0.032);
    path.lineTo(min2X + minW + 2, minTopY + h * 0.032);
    path.lineTo(min2X + minW + 2, minTopY + h * 0.04);
    path.lineTo(min2X + minW, minTopY + h * 0.04);
    path.lineTo(min2X + minW, baseY - h * 0.07);

    // Right skyline tail
    path.lineTo(endX, baseY - h * 0.05);
    path.lineTo(endX, baseY);
    path.close();

    // Fill with atmospheric gradient
    final effectiveOpacity =
        (opacity + flashIntensity * 0.35).clamp(0.0, 1.0);
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          baseColor.withValues(alpha: effectiveOpacity * 0.40),
          baseColor.withValues(alpha: effectiveOpacity * 0.95),
        ],
      ).createShader(Rect.fromLTWH(startX, minTopY, endX - startX, baseY - minTopY));

    canvas.drawPath(path, fillPaint);

    // Top rim-light stroke
    final rimPaint = Paint()
      ..color = rimLightColor.withValues(
        alpha: (0.35 + flashIntensity * 0.45).clamp(0.0, 0.9),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(path, rimPaint);
  }

  @override
  bool shouldRepaint(CityLandmarkPainter old) =>
      old.baseColor != baseColor ||
      old.rimLightColor != rimLightColor ||
      old.opacity != opacity ||
      old.flashIntensity != flashIntensity;
}

// ─────────────────────────────────────────────────────────────
// RainPainter
// Draws visible, elegant rainfall streaks with angle, depth,
// and moving droplets.
// ─────────────────────────────────────────────────────────────
class RainPainter extends CustomPainter {
  final double animValue; // 0.0–1.0, drives streak velocity
  final double intensity; // 0.0–1.0

  const RainPainter({required this.animValue, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final count = (28 + (intensity * 48)).toInt();
    final rng = math.Random(101);

    // Angle of rain: slight wind tilt
    const double slantX = -4.0;

    final paintLight = Paint()
      ..color = Colors.white.withValues(alpha: 0.16 + intensity * 0.14)
      ..strokeWidth = 1.0 + intensity * 0.5
      ..strokeCap = StrokeCap.round;

    final paintHeavy = Paint()
      ..color = Colors.white.withValues(alpha: 0.28 + intensity * 0.22)
      ..strokeWidth = 1.4 + intensity * 0.8
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < count; i++) {
      final seedX = rng.nextDouble();
      final seedY = rng.nextDouble();
      final length = 12.0 + rng.nextDouble() * (14.0 + intensity * 16.0);
      final speed = 0.5 + rng.nextDouble() * 0.8;
      final isFore = (i % 3 == 0);

      final x = (seedX * size.width + animValue * slantX * 30) % size.width;
      final rawY = (seedY + animValue * speed * 1.8) % 1.0;
      final y = rawY * size.height;

      canvas.drawLine(
        Offset(x, y),
        Offset(x + slantX, y + length),
        isFore ? paintHeavy : paintLight,
      );
    }
  }

  @override
  bool shouldRepaint(RainPainter old) =>
      old.animValue != animValue || old.intensity != intensity;
}

// ─────────────────────────────────────────────────────────────
// CloudPainter
// Draws layered, drifting cloud shapes with soft atmospheric blur.
// ─────────────────────────────────────────────────────────────
class CloudPainter extends CustomPainter {
  final double animValue;
  final double opacity;
  final Color tintColor;

  const CloudPainter({
    required this.animValue,
    required this.opacity,
    this.tintColor = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final clouds = [
      _Cloud(0.08, 0.10, 0.45, 0.55),
      _Cloud(0.52, 0.06, 0.38, 0.45),
      _Cloud(0.25, 0.22, 0.42, 0.38),
      _Cloud(0.72, 0.18, 0.35, 0.50),
      _Cloud(0.90, 0.08, 0.32, 0.40),
    ];

    for (final c in clouds) {
      final drift = (animValue * 0.03 + c.x) % 1.2 - 0.1;
      _drawCloudPuff(
        canvas,
        Offset(drift * size.width, c.y * size.height),
        c.scale * size.width * 0.38,
        (opacity * c.opacity).clamp(0.0, 1.0),
      );
    }
  }

  void _drawCloudPuff(
    Canvas canvas,
    Offset center,
    double radius,
    double alpha,
  ) {
    final paint = Paint()
      ..color = tintColor.withValues(alpha: alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    canvas.drawCircle(center, radius * 0.58, paint);
    canvas.drawCircle(
      center + Offset(radius * 0.42, radius * 0.08),
      radius * 0.46,
      paint,
    );
    canvas.drawCircle(
      center + Offset(-radius * 0.38, radius * 0.08),
      radius * 0.40,
      paint,
    );
    canvas.drawCircle(
      center + Offset(radius * 0.12, radius * 0.22),
      radius * 0.52,
      paint,
    );
  }

  @override
  bool shouldRepaint(CloudPainter old) =>
      old.animValue != animValue ||
      old.opacity != opacity ||
      old.tintColor != tintColor;
}

// ─────────────────────────────────────────────────────────────
// LightningPainter
// Draws realistic branching lightning bolts and atmospheric flashes.
// ─────────────────────────────────────────────────────────────
class LightningPainter extends CustomPainter {
  final double animValue; // 0.0–1.0

  const LightningPainter({required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    final phase = animValue % 1.0;
    // Lightning strikes during a brief window
    final inFlash = phase > 0.88;
    if (!inFlash) return;

    final subPhase = (phase - 0.88) / 0.12; // 0.0 to 1.0 inside flash
    // Double-flash intensity curve
    final double flashAlpha = (math.sin(subPhase * math.pi * 3).abs() * 0.85);

    // 1. Ambient sky flash
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = const Color(0xFFD1C4E9).withValues(
          alpha: (flashAlpha * 0.18).clamp(0.0, 0.25),
        ),
    );

    // 2. Realistic branching lightning bolt
    if (subPhase > 0.15 && subPhase < 0.75) {
      final boltPaintGlow = Paint()
        ..color = const Color(0xFFB388FF).withValues(alpha: flashAlpha * 0.8)
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      final boltPaintCore = Paint()
        ..color = Colors.white.withValues(alpha: flashAlpha)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;

      final start = Offset(size.width * 0.74, size.height * 0.05);
      final boltPath = Path();
      boltPath.moveTo(start.dx, start.dy);

      // Main zig-zag trunk
      boltPath.lineTo(start.dx - 12, size.height * 0.18);
      boltPath.lineTo(start.dx + 8, size.height * 0.32);
      boltPath.lineTo(start.dx - 15, size.height * 0.48);
      boltPath.lineTo(start.dx + 4, size.height * 0.62);
      boltPath.lineTo(start.dx - 8, size.height * 0.78);

      // Branch 1
      final branch1 = Path();
      branch1.moveTo(start.dx - 12, size.height * 0.18);
      branch1.lineTo(start.dx - 32, size.height * 0.28);
      branch1.lineTo(start.dx - 22, size.height * 0.38);

      // Branch 2
      final branch2 = Path();
      branch2.moveTo(start.dx + 8, size.height * 0.32);
      branch2.lineTo(start.dx + 28, size.height * 0.42);
      branch2.lineTo(start.dx + 20, size.height * 0.52);

      canvas.drawPath(boltPath, boltPaintGlow);
      canvas.drawPath(boltPath, boltPaintCore);
      canvas.drawPath(branch1, boltPaintGlow);
      canvas.drawPath(branch1, boltPaintCore);
      canvas.drawPath(branch2, boltPaintGlow);
      canvas.drawPath(branch2, boltPaintCore);
    }
  }

  @override
  bool shouldRepaint(LightningPainter old) => old.animValue != animValue;
}

// ─────────────────────────────────────────────────────────────
// HeatWavePainter
// Undulating horizontal bands for shimmering thermal heat.
// ─────────────────────────────────────────────────────────────
class HeatWavePainter extends CustomPainter {
  final double animValue;

  const HeatWavePainter({required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < 6; i++) {
      final yBase = size.height * (0.50 + i * 0.07);
      final path = Path();
      path.moveTo(0, yBase);

      for (double x = 0; x <= size.width; x += 4) {
        final wave = math.sin(
          (x / size.width * 5 * math.pi) +
              animValue * math.pi * 2 +
              i * 0.9,
        );
        path.lineTo(x, yBase + wave * 3.5);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(HeatWavePainter old) => old.animValue != animValue;
}

// ─────────────────────────────────────────────────────────────
// FogPainter
// Horizontal drifting semi-transparent mist banks for FOG.
// ─────────────────────────────────────────────────────────────
class FogPainter extends CustomPainter {
  final double animValue;

  const FogPainter({required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 4; i++) {
      final yFrac = 0.28 + i * 0.18;
      final drift = math.sin(animValue * math.pi * 2 + i * 1.4) * 0.05;
      final y = (yFrac + drift) * size.height;

      final paint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.11 - i * 0.015),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, y - 35, size.width, 70));

      canvas.drawRect(Rect.fromLTWH(0, y - 35, size.width, 70), paint);
    }
  }

  @override
  bool shouldRepaint(FogPainter old) => old.animValue != animValue;
}

// ─────────────────────────────────────────────────────────────
// HazePainter
// Atmospheric particulate haze for POOR AQI.
// ─────────────────────────────────────────────────────────────
class HazePainter extends CustomPainter {
  final double animValue;

  const HazePainter({required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    // Warm sepia hazy wash
    final hazePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF8D6E63).withValues(alpha: 0.10),
          const Color(0xFF6D4C41).withValues(alpha: 0.22),
          const Color(0xFF4E342E).withValues(alpha: 0.14),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, hazePaint);

    // Drifting particulate specks
    final rng = math.Random(55);
    final dotPaint = Paint()..color = const Color(0xFFFFCC80).withValues(alpha: 0.12);
    for (int i = 0; i < 22; i++) {
      final sx = (rng.nextDouble() + animValue * 0.1) % 1.0;
      final sy = (rng.nextDouble() + animValue * 0.05) % 1.0;
      canvas.drawCircle(
        Offset(sx * size.width, sy * size.height),
        1.0 + rng.nextDouble() * 1.5,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(HazePainter old) => old.animValue != animValue;
}

// ─────────────────────────────────────────────────────────────
// WindParticlePainter
// Horizontal drifting particles for strong wind.
// ─────────────────────────────────────────────────────────────
class WindParticlePainter extends CustomPainter {
  final double animValue;

  const WindParticlePainter({required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(17);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 20; i++) {
      final seedX = rng.nextDouble();
      final y = rng.nextDouble() * size.height;
      final length = 14.0 + rng.nextDouble() * 22.0;
      final speed = 0.5 + rng.nextDouble() * 0.6;

      final rawX = (seedX + animValue * speed) % 1.0;
      final x = rawX * size.width;

      canvas.drawLine(
        Offset(x, y),
        Offset(x + length, y + rng.nextDouble() * 3 - 1.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WindParticlePainter old) => old.animValue != animValue;
}

// ─────────────────────────────────────────────────────────────
// Cloud data model
// ─────────────────────────────────────────────────────────────
class _Cloud {
  final double x;
  final double y;
  final double scale;
  final double opacity;

  const _Cloud(this.x, this.y, this.scale, this.opacity);
}
