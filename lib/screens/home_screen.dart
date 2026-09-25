// ============================================================
// screens/home_screen.dart
//
// Reads all weather values from WeatherData (passed in from
// main.dart via MainShell). No direct imports of DemoWeather
// or any static constant remain here.
//
// Sections:
//   A. Header         – app name, location, last-updated time
//   B. Current Hero   – temperature, condition, key metrics
//   C. Persona Strip  – active profile badge + Change button
//   D. "Why you're seeing this" explanation bar
//   E. Personalized Cards – ordered by backend API rank,
//                           falls back to Persona.cardPriority
// ============================================================

import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../models/persona.dart';
import '../models/weather_data.dart';
import '../state/app_state.dart';
import '../state/location_notifier.dart';
import '../widgets/location_bar.dart';
import '../widgets/weather_card.dart';
import '../widgets/persona_selector.dart';
import 'persona_screen.dart';
import 'detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppPersonaNotifier personaNotifier;
  final WeatherData weather;
  final LocationNotifier locationNotifier;

  /// Ranked card type strings delivered by the FastAPI backend.
  /// When the backend is available this drives the card order.
  /// When null the screen falls back to persona.cardPriority.
  final ValueNotifier<List<String>?> backendCardOrderNotifier;

  const HomeScreen({
    super.key,
    required this.personaNotifier,
    required this.weather,
    required this.locationNotifier,
    required this.backendCardOrderNotifier,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  // Card catalogue derived from the WeatherData snapshot.
  // Built once — the catalogue does not change unless weather
  // data is refreshed (future: rebuild on new API response).
  late final List<WeatherCardData> _catalogue;

  // ── Maps backend card type strings → Flutter WeatherCardType ──
  //
  // The backend uses snake_case strings (e.g. "rain_alert").
  // Flutter uses a WeatherCardType enum.
  // Types that exist in the backend but not in Flutter's enum
  // (e.g. "feels_like", "sunrise_sunset", "pollen") are omitted
  // from this map — those backend cards are simply skipped when
  // building the rank, so the unmapped Flutter cards fall to the
  // end in their natural catalogue order.
  static const Map<String, WeatherCardType> _backendTypeMap = {
    'rain_alert': WeatherCardType.rain,
    'temperature': WeatherCardType.temperature,
    'humidity': WeatherCardType.humidity,
    'wind_speed': WeatherCardType.wind,
    'uv_index': WeatherCardType.uvIndex,
    'air_quality': WeatherCardType.aqi,
    'visibility': WeatherCardType.visibility,
  };

  @override
  void initState() {
    super.initState();
    _catalogue = buildWeatherCardCatalogue(widget.weather);
  }

  // ── Card ordering ───────────────────────────────────────────
  //
  // Priority chain:
  //   1. Backend ranked order (when available)
  //   2. Local persona.cardPriority (fallback)
  //
  // The backend order is read from backendCardOrderNotifier
  // inside the ValueListenableBuilder in build(), so a fresh
  // backend response automatically triggers a UI rebuild with
  // the new ordering — no setState() needed here.
  List<WeatherCardData> _sortedCards(
    Persona persona,
    List<String>? backendOrder,
  ) {
    if (backendOrder != null && backendOrder.isNotEmpty) {
      return _sortedByBackend(backendOrder);
    }
    return _sortedByPersona(persona);
  }

  /// Sort using the ordered list of type strings from the backend.
  /// Backend-mapped cards come first (in backend rank order).
  /// Unmapped Flutter cards (farmAdvisory, travelAdvisory, etc.)
  /// are appended at the end in their original catalogue order.
  List<WeatherCardData> _sortedByBackend(List<String> backendOrder) {
    // Build rank map: WeatherCardType → position index
    final Map<WeatherCardType, int> rank = {};
    int idx = 0;
    for (final typeStr in backendOrder) {
      final flutterType = _backendTypeMap[typeStr];
      if (flutterType != null && !rank.containsKey(flutterType)) {
        rank[flutterType] = idx++;
      }
    }
    // Cards with no backend mapping get rank 9000 + original position,
    // preserving their relative catalogue order at the end.
    return List<WeatherCardData>.from(_catalogue)..sort((a, b) {
      final ra = rank[a.type] ?? (9000 + _catalogue.indexOf(a));
      final rb = rank[b.type] ?? (9000 + _catalogue.indexOf(b));
      return ra.compareTo(rb);
    });
  }

  /// Fallback: sort using local persona.cardPriority list.
  List<WeatherCardData> _sortedByPersona(Persona persona) {
    final priority = persona.cardPriority;
    final Map<WeatherCardType, int> rank = {
      for (int i = 0; i < priority.length; i++) priority[i]: i,
    };
    return List<WeatherCardData>.from(_catalogue)..sort((a, b) {
      final ra = rank[a.type] ?? 999;
      final rb = rank[b.type] ?? 999;
      return ra.compareTo(rb);
    });
  }

  // ── Navigation ──────────────────────────────────────────────
  Future<void> _openPersonaScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PersonaScreen(personaNotifier: widget.personaNotifier),
      ),
    );
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  void _openDetail(WeatherCardData card) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            WeatherDetailScreen(card: card, weather: widget.weather),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Outer listener: backend card order (drives card ranking).
    // Rebuilds the card grid whenever the backend responds or clears.
    return ValueListenableBuilder<List<String>?>(
      valueListenable: widget.backendCardOrderNotifier,
      builder: (context, backendOrder, _) {
        // Inner listener: selected persona (drives everything else).
        return ValueListenableBuilder<Persona>(
          valueListenable: widget.personaNotifier,
          builder: (context, persona, _) {
            final sorted = _sortedCards(persona, backendOrder);

            return Scaffold(
              backgroundColor: const Color(0xFFF5F7FA),
              body: SafeArea(
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader(context)),
                    // ── Location bar (GPS coordinates strip) ──
                    // Shows detected coordinates once permission
                    // is granted. Sits just below the app header
                    // without disturbing any existing layout.
                    SliverToBoxAdapter(
                      child: LocationBar(
                        locationNotifier: widget.locationNotifier,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _buildCurrentWeatherHero(context),
                    ),
                    SliverToBoxAdapter(
                      child: _buildPersonaStrip(context, persona),
                    ),
                    SliverToBoxAdapter(
                      child: _buildWhySection(context, persona),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverToBoxAdapter(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          switchInCurve: Curves.easeOut,
                          child: WeatherCardGrid(
                            // Key includes backendOrder length so the grid
                            // re-animates when the backend response arrives.
                            key: ValueKey('${persona}_${backendOrder?.length}'),
                            cards: sorted,
                            onCardTap: _openDetail,
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: _buildFooter(context)),
                  ],
                ),
              ),
            );
          }, // inner ValueListenableBuilder (persona)
        );
      }, // outer ValueListenableBuilder (backendCardOrder)
    );
  }

  // ── A: Header ───────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    // Timestamp: show "Updated just now" for demo; use formatted
    // timestamp when a real API provides one.
    final updatedLabel = widget.weather.timestamp != null
        ? _formatTimestamp(widget.weather.timestamp!)
        : 'Updated just now';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cloud, color: primary, size: 22),
                  const SizedBox(width: 6),
                  Text(
                    'MAUSAM',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                      color: primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Personalized weather for every user',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 3),
                  // City name now comes from WeatherData
                  Text(
                    widget.weather.city,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                updatedLabel,
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Updated just now';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
    return 'Updated ${diff.inHours}h ago';
  }

  // ── B: Current Weather Hero ─────────────────────────────────
  Widget _buildCurrentWeatherHero(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final heroEnd = Color.fromARGB(
      255,
      (primary.r * 255.0).round().clamp(0, 255),
      (primary.g * 255.0).round().clamp(0, 255),
      ((primary.b * 255.0).round() + 40).clamp(0, 255),
    );

    final w = widget.weather; // local alias for brevity

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, heroEnd],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Condition label
          Row(
            children: [
              Icon(
                Icons.wb_cloudy_outlined,
                color: Colors.white.withValues(alpha: 0.9),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                w.weatherCondition,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Temperature + sunrise/sunset
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${w.tempInt}°',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 72,
                  fontWeight: FontWeight.w300,
                  height: 1.0,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'C',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 22,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (w.sunrise != null)
                    _miniStat(Icons.wb_twilight, w.sunrise!, 'Sunrise'),
                  if (w.sunrise != null && w.sunset != null)
                    const SizedBox(height: 8),
                  if (w.sunset != null)
                    _miniStat(Icons.nights_stay_outlined, w.sunset!, 'Sunset'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Condition detail
          Text(
            w.weatherConditionDetail,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 16),

          // Key metrics strip
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _heroMetric(
                  Icons.thermostat_outlined,
                  'Feels like',
                  '${w.feelsLikeInt}°C',
                ),
                _vDivider(),
                _heroMetric(
                  Icons.water_drop_outlined,
                  'Humidity',
                  '${w.humidity}%',
                ),
                _vDivider(),
                _heroMetric(Icons.wind_power, 'Wind', '${w.windSpeedInt} km/h'),
                _vDivider(),
                _heroMetric(
                  Icons.visibility_outlined,
                  'Visibility',
                  '${w.visibilityStr} km',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String value, String label) => Row(
    children: [
      Icon(icon, color: Colors.white60, size: 13),
      const SizedBox(width: 4),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ],
  );

  Widget _heroMetric(IconData icon, String label, String value) => Column(
    children: [
      Icon(icon, color: Colors.white70, size: 16),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
    ],
  );

  Widget _vDivider() => Container(
    height: 28,
    width: 1,
    color: Colors.white.withValues(alpha: 0.25),
  );

  // ── C: Persona Strip ─────────────────────────────────────────
  Widget _buildPersonaStrip(BuildContext context, Persona persona) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Text(
            'Weather Profile',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 10),
          PersonaBadge(persona: persona, onChangeTap: _openPersonaScreen),
          const Spacer(),
          TextButton.icon(
            onPressed: _openPersonaScreen,
            icon: const Icon(Icons.tune, size: 15),
            label: const Text('Change'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ── D: "Why you're seeing this" ──────────────────────────────
  Widget _buildWhySection(BuildContext context, Persona persona) {
    final secondary = Theme.of(context).colorScheme.secondary;
    final secondaryContainer = Theme.of(context).colorScheme.secondaryContainer;

    final topCards = persona.cardPriority
        .take(3)
        .map((t) => _catalogue.firstWhere((c) => c.type == t).title)
        .join(', ');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: secondary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: secondary),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
                children: [
                  const TextSpan(
                    text: 'Why you\'re seeing this  ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text:
                        'Prioritised for your ${persona.label} profile'
                        ' — showing $topCards first. '
                        'All weather data is on the Explore tab.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer ───────────────────────────────────────────────────
  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        children: [
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outlined, size: 13, color: Colors.grey[400]),
              const SizedBox(width: 5),
              Text(
                'Demo data · IMD integration coming soon',
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'SIH26076 · Mausam Personalized Homepage Prototype',
            style: TextStyle(fontSize: 10, color: Colors.grey[350]),
          ),
        ],
      ),
    );
  }
}
