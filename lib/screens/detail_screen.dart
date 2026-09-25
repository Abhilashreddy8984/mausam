// ============================================================
// screens/detail_screen.dart
// Displays extended detail for a single weather metric.
// Receives WeatherData so location strings come from the model,
// not from DemoWeather static constants.
// ============================================================

import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../data/detail_data.dart';
import '../models/weather_data.dart';

class WeatherDetailScreen extends StatelessWidget {
  final WeatherCardData card;
  final WeatherData weather;

  const WeatherDetailScreen({
    super.key,
    required this.card,
    required this.weather,
  });

  @override
  Widget build(BuildContext context) {
    final detail = kDetailContent[card.type];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Hero app bar ──────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: card.accentColor,
            surfaceTintColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Back',
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroBanner(
                card: card,
                detail: detail,
                weather: weather,
              ),
            ),
            title: Text(
              card.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
          ),

          // ── Body content ──────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (detail != null) ...[
                    _SummaryCard(detail: detail),
                    const SizedBox(height: 16),
                  ],
                  if (detail != null && detail.rows.isNotEmpty) ...[
                    _sectionLabel('Details'),
                    const SizedBox(height: 10),
                    _DetailRowsCard(
                      rows: detail.rows,
                      accent: card.accentColor,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (detail?.tip != null) ...[
                    _sectionLabel('Advisory'),
                    const SizedBox(height: 10),
                    _TipCard(tip: detail!.tip!, accent: card.accentColor),
                    const SizedBox(height: 16),
                  ],
                  const _SourceNote(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Colors.grey[400],
      letterSpacing: 1.1,
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// _HeroBanner
// ─────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  final WeatherCardData card;
  final WeatherDetailContent? detail;
  final WeatherData weather;

  const _HeroBanner({
    required this.card,
    required this.detail,
    required this.weather,
  });

  @override
  Widget build(BuildContext context) {
    final heroValue = detail?.heroValue ?? card.value;
    final heroUnit = detail?.heroUnit ?? '';

    final heroEnd = Color.fromARGB(
      255,
      (card.accentColor.r * 255.0).round().clamp(0, 255),
      (card.accentColor.g * 255.0).round().clamp(0, 255),
      ((card.accentColor.b * 255.0).round() + 40).clamp(0, 255),
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [card.accentColor, heroEnd],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(card.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                card.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                heroValue,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 52,
                  fontWeight: FontWeight.w300,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  heroUnit,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 12,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 3),
              // Location now read from WeatherData, not DemoWeather
              Text(
                weather.fullLocation,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'DEMO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SummaryCard
// ─────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final WeatherDetailContent detail;
  const _SummaryCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        detail.summary,
        style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.6),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _DetailRowsCard
// ─────────────────────────────────────────────────────────────
class _DetailRowsCard extends StatelessWidget {
  final List<DetailRow> rows;
  final Color accent;
  const _DetailRowsCard({required this.rows, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          final isLast = i == rows.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        row.icon ?? Icons.info_outline,
                        size: 15,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        row.label,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ),
                    Text(
                      row.value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[850],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(height: 1, indent: 44, color: Colors.grey[100]),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _TipCard
// ─────────────────────────────────────────────────────────────
class _TipCard extends StatelessWidget {
  final String tip;
  final Color accent;
  const _TipCard({required this.tip, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tips_and_updates_outlined, size: 18, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SourceNote
// ─────────────────────────────────────────────────────────────
class _SourceNote extends StatelessWidget {
  const _SourceNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.info_outlined, size: 12, color: Colors.grey[400]),
        const SizedBox(width: 5),
        Text(
          'Demo data · IMD API integration coming soon',
          style: TextStyle(fontSize: 11, color: Colors.grey[400]),
        ),
      ],
    );
  }
}
