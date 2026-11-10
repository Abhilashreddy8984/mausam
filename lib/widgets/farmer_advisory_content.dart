import 'package:flutter/material.dart';

import '../models/farmer_advisory.dart';
import '../models/weather_data.dart';
import '../services/farmer_advisory_service.dart';
import '../theme/mausam_theme.dart';

/// Single authoritative UI representation of the Farmer Advisory.
/// Rendered identically whether accessed from the main Advisories section tab
/// or the dedicated Farmer Advisory page.
class FarmerAdvisoryContent extends StatelessWidget {
  final WeatherData? weather;
  final VoidCallback? onRetry;

  const FarmerAdvisoryContent({
    super.key,
    required this.weather,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final advisory = FarmerAdvisoryService.compute(weather);

    if (!advisory.hasData || weather == null) {
      return _buildErrorState(context, advisory);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Scenic Farmland Banner
        _buildScenicBanner(),
        const SizedBox(height: 16),

        // 2. Field Suitability Status Card
        _buildSuitabilityCard(advisory),
        const SizedBox(height: 16),

        // 3. Current Agrimet Weather Summary Bar
        _buildWeatherSummaryBar(weather!),
        const SizedBox(height: 16),

        // 4. Farming Metrics Grid (2x2)
        _buildMetricsGrid(advisory),
        const SizedBox(height: 16),

        // 5. Field Management Summary Card
        _buildSummaryCard(advisory),
        const SizedBox(height: 16),

        // 6. Agrimet Division Tip Box
        _buildTipBox(advisory),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildScenicBanner() {
    return Container(
      height: 175,
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
              'assets/images/farm_advisory.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFF15803D),
                alignment: Alignment.center,
                child: const Icon(Icons.agriculture, color: Colors.white54, size: 48),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.65),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'AGRICULTURAL GUIDANCE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF166534),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Farmer Advisory',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Field recommendations & irrigation schedule',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuitabilityCard(FarmerAdvisoryData advisory) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: advisory.statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(MausamTheme.radiusCard),
        border: Border.all(color: advisory.statusColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: advisory.statusColor,
              shape: BoxShape.circle,
            ),
            child: Icon(advisory.statusIcon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  advisory.statusBadge,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: advisory.statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  advisory.statusSubtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF334155),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherSummaryBar(WeatherData weather) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: MausamTheme.cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: _buildWeatherMetric(
              label: 'Condition',
              value: '${weather.tempInt}°C · ${weather.weatherCondition}',
              icon: Icons.wb_sunny_outlined,
              color: const Color(0xFFF59E0B),
            ),
          ),
          Container(width: 1, height: 28, color: Colors.grey[200]),
          Expanded(
            child: _buildWeatherMetric(
              label: 'Humidity',
              value: '${weather.humidity}%',
              icon: Icons.water_drop_outlined,
              color: const Color(0xFF0284C7),
            ),
          ),
          Container(width: 1, height: 28, color: Colors.grey[200]),
          Expanded(
            child: _buildWeatherMetric(
              label: 'Wind',
              value: '${weather.windSpeedInt} km/h ${weather.windDirection}'.trim(),
              icon: Icons.air_rounded,
              color: const Color(0xFF6366F1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontSize: 11, color: MausamTheme.textMuted, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MausamTheme.textPrimary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(FarmerAdvisoryData advisory) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        final aspectRatio = isNarrow ? 1.15 : 1.45;
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: aspectRatio,
          children: [
            _buildMetricTile('Crop Advisory', advisory.cropAdvisory, Icons.grass, const Color(0xFF16A34A)),
            _buildMetricTile('Pest Watch', advisory.pestWatch, Icons.bug_report_outlined, const Color(0xFFEAB308)),
            _buildMetricTile('Soil Moisture', advisory.soilMoisture, Icons.water_drop_outlined, const Color(0xFF0284C7)),
            _buildMetricTile('Expected Rain', advisory.expectedRain, Icons.grain, const Color(0xFF2563EB)),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: MausamTheme.cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: MausamTheme.textMuted,
                    fontWeight: FontWeight.w500,
                    height: 1.15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MausamTheme.textPrimary,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(FarmerAdvisoryData advisory) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: MausamTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            advisory.summaryTitle,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: MausamTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            advisory.summaryText,
            style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _buildDetailRow('Harvest Window', advisory.harvestWindow, Icons.agriculture),
          const SizedBox(height: 8),
          _buildDetailRow('Next Dry Window', advisory.nextDryWindow, Icons.wb_sunny_outlined),
          const SizedBox(height: 8),
          _buildDetailRow('Spraying Advisory', advisory.sprayingAdvisory, Icons.science_outlined),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: MausamTheme.primaryBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontSize: 12, color: MausamTheme.textSecondary),
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MausamTheme.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipBox(FarmerAdvisoryData advisory) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(MausamTheme.radiusCard),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.tips_and_updates_outlined, color: Color(0xFF15803D), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              advisory.officialTip,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF166534), height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, FarmerAdvisoryData advisory) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              advisory.statusBadge,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: MausamTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              advisory.summaryText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: MausamTheme.textSecondary, height: 1.4),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry Fetching Agrimet Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MausamTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
