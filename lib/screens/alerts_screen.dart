import 'package:flutter/material.dart';

import '../models/weather_data.dart';
import '../theme/mausam_theme.dart';
import '../widgets/mausam_state_views.dart';

export '../models/weather_data.dart' show AlertSeverity;

class WeatherAlertItem {
  final String title;
  final String description;
  final AlertSeverity severity;
  final String validPeriod;
  final IconData icon;

  const WeatherAlertItem({
    required this.title,
    required this.description,
    required this.severity,
    required this.validPeriod,
    required this.icon,
  });
}

class AlertsScreen extends StatefulWidget {
  final WeatherData? weather;

  const AlertsScreen({super.key, this.weather});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  AlertSeverity? _filterSeverity; // null = all
  late List<WeatherAlertItem> _alerts;

  @override
  void initState() {
    super.initState();
    _initAlerts();
  }

  @override
  void didUpdateWidget(covariant AlertsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weather != widget.weather) {
      _initAlerts();
    }
  }

  void _initAlerts() {
    if (widget.weather == null) {
      _alerts = const [];
      return;
    }

    final alert = widget.weather!.primaryAlert;
    if (!alert.isActive) {
      _alerts = const [];
      return;
    }

    final validPeriod = alert.validPeriod ??
        (widget.weather!.timestamp != null
            ? 'Observed at ${widget.weather!.timestamp!.hour.toString().padLeft(2, '0')}:${widget.weather!.timestamp!.minute.toString().padLeft(2, '0')} IST'
            : 'Current Weather Advisory');

    IconData alertIcon;
    switch (alert.hazardType) {
      case WeatherHazardType.thunderstorm:
        alertIcon = Icons.bolt_rounded;
        break;
      case WeatherHazardType.heavyRain:
        alertIcon = Icons.water_drop_rounded;
        break;
      case WeatherHazardType.hazeFog:
        alertIcon = Icons.visibility_outlined;
        break;
      case WeatherHazardType.strongWind:
        alertIcon = Icons.air_rounded;
        break;
      case WeatherHazardType.heatwave:
        alertIcon = Icons.wb_sunny_rounded;
        break;
      case WeatherHazardType.coldWave:
        alertIcon = Icons.ac_unit_rounded;
        break;
      case WeatherHazardType.poorAqi:
        alertIcon = Icons.masks_rounded;
        break;
      case WeatherHazardType.normal:
        alertIcon = Icons.shield_outlined;
        break;
    }

    _alerts = [
      WeatherAlertItem(
        title: alert.title,
        description: '${alert.headline}\n\nKey Safety Actions:\n• ${alert.precautions.take(2).join('\n• ')}',
        severity: alert.severity,
        validPeriod: validPeriod,
        icon: alertIcon,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filterSeverity == null
        ? _alerts
        : _alerts.where((a) => a.severity == _filterSeverity).toList();

    return Scaffold(
      backgroundColor: MausamTheme.background,
      appBar: AppBar(
        title: const Text('Weather Alerts'),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: 'Filter Alerts',
            onPressed: _showFilterMenu,
          ),
        ],
      ),
      body: filtered.isEmpty
          ? MausamNoAlertsView(
              onBackHome: () {
                setState(() => _filterSeverity = null);
                if (Navigator.canPop(context)) Navigator.pop(context);
              },
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Alert cards
                  ...filtered.map(_buildAlertCard),

                  const SizedBox(height: 16),

                  // Information disclaimer footer
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(MausamTheme.radiusCard),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: Color(0xFF3B82F6), size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'These alerts are based on official weather bulletins and may be subject to change.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1E40AF),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildAlertCard(WeatherAlertItem alert) {
    Color cardBg;
    Color iconBg;
    Color iconColor;
    Color pillBg;
    Color pillText;
    String tagLabel;

    switch (alert.severity) {
      case AlertSeverity.extreme:
      case AlertSeverity.high:
        cardBg = const Color(0xFFFEF2F2);
        iconBg = const Color(0xFFFEE2E2);
        iconColor = const Color(0xFFEF4444);
        pillBg = const Color(0xFFEF4444);
        pillText = Colors.white;
        tagLabel = alert.severity == AlertSeverity.extreme ? 'Extreme' : 'High';
        break;
      case AlertSeverity.medium:
        cardBg = const Color(0xFFFFFBEB);
        iconBg = const Color(0xFFFEF3C7);
        iconColor = const Color(0xFFF59E0B);
        pillBg = const Color(0xFFFDE68A);
        pillText = const Color(0xFF92400E);
        tagLabel = 'Medium';
        break;
      case AlertSeverity.low:
        cardBg = const Color(0xFFFEFCE8);
        iconBg = const Color(0xFFFEF9C3);
        iconColor = const Color(0xFFEAB308);
        pillBg = const Color(0xFFFEF08A);
        pillText = const Color(0xFF854D0E);
        tagLabel = 'Low';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(MausamTheme.radiusCard),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
        boxShadow: MausamTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(alert.icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  alert.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: MausamTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tagLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: pillText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            alert.description,
            style: const TextStyle(
              fontSize: 13,
              color: MausamTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            alert.validPeriod,
            style: const TextStyle(
              fontSize: 11,
              color: MausamTheme.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter by Severity',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('All Alerts'),
                  trailing: _filterSeverity == null ? const Icon(Icons.check, color: MausamTheme.primaryBlue) : null,
                  onTap: () {
                    setState(() => _filterSeverity = null);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  title: const Text('High Severity'),
                  trailing: _filterSeverity == AlertSeverity.high ? const Icon(Icons.check, color: MausamTheme.primaryBlue) : null,
                  onTap: () {
                    setState(() => _filterSeverity = AlertSeverity.high);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  title: const Text('Medium Severity'),
                  trailing: _filterSeverity == AlertSeverity.medium ? const Icon(Icons.check, color: MausamTheme.primaryBlue) : null,
                  onTap: () {
                    setState(() => _filterSeverity = AlertSeverity.medium);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  title: const Text('Low Severity'),
                  trailing: _filterSeverity == AlertSeverity.low ? const Icon(Icons.check, color: MausamTheme.primaryBlue) : null,
                  onTap: () {
                    setState(() => _filterSeverity = AlertSeverity.low);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
