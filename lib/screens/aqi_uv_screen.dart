import 'package:flutter/material.dart';

import '../models/weather_data.dart';
import '../theme/mausam_theme.dart';

class AqiUvScreen extends StatelessWidget {
  final WeatherData weather;

  const AqiUvScreen({super.key, required this.weather});

  @override
  Widget build(BuildContext context) {
    final aqi = weather.aqi;
    final aqiCat = weather.aqiCategory ?? (aqi != null ? 'Good' : 'N/A');
    final uv = weather.uvIndex;
    final uvCat = weather.uvCategory ?? (uv != null ? 'Moderate' : 'N/A');

    return Scaffold(
      backgroundColor: MausamTheme.background,
      appBar: AppBar(
        title: const Text('AQI & UV'),
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
            // ── AQI Card ─────────────────────────────────────
            _buildAqiCard(aqi, aqiCat),
            const SizedBox(height: 16),

            // ── UV Index Card ────────────────────────────────
            _buildUvCard(uv, uvCat),
            const SizedBox(height: 24),

            // ── Other Air Quality Details ────────────────────
            const Text(
              'Other Air Quality Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: MausamTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildPollutantList(),
            const SizedBox(height: 20),

            // ── Quick Tip Card ───────────────────────────────
            _buildQuickTipCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAqiCard(int? aqi, String aqiCat) {
    Color aqiColor = MausamTheme.textMuted;
    if (aqi != null) {
      if (aqi <= 100) {
        aqiColor = MausamTheme.aqiGreen;
      } else if (aqi <= 200) {
        aqiColor = MausamTheme.warningAmber;
      } else {
        aqiColor = MausamTheme.alertRed;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: MausamTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Air Quality Index (AQI)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: MausamTheme.textPrimary,
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: MausamTheme.aqiGreenLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.eco_rounded, color: MausamTheme.aqiGreen, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            aqi != null ? '$aqi' : '--',
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: aqi != null ? aqiColor : MausamTheme.textPrimary,
              height: 1.1,
            ),
          ),
          Text(
            aqiCat,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: aqiColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            aqi != null
                ? 'Air quality is $aqiCat based on latest observation.'
                : 'Air quality data is not reported for this observation station.',
            style: const TextStyle(
              fontSize: 13,
              color: MausamTheme.textSecondary,
              height: 1.4,
            ),
          ),
          if (aqi != null) ...[
            const SizedBox(height: 20),
            // Colored spectrum bar with pointer
            _buildAqiSpectrumBar(aqi),
          ],
        ],
      ),
    );
  }

  Widget _buildAqiSpectrumBar(int aqi) {
    // 0 to 500 scale
    final clampedAqi = aqi.clamp(0, 500);
    final ratio = clampedAqi / 500.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth;
        final thumbOffset = (barWidth * ratio).clamp(8.0, barWidth - 8.0);

        return Column(
          children: [
            // Pointer indicator
            SizedBox(
              height: 12,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: thumbOffset - 5,
                    bottom: 0,
                    child: const Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: MausamTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            // Multi-color spectrum bar
            Container(
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF10B981), // Good
                    Color(0xFF84CC16), // Moderate
                    Color(0xFFFBBF24), // Moderate/sensitive
                    Color(0xFFF97316), // Unhealthy
                    Color(0xFFEF4444), // Very Unhealthy
                    Color(0xFF881337), // Hazardous
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Numbers 0, 50, 100, 200, 300, 500
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0', style: TextStyle(fontSize: 11, color: MausamTheme.textMuted)),
                Text('50', style: TextStyle(fontSize: 11, color: MausamTheme.textMuted)),
                Text('100', style: TextStyle(fontSize: 11, color: MausamTheme.textMuted)),
                Text('200', style: TextStyle(fontSize: 11, color: MausamTheme.textMuted)),
                Text('300', style: TextStyle(fontSize: 11, color: MausamTheme.textMuted)),
                Text('500', style: TextStyle(fontSize: 11, color: MausamTheme.textMuted)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildUvCard(int? uv, String uvCat) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: MausamTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'UV Index',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: MausamTheme.textPrimary,
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: MausamTheme.uvOrangeLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wb_sunny_rounded, color: MausamTheme.uvOrange, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            uv != null ? '$uv' : '--',
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: Color(0xFFC2410C),
              height: 1.1,
            ),
          ),
          Text(
            uvCat,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFFC2410C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            uv != null
                ? 'Protection ${uv >= 6 ? 'Required' : 'Optional'}\nSPF 30+ recommended during peak solar hours.'
                : 'UV index is not reported for this observation time.',
            style: const TextStyle(
              fontSize: 13,
              color: MausamTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPollutantList() {
    final pollutants = [
      {'label': 'PM2.5', 'value': '18 µg/m³', 'icon': Icons.grain_rounded, 'color': const Color(0xFF3B82F6)},
      {'label': 'PM10', 'value': '32 µg/m³', 'icon': Icons.blur_circular_rounded, 'color': const Color(0xFF0EA5E9)},
      {'label': 'NO2', 'value': '12 µg/m³', 'icon': Icons.science_outlined, 'color': const Color(0xFF06B6D4)},
      {'label': 'SO2', 'value': '6 µg/m³', 'icon': Icons.bubble_chart_outlined, 'color': const Color(0xFF6366F1)},
      {'label': 'CO', 'value': '0.8 mg/m³', 'icon': Icons.speed_rounded, 'color': const Color(0xFF8B5CF6)},
    ];

    return Container(
      decoration: MausamTheme.cardDecoration(),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: pollutants.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey[200]),
        itemBuilder: (context, idx) {
          final p = pollutants[idx];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: (p['color'] as Color).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(p['icon'] as IconData, color: p['color'] as Color, size: 16),
                ),
                const SizedBox(width: 14),
                Text(
                  p['label'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MausamTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  p['value'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MausamTheme.textSecondary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickTipCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(MausamTheme.radiusCard),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.eco_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Tip',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF047857),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Keep windows open for fresh air and avoid intense outdoor activity in the afternoon.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF065F46),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
