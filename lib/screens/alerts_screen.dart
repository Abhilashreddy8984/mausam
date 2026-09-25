// ============================================================
// screens/alerts_screen.dart
// Demo weather alerts with severity, title, description, time
// and location. All data is static demo content.
//
// TODO: Replace DemoAlerts with real IMD API alerts.
// ============================================================

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// Alert severity levels
// ─────────────────────────────────────────────────────────────
enum AlertSeverity { red, orange, yellow, green }

extension AlertSeverityStyle on AlertSeverity {
  String get label {
    switch (this) {
      case AlertSeverity.red:    return 'Red Alert';
      case AlertSeverity.orange: return 'Orange Alert';
      case AlertSeverity.yellow: return 'Yellow Alert';
      case AlertSeverity.green:  return 'No Warning';
    }
  }

  Color get color {
    switch (this) {
      case AlertSeverity.red:    return const Color(0xFFD32F2F);
      case AlertSeverity.orange: return const Color(0xFFE64A19);
      case AlertSeverity.yellow: return const Color(0xFFF9A825);
      case AlertSeverity.green:  return const Color(0xFF388E3C);
    }
  }

  IconData get icon {
    switch (this) {
      case AlertSeverity.red:    return Icons.crisis_alert;
      case AlertSeverity.orange: return Icons.warning_rounded;
      case AlertSeverity.yellow: return Icons.warning_amber_rounded;
      case AlertSeverity.green:  return Icons.check_circle_outline;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// DemoAlert model
// ─────────────────────────────────────────────────────────────
class DemoAlert {
  final AlertSeverity severity;
  final String title;
  final String description;
  final String time;
  final String location;
  final String issuedBy;

  const DemoAlert({
    required this.severity,
    required this.title,
    required this.description,
    required this.time,
    required this.location,
    required this.issuedBy,
  });
}

// ─────────────────────────────────────────────────────────────
// Demo alert data
// ─────────────────────────────────────────────────────────────
const List<DemoAlert> kDemoAlerts = [
  DemoAlert(
    severity: AlertSeverity.yellow,
    title: 'Thunderstorm Warning',
    description:
        'Thunderstorm with lightning and gusty winds (30–40 km/h) '
        'expected over Hyderabad, Rangareddy and Medchal districts between '
        '3:00 PM and 8:00 PM. Isolated heavy rainfall (≥ 64 mm in 3 h) '
        'possible. Residents are advised to avoid open areas, tall trees, '
        'and metal structures.',
    time: 'Today · 3:00 PM – 8:00 PM',
    location: 'Hyderabad, Rangareddy, Medchal',
    issuedBy: 'IMD Hyderabad',
  ),
  DemoAlert(
    severity: AlertSeverity.yellow,
    title: 'Urban Flooding Advisory',
    description:
        'Waterlogging is likely at low-lying underpasses and roads in '
        'Hyderabad city following predicted heavy rainfall. Mehdipatnam, '
        'Falaknuma, and Tolichowki areas are particularly vulnerable. '
        'GHMC pumping crews are on standby.',
    time: 'Today · 4:00 PM onwards',
    location: 'GHMC Limits, Hyderabad',
    issuedBy: 'GHMC Disaster Management',
  ),
  DemoAlert(
    severity: AlertSeverity.orange,
    title: 'Heat Wave — Telangana Interior',
    description:
        'Heat wave conditions are very likely in isolated pockets of '
        'Nalgonda, Suryapet, and Khammam districts with maximum '
        'temperatures expected to touch 42–43 °C. Vulnerable populations '
        '(elderly, children, outdoor workers) should avoid outdoor '
        'activity between 11 AM and 4 PM.',
    time: 'Tomorrow · 11:00 AM – 5:00 PM',
    location: 'Nalgonda, Suryapet, Khammam',
    issuedBy: 'IMD Hyderabad',
  ),
  DemoAlert(
    severity: AlertSeverity.yellow,
    title: 'Fishing Advisory — Bay of Bengal',
    description:
        'Rough sea conditions (wave height 2.5–3.5 m) are forecast along '
        'the north Andhra Pradesh coast and adjoining Bay of Bengal. '
        'Fishermen are strongly advised not to venture into the sea. '
        'Those already at sea are advised to return to coast.',
    time: 'Next 48 hours',
    location: 'North AP Coast & BoB',
    issuedBy: 'IMD — Fisheries Division',
  ),
  DemoAlert(
    severity: AlertSeverity.green,
    title: 'Normal Conditions — North Telangana',
    description:
        'Weather conditions are normal in Nizamabad, Karimnagar and '
        'Adilabad districts. No significant weather event expected in '
        'the next 24 hours. Light to moderate rainfall may occur.',
    time: 'Next 24 hours',
    location: 'North Telangana Districts',
    issuedBy: 'IMD Hyderabad',
  ),
];

// ─────────────────────────────────────────────────────────────
// AlertsScreen widget
// ─────────────────────────────────────────────────────────────
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Count active (non-green) alerts
    final activeCount =
        kDemoAlerts.where((a) => a.severity != AlertSeverity.green).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App bar ─────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Row(
              children: [
                Icon(
                  Icons.notifications_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Alerts',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                const SizedBox(width: 8),
                if (activeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$activeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, color: Colors.grey[200]),
            ),
          ),

          // ── Summary strip ───────────────────────────────────
          SliverToBoxAdapter(
            child: _AlertSummaryStrip(activeCount: activeCount),
          ),

          // ── Alert cards ────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _AlertCard(alert: kDemoAlerts[index]),
                ),
                childCount: kDemoAlerts.length,
              ),
            ),
          ),

          // ── Source note ────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outlined,
                      size: 12, color: Colors.grey[400]),
                  const SizedBox(width: 5),
                  Text(
                    'Demo alerts · IMD API integration coming soon',
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _AlertSummaryStrip — severity legend
// ─────────────────────────────────────────────────────────────
class _AlertSummaryStrip extends StatelessWidget {
  final int activeCount;
  const _AlertSummaryStrip({required this.activeCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF9A825).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: Color(0xFFF9A825)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$activeCount active alert${activeCount == 1 ? '' : 's'} for '
              'Hyderabad region · Updated just now',
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _AlertCard — expandable card for one alert
// ─────────────────────────────────────────────────────────────
class _AlertCard extends StatefulWidget {
  final DemoAlert alert;
  const _AlertCard({required this.alert});

  @override
  State<_AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<_AlertCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final sev = widget.alert.severity;
    final color = sev.color;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: _expanded ? 0.5 : 0.2),
            width: _expanded ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Severity icon badge
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(sev.icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Severity chip + title
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                sev.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.alert.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[850],
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Time + location
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                size: 11, color: Colors.grey[400]),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                widget.alert.time,
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[500]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 11, color: Colors.grey[400]),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                widget.alert.location,
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[500]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                ],
              ),
            ),

            // ── Expanded body ──
            if (_expanded) ...[
              Divider(height: 1, color: Colors.grey[100]),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.alert.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.account_balance_outlined,
                            size: 12, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          'Issued by: ${widget.alert.issuedBy}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
