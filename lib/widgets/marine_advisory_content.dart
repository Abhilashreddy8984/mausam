// ============================================================
// widgets/marine_advisory_content.dart
//
// Interactive Coastal & Marine Advisory UI.
//
// Key Features:
// 1. Geographic Relevance:
//    - Automatically identifies inland locations (e.g. Hyderabad, Delhi)
//      and displays an informative Inland Location Notice.
//    - Maps coastal users strictly to their relevant coast and basin
//      (Mumbai -> Arabian Sea, Chennai -> Bay of Bengal).
//    - Never hardcodes Bay of Bengal as a universal default.
// 2. Interactive Coastal Switcher:
//    - Filter by basin (Arabian Sea, Bay of Bengal, All).
//    - Select from all major Indian coastal stations, ports, and zones.
// 3. Provenance & Accuracy:
//    - Never fabricates tide timings or levels; displays verified status
//      or transparent telemetry unavailable states.
//    - Tracks observation source and timestamp.
// ============================================================

import 'package:flutter/material.dart';

import '../models/marine_advisory_model.dart';
import '../models/weather_data.dart';
import '../services/marine_advisory_service.dart';
import '../theme/mausam_theme.dart';

class MarineAdvisoryContent extends StatefulWidget {
  final WeatherData weather;
  final CoastalStation? initialStation;

  const MarineAdvisoryContent({
    super.key,
    required this.weather,
    this.initialStation,
  });

  @override
  State<MarineAdvisoryContent> createState() => _MarineAdvisoryContentState();
}

class _MarineAdvisoryContentState extends State<MarineAdvisoryContent> {
  late CoastalStation _selectedStation;
  late bool _isUserInland;
  late double _distanceToNearestKm;
  late CoastalStation _nearestStation;
  MarineBasin? _basinFilter;

  @override
  void initState() {
    super.initState();
    final resolution = MarineAdvisoryService.resolveNearestStation(
      city: widget.weather.city,
    );
    _nearestStation = resolution.station;
    _distanceToNearestKm = resolution.distanceKm;
    _isUserInland = resolution.isUserInland;

    _selectedStation = widget.initialStation ?? resolution.station;
  }

