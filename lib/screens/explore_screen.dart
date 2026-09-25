// ============================================================
// screens/explore_screen.dart
// Shows ALL available weather cards in a categorised layout.
//
// Core principle: "Personalization changes the priority, not
// the availability." A Farmer whose home screen shows farm
// cards first can still find Marine/Tide here.
// ============================================================

import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../models/persona.dart';
import '../models/weather_data.dart';
import '../state/app_state.dart';
import '../widgets/weather_card.dart';
import 'detail_screen.dart';

// ─────────────────────────────────────────────────────────────
// Category groups — static, not affected by persona
// ─────────────────────────────────────────────────────────────
class _ExploreCategory {
  final String label;
  final IconData icon;
  final List<WeatherCardType> types;
  const _ExploreCategory(this.label, this.icon, this.types);
}

const _categories = [
  _ExploreCategory('Current Conditions', Icons.wb_sunny_outlined, [
    WeatherCardType.temperature,
    WeatherCardType.humidity,
    WeatherCardType.wind,
    WeatherCardType.visibility,
  ]),
  _ExploreCategory('Precipitation', Icons.water_drop, [WeatherCardType.rain]),
  _ExploreCategory('Health & Environment', Icons.health_and_safety_outlined, [
    WeatherCardType.aqi,
    WeatherCardType.uvIndex,
  ]),
  _ExploreCategory('Advisories & Alerts', Icons.warning_amber_rounded, [
    WeatherCardType.weatherAlert,
    WeatherCardType.farmAdvisory,
    WeatherCardType.travelAdvisory,
  ]),
  _ExploreCategory('Marine & Coastal', Icons.waves, [
    WeatherCardType.marineTide,
  ]),
];

// ─────────────────────────────────────────────────────────────
// ExploreScreen
// ─────────────────────────────────────────────────────────────
class ExploreScreen extends StatelessWidget {
  final AppPersonaNotifier personaNotifier;
  final WeatherData weather;

  const ExploreScreen({
    super.key,
    required this.personaNotifier,
    required this.weather,
  });

  @override
  Widget build(BuildContext context) {
    // Build the card catalogue from the WeatherData snapshot.
    final catalogue = buildWeatherCardCatalogue(weather);
    final Map<WeatherCardType, WeatherCardData> byType = {
      for (final c in catalogue) c.type: c,
    };

    return ValueListenableBuilder<Persona>(
      valueListenable: personaNotifier,
      builder: (context, persona, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                title: Row(
                  children: [
                    Icon(
                      Icons.explore_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Explore',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Divider(height: 1, color: Colors.grey[200]),
                ),
              ),
              SliverToBoxAdapter(child: _PersonaBanner(persona: persona)),
              for (final cat in _categories)
                SliverToBoxAdapter(
                  child: _CategorySection(
                    category: cat,
                    byType: byType,
                    weather: weather,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _PersonaBanner
// ─────────────────────────────────────────────────────────────
class _PersonaBanner extends StatelessWidget {
  final Persona persona;
  const _PersonaBanner({required this.persona});

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.secondary;
    final secondaryContainer = Theme.of(context).colorScheme.secondaryContainer;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: secondary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(persona.icon, size: 16, color: secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: 'All weather data  ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[800],
                    ),
                  ),
                  TextSpan(
                    text:
                        'Your ${persona.label} profile prioritises'
                        ' cards on Home. Everything is available here.',
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
// _CategorySection
// ─────────────────────────────────────────────────────────────
class _CategorySection extends StatelessWidget {
  final _ExploreCategory category;
  final Map<WeatherCardType, WeatherCardData> byType;
  final WeatherData weather;

  const _CategorySection({
    required this.category,
    required this.byType,
    required this.weather,
  });

  @override
  Widget build(BuildContext context) {
    final cards = category.types
        .map((t) => byType[t])
        .whereType<WeatherCardData>()
        .toList();
    if (cards.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                category.icon,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                category.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          WeatherCardGrid(
            cards: cards,
            onCardTap: (card) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    WeatherDetailScreen(card: card, weather: weather),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
