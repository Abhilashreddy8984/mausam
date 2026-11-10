// lib/widgets/weather_snow_painter.dart
import 'dart:math';
import 'package:flutter/material.dart';

/// A lightweight painter that draws falling snowflakes.
///
/// The painter uses a sinusoidal path for each flake to give a gentle drift.
/// `animValue` drives the vertical progress (0‑1) and `intensity` controls
/// the number of flakes (0‑1). This implementation is intentionally simple
/// to keep the project size small while providing a clear visual cue.
class SnowPainter extends CustomPainter {
  final double animValue;
  final double intensity; // 0‑1, number of flakes proportional

  SnowPainter({required this.animValue, this.intensity = 0.4});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.5;

    // Number of flakes based on intensity and area.
    final int flakes = (size.width * size.height * intensity / 2000).ceil();
    final rng = Random(animValue.hashCode);
    for (int i = 0; i < flakes; i++) {
      // Horizontal position spreads across the width.
      final x = rng.nextDouble() * size.width;
      // Y position loops with animation value to create continuous fall.
      final y = ((rng.nextDouble() + animValue) % 1.0) * size.height;
      // Small offset for drift.
      final dx = sin((animValue + i) * 2 * pi) * 2;
      canvas.drawLine(Offset(x + dx, y), Offset(x + dx, y + 4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant SnowPainter oldDelegate) =>
      oldDelegate.animValue != animValue || oldDelegate.intensity != intensity;
}