  @override
  void didUpdateWidget(covariant MarineAdvisoryContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weather.city != widget.weather.city) {
      final resolution = MarineAdvisoryService.resolveNearestStation(
        city: widget.weather.city,
      );
      setState(() {
        _nearestStation = resolution.station;
        _distanceToNearestKm = resolution.distanceKm;
        _isUserInland = resolution.isUserInland;
        if (widget.initialStation == null) {
          _selectedStation = resolution.station;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final advisory = MarineAdvisoryService.computeMarineAdvisory(
      station: _selectedStation,
      weather: widget.weather,
      isUserInland: _isUserInland,
      distanceKmToUser: _selectedStation == _nearestStation ? _distanceToNearestKm : null,
    );

    final rankedStations = MarineAdvisoryService.rankCoastalStations(
      city: widget.weather.city,
      basinFilter: _basinFilter,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Inland Location Notice (displayed if user is inland)
        if (_isUserInland) ...[
          _buildInlandNotice(),
          const SizedBox(height: 14),
        ],

        // 2. Coastal Basin Filter & Station Selector Chips
        _buildStationSelector(rankedStations),
        const SizedBox(height: 16),

        // 3. Marine Hero Banner
        _buildMarineBanner(advisory),
        const SizedBox(height: 16),

        // 4. Marine Risk Warning (if active)
        if (advisory.marineWarning != null) ...[
          _buildWarningBanner(advisory),
          const SizedBox(height: 16),
        ],

        // 5. 4-metric Marine Conditions Grid
        _buildMetricsGrid(advisory),
        const SizedBox(height: 16),

        // 6. Tide Schedule & Coastal Details Card
        _buildTideScheduleCard(advisory),
        const SizedBox(height: 16),

        // 7. Recommended Maritime Precautions
        _buildPrecautionsCard(advisory),
        const SizedBox(height: 16),

        // 8. Source & Freshness Note
        _buildSourceFooter(advisory),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Inland Location Notice ──────────────────────────────────
  Widget _buildInlandNotice() {
    final cityName = widget.weather.city.isNotEmpty ? widget.weather.city : 'Current Location';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(MausamTheme.radiusCard),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.terrain_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inland Location ($cityName)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF166534),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Your location is inland and has no coastline. Showing nearest coast: '
                  '${_nearestStation.name} (${_nearestStation.basin.shortLabel}, ${_distanceToNearestKm.toInt()} km away). '
                  'Select any coastal region or port below.',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF14532D),
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

  // ── Coastal Station Selector & Basin Filter ────────────────
  Widget _buildStationSelector(
    List<({CoastalStation station, double distanceKm, double rankScore})> ranked,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Coastal Zone / Port',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: MausamTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildBasinChip(null, 'All Coasts'),
              const SizedBox(width: 6),
              _buildBasinChip(MarineBasin.arabianSea, 'Arabian Sea'),
              const SizedBox(width: 6),
              _buildBasinChip(MarineBasin.bayOfBengal, 'Bay of Bengal'),
              const SizedBox(width: 6),
              _buildBasinChip(MarineBasin.andamanSea, 'Andaman Sea'),
              const SizedBox(width: 6),
              _buildBasinChip(MarineBasin.indianOcean, 'Indian Ocean'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: ranked.length,
            separatorBuilder: (_, index) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final item = ranked[idx];
              final isSelected = item.station.id == _selectedStation.id;
              final isNearest = item.station.id == _nearestStation.id;

              return GestureDetector(
                onTap: () => setState(() => _selectedStation = item.station),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? item.station.basin.color
                        : (isNearest ? const Color(0xFFEFF6FF) : Colors.white),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? item.station.basin.color
                          : (isNearest ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0)),
                      width: isNearest ? 1.5 : 1.0,
                    ),
                    boxShadow: isSelected ? MausamTheme.cardShadow : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? Icons.check_circle_rounded : Icons.waves_rounded,
                        size: 14,
                        color: isSelected
                            ? Colors.white
                            : (isNearest ? const Color(0xFF2563EB) : MausamTheme.textSecondary),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.station.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected || isNearest ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isNearest ? const Color(0xFF1D4ED8) : MausamTheme.textPrimary),
                        ),
                      ),
                      if (isNearest) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white24 : const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Nearest',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? Colors.white : const Color(0xFF1E40AF),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBasinChip(MarineBasin? basin, String label) {
    final isSelected = _basinFilter == basin;
    return GestureDetector(
      onTap: () => setState(() => _basinFilter = basin),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  // ── Marine Ocean Banner ─────────────────────────────────────
  Widget _buildMarineBanner(MarineAdvisoryData advisory) {
    final basinGradient = advisory.station.basin == MarineBasin.arabianSea
        ? const [Color(0xFF0F766E), Color(0xFF0284C7)]
        : (advisory.station.basin == MarineBasin.bayOfBengal
            ? const [Color(0xFF0369A1), Color(0xFF1E40AF)]
            : (advisory.station.basin == MarineBasin.andamanSea
                ? const [Color(0xFF0E7490), Color(0xFF155E75)]
                : const [Color(0xFF3730A3), Color(0xFF1E3A8A)]));

    return Container(
      height: 165,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MausamTheme.radiusCard),
        boxShadow: MausamTheme.cardShadow,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: basinGradient,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MausamTheme.radiusCard),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              bottom: -15,
              child: Icon(
                Icons.waves,
                size: 140,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.sailing_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Marine Advisory',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                advisory.station.basin.shortLabel.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  letterSpacing: 0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          advisory.station.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${advisory.station.coastalZone}, ${advisory.station.state}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _isUserInland && advisory.distanceKmToUser != null
                              ? '${advisory.distanceKmToUser!.toInt()} km from ${widget.weather.city}'
                              : (advisory.station.isMajorPort ? 'Major Port Maritime Zone' : 'Coastal Zone'),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.8),
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
          ],
        ),
      ),
    );
  }

  // ── Warning Banner ──────────────────────────────────────────
  Widget _buildWarningBanner(MarineAdvisoryData advisory) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: advisory.riskLevel.bgColor,
        borderRadius: BorderRadius.circular(MausamTheme.radiusCard),
        border: Border.all(color: advisory.riskLevel.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: advisory.riskLevel.color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  advisory.riskLevel.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: advisory.riskLevel.color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  advisory.marineWarning ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1E293B),
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

  // ── 4-metric Conditions Grid ────────────────────────────────
  Widget _buildMetricsGrid(MarineAdvisoryData advisory) {
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
            _buildMetricTile(
              'Sea State (Estimated)',
              advisory.seaConditions,
              Icons.waves,
              advisory.station.basin.color,
            ),
            _buildMetricTile(
              'Wave Height (Estimated)',
              advisory.waveHeightDisplay,
              Icons.tsunami_rounded,
              const Color(0xFF0284C7),
            ),
            _buildMetricTile(
              'Wind Speed',
              advisory.windDisplay,
              Icons.air_rounded,
              const Color(0xFF6366F1),
            ),
            _buildMetricTile(
              'Sea Surface Temp',
              advisory.sstDisplay,
              Icons.thermostat_outlined,
              const Color(0xFF059669),
            ),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MausamTheme.textPrimary,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tide Schedule Card ──────────────────────────────────────
  Widget _buildTideScheduleCard(MarineAdvisoryData advisory) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: MausamTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_rounded, color: Color(0xFF0284C7), size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Tide & Sea Schedule',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MausamTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: advisory.hasLiveTideData
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  advisory.hasLiveTideData ? 'Live Gauge' : 'Live Data Unavailable',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: advisory.hasLiveTideData
                        ? const Color(0xFF166534)
                        : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            'Coastal Station',
            '${advisory.station.name}, ${advisory.station.coastalZone}',
            Icons.location_on_outlined,
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            'Sea Basin',
            advisory.station.basin.label,
            Icons.public_rounded,
          ),
          const SizedBox(height: 8),
          if (advisory.hasLiveTideData && advisory.tides.isNotEmpty) ...[
            for (final tide in advisory.tides) ...[
              _buildDetailRow(
                tide.type,
                '${tide.time} (${tide.formattedHeight})',
                tide.type == 'High Tide'
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
              ),
              const SizedBox(height: 8),
            ],
          ] else ...[
            _buildDetailRow(
              'Tide Telemetry',
              'Live tide data unavailable',
              Icons.schedule_rounded,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 15, color: Color(0xFF64748B)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Live tide data unavailable: No active INCOIS tide gauge telemetry stream connected. Do not use estimated tide values for maritime navigation. Consult official Survey of India / INCOIS tide tables.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Precautions Card ────────────────────────────────────────
  Widget _buildPrecautionsCard(MarineAdvisoryData advisory) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(MausamTheme.radiusCard),
        border: Border.all(color: const Color(0xFF99F6E4)),
        boxShadow: MausamTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.anchor_rounded, color: advisory.station.basin.color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Recommended Precautions',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: advisory.station.basin.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final precaution in advisory.precautions) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: advisory.station.basin.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      precaution,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF0F172A),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Source & Freshness Note ─────────────────────────────────
  Widget _buildSourceFooter(MarineAdvisoryData advisory) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(MausamTheme.radiusCard),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.info_outline, color: Color(0xFF64748B), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data Provenance: ${advisory.sourceCitation}. Observation: ${advisory.observationTime != null ? _formatTimestamp(advisory.observationTime!) : "Live observation"}.',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Data Integrity Notice: Wave heights and sea state are simplified empirical estimates derived solely from local surface wind velocity. Wind duration, fetch length, and water depth/bathymetry are unmodeled. They are not direct ocean buoy measurements. For navigational safety, refer to official INCOIS ocean state forecasts.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
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

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: MausamTheme.textMuted),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: MausamTheme.textSecondary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: MausamTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute IST';
  }
}
