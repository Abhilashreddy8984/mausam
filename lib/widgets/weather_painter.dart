// ============================================================
// widgets/weather_painter.dart
//
// CustomPainter classes that draw the living weather atmosphere
// inside the hero section.  Each painter is driven by an
// animation value (0.0 → 1.0) from the parent widget's
// AnimationController.
//
// Rules:
//   - No images or external assets.
//   - All drawing uses Canvas primitives only.
//   - Painters are stateless; animation value drives the frame.
//   - Motion is subtle and performant (no heavy blur/shadow loops).
// ============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// RainPainter
// Draws falling rain streaks.
// [intensity] 0.0 = light, 1.0 = heavy
// ─────────────────────────────────────────────────────────────
class RainPainter extends CustomPainter {
  final double animValue; // 0.0–1.0, drives streak position
  final double intensity; // 0.0–1.0

  const RainPainter({required this.animValue, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final count = (20 + (intensity * 30)).toInt();
    final rng = math.Random(42); // fixed seed = deterministic layout

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18 + intensity * 0.12)
      ..strokeWidth = 1.0 + intensity * 0.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < count; i++) {
      final seedX = rng.nextDouble();
      final seedY = rng.nextDouble();
      final length = 8.0 + rng.nextDouble() * 10.0;
      final speed = 0.3 + rng.nextDouble() * 0.7;

      final x = seedX * size.width;
      // y position wraps with animValue so streaks fall continuously
      final rawY = (seedY + animValue * speed) % 1.0;
      final y = rawY * size.height;

      canvas.drawLine(Offset(x, y), Offset(x - 2, y + length), paint);
    }
  }

  @override
  bool shouldRepaint(RainPainter old) =>
      old.animValue != animValue || old.intensity != intensity;
}

// ─────────────────────────────────────────────────────────────
// CloudPainter
// Draws soft drifting cloud shapes.
// ─────────────────────────────────────────────────────────────
class CloudPainter extends CustomPainter {
  final double animValue; // 0.0–1.0
  final double opacity; // base opacity for clouds

  const CloudPainter({required this.animValue, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final clouds = [
      _Cloud(0.1, 0.15, 0.40, 0.6),
      _Cloud(0.55, 0.08, 0.30, 0.4),
      _Cloud(0.30, 0.35, 0.35, 0.3),
      _Cloud(0.70, 0.28, 0.25, 0.5),
    ];

    for (final c in clouds) {
      final drift = (animValue * 0.02 + c.x) % 1.1 - 0.05;
      _drawCloud(
        canvas,
        Offset(drift * size.width, c.y * size.height),
        c.scale * size.width * 0.38,
        opacity * c.opacity,
      );
    }
  }

  void _drawCloud(Canvas canvas, Offset center, double radius, double alpha) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: alpha.clamp(0.0, 1.0))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // Three overlapping circles make a cloud puff
    canvas.drawCircle(center, radius * 0.55, paint);
    canvas.drawCircle(
      center + Offset(radius * 0.45, radius * 0.1),
      radius * 0.45,
      paint,
    );
    canvas.drawCircle(
      center + Offset(-radius * 0.4, radius * 0.1),
      radius * 0.38,
      paint,
    );
    canvas.drawCircle(
      center + Offset(radius * 0.1, radius * 0.25),
      radius * 0.52,
      paint,
    );
  }

  @override
  bool shouldRepaint(CloudPainter old) =>
      old.animValue != animValue || old.opacity != opacity;
}

// ─────────────────────────────────────────────────────────────
// HeatWavePainter
// Draws subtle undulating horizontal bands for heat shimmer.
// ─────────────────────────────────────────────────────────────
class HeatWavePainter extends CustomPainter {
  final double animValue;

  const HeatWavePainter({required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < 5; i++) {
      final yBase = size.height * (0.55 + i * 0.08);
      final path = Path();
      path.moveTo(0, yBase);

      for (double x = 0; x <= size.width; x += 4) {
        final wave = math.sin(
          (x / size.width * 4 * math.pi) + animValue * math.pi * 2 + i * 0.8,
        );
        path.lineTo(x, yBase + wave * 3);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(HeatWavePainter old) => old.animValue != animValue;
}

// ─────────────────────────────────────────────────────────────
// WindParticlePainter
// Draws small drifting horizontal particles for wind.
// ─────────────────────────────────────────────────────────────
class WindParticlePainter extends CustomPainter {
  final double animValue;

  const WindParticlePainter({required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(17);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.20)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 18; i++) {
      final seedX = rng.nextDouble();
      final y = rng.nextDouble() * size.height;
      final length = 12.0 + rng.nextDouble() * 20.0;
      final speed = 0.4 + rng.nextDouble() * 0.6;

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
// FogPainter
// Draws slowly drifting semi-transparent fog layers.
// ─────────────────────────────────────────────────────────────
class FogPainter extends CustomPainter {
  final double animValue;

  const FogPainter({required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 3; i++) {
      final yFrac = 0.3 + i * 0.2;
      final drift = math.sin(animValue * math.pi * 2 + i * 1.2) * 0.04;
      final y = (yFrac + drift) * size.height;

      final paint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.08 - i * 0.01),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, y - 30, size.width, 60));

      canvas.drawRect(Rect.fromLTWH(0, y - 30, size.width, 60), paint);
    }
  }

  @override
  bool shouldRepaint(FogPainter old) => old.animValue != animValue;
}

// ─────────────────────────────────────────────────────────────
// LightningPainter
// Draws a very faint occasional lightning bolt.
// ─────────────────────────────────────────────────────────────
class LightningPainter extends CustomPainter {
  final double animValue; // 0.0–1.0 from a separate slow controller

  const LightningPainter({required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    // Flash only during a narrow window of the cycle
    final phase = animValue % 1.0;
    final inFlash = phase > 0.92;
    if (!inFlash) return;

    final flashAlpha = ((phase - 0.92) / 0.08) < 0.5
        ? (phase - 0.92) / 0.04
        : (1.0 - (phase - 0.96) / 0.04);

    // Background flash — very subtle
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = Colors.white.withValues(
          alpha: (flashAlpha * 0.06).clamp(0.0, 0.06),
        ),
    );
  }

  @override
  bool shouldRepaint(LightningPainter old) => old.animValue != animValue;
}

// ─────────────────────────────────────────────────────────────
// Internal model used by CloudPainter
// ─────────────────────────────────────────────────────────────
class _Cloud {
  final double x;
  final double y;
  final double scale;
  final double opacity;

  const _Cloud(this.x, this.y, this.scale, this.opacity);
}
