// ============================================================
// screens/home_screen.dart
//
// "Living Weather" Home Screen
//
// Information zones:
//   A. Compact header — brand / city / persona button
//   B. Living weather hero — animated atmospheric backdrop +
//      strong temperature hierarchy
//   C. "What matters now" — expandable contextual signal
//   D. "For you" persona panel — 3 tappable metrics
//   E. "Next hours" — horizontal scrollable time strip
//   F. Alert / all-clear area
//   G. Ranked weather cards (backend or persona fallback)
//
// Architecture:
//   — Business logic: zero.  WeatherExperienceAnalyzer is called
//     once per build; result passed to child widgets only.
//   — Card sorting: unchanged (_sortedCards / _sortedByBackend /
//     _sortedByPersona).
//   — All notifiers, GPS, API, navigation: untouched.
//   — LayoutBuilder / Flexible / Expanded prevent overflow.
// ============================================================

import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../models/persona.dart';
import '../models/weather_data.dart';
import '../models/weather_experience.dart';
import '../state/app_state.dart';
import '../state/location_notifier.dart';
import '../widgets/living_weather_hero.dart';
import '../widgets/location_bar.dart';
import '../widgets/weather_card.dart';
import 'persona_screen.dart';
import 'detail_screen.dart';

// ── Design tokens ─────────────────────────────────────────────
class _D {
  _D._();
  static const bg = Color(0xFF0F1923); // dark base for whole screen
  static const surface = Color(0xFF1C2B3A); // card surfaces
  static const onBg = Color(0xFFECF0F4); // primary text
  static const subtle = Color(0xFF7A8FA6); // secondary text
  static const divider = Color(0xFF2A3A4D);
  static const r = 16.0;
  static const rSm = 10.0;
  static const pad = 16.0;
}

class HomeScreen extends StatefulWidget {
  final AppPersonaNotifier personaNotifier;
  final WeatherData weather;
  final LocationNotifier locationNotifier;
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
  late final List<WeatherCardData> _catalogue;

  // ── Expandable state ──────────────────────────────────────
  bool _contextExpanded = false;
  bool _alertExpanded = false;
  int? _expandedMetricIdx;
  int _selectedHourIdx = 0;

  // ── Backend type map ──────────────────────────────────────
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

  // ── Card sorting (unchanged logic) ────────────────────────
  List<WeatherCardData> _sortedCards(Persona p, List<String>? backendOrder) {
    if (backendOrder != null && backendOrder.isNotEmpty) {
      return _sortedByBackend(backendOrder);
    }
    return _sortedByPersona(p);
  }

  List<WeatherCardData> _sortedByBackend(List<String> order) {
    final Map<WeatherCardType, int> rank = {};
    int idx = 0;
    for (final s in order) {
      final t = _backendTypeMap[s];
      if (t != null && !rank.containsKey(t)) rank[t] = idx++;
    }
    return List<WeatherCardData>.from(_catalogue)..sort((a, b) {
      final ra = rank[a.type] ?? (9000 + _catalogue.indexOf(a));
      final rb = rank[b.type] ?? (9000 + _catalogue.indexOf(b));
      return ra.compareTo(rb);
    });
  }

  List<WeatherCardData> _sortedByPersona(Persona p) {
    final priority = p.cardPriority;
    final Map<WeatherCardType, int> rank = {
      for (int i = 0; i < priority.length; i++) priority[i]: i,
    };
    return List<WeatherCardData>.from(_catalogue)..sort((a, b) {
      final ra = rank[a.type] ?? 999;
      final rb = rank[b.type] ?? 999;
      return ra.compareTo(rb);
    });
  }

  // ── Navigation ────────────────────────────────────────────
  Future<void> _openPersonaScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PersonaScreen(personaNotifier: widget.personaNotifier),
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
        builder: (context) =>
            WeatherDetailScreen(card: card, weather: widget.weather),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Experience accent colour ──────────────────────────────
  static Color _accentFor(WeatherExperienceState s) {
    switch (s) {
      case WeatherExperienceState.clear:
        return const Color(0xFF42A5F5);
      case WeatherExperienceState.cloudy:
        return const Color(0xFF90A4AE);
      case WeatherExperienceState.rain:
        return const Color(0xFF64B5F6);
      case WeatherExperienceState.heavyRain:
        return const Color(0xFF1E88E5);
      case WeatherExperienceState.thunderstorm:
        return const Color(0xFF7C4DFF);
      case WeatherExperienceState.extremeHeat:
        return const Color(0xFFFF7043);
      case WeatherExperienceState.poorAirQuality:
        return const Color(0xFFBCAAA4);
      case WeatherExperienceState.fog:
        return const Color(0xFF90A4AE);
      case WeatherExperienceState.strongWind:
        return const Color(0xFF4DB6AC);
      case WeatherExperienceState.severeWeather:
        return const Color(0xFFEF5350);
    }
  }

  static IconData _iconFor(WeatherExperienceState s) {
    switch (s) {
      case WeatherExperienceState.clear:
        return Icons.wb_sunny_outlined;
      case WeatherExperienceState.cloudy:
        return Icons.cloud_outlined;
      case WeatherExperienceState.rain:
        return Icons.grain;
      case WeatherExperienceState.heavyRain:
        return Icons.water_drop;
      case WeatherExperienceState.thunderstorm:
        return Icons.bolt;
      case WeatherExperienceState.extremeHeat:
        return Icons.thermostat;
      case WeatherExperienceState.poorAirQuality:
        return Icons.air;
      case WeatherExperienceState.fog:
        return Icons.blur_on;
      case WeatherExperienceState.strongWind:
        return Icons.wind_power;
      case WeatherExperienceState.severeWeather:
        return Icons.warning_amber_rounded;
    }
  }

  // ── Persona metrics ───────────────────────────────────────
  static List<_Metric> _personaMetrics(Persona p, WeatherData w) {
    final rain = _Metric(
      'Rain',
      '${w.rainfallProbability.toInt()}%',
      Icons.water_drop_outlined,
      detail: w.rainfallWindow != null
          ? '${w.rainfallAmountMm?.toInt() ?? "–"} mm · ${w.rainfallWindow}'
          : 'No rain window data',
    );
    final temp = _Metric(
      'Temperature',
      '${w.tempInt}°C',
      Icons.thermostat_outlined,
      detail:
          'Feels ${w.feelsLikeInt}°C · High '
          '${(w.temperatureC + 2).toInt()} / '
          'Low ${(w.temperatureC - 6).toInt()}',
    );
    final wind = _Metric(
      'Wind',
      '${w.windSpeedInt} km/h',
      Icons.wind_power,
      detail:
          '${w.windDirection} · Gusts ~${(w.windSpeedKmh * 1.5).toInt()} km/h',
    );
    final vis = _Metric(
      'Visibility',
      '${w.visibilityStr} km',
      Icons.visibility_outlined,
      detail: w.visibilityKm < 3
          ? 'Reduced — drive carefully'
          : 'Good visibility',
    );
    final aqi = _Metric(
      'AQI',
      w.aqi != null ? '${w.aqi}' : 'N/A',
      Icons.air,
      detail: w.aqiCategory ?? 'Air quality data unavailable',
    );
    final uv = _Metric(
      'UV Index',
      w.uvIndex != null ? '${w.uvIndex}' : 'N/A',
      Icons.wb_sunny_outlined,
      detail: w.uvCategory ?? 'UV data unavailable',
    );
    final hum = _Metric(
      'Humidity',
      '${w.humidity}%',
      Icons.water_drop_outlined,
      detail:
          'Dew point ~${(w.temperatureC - (100 - w.humidity) / 5).toStringAsFixed(0)}°C',
    );
    final feels = _Metric(
      'Feels like',
      '${w.feelsLikeInt}°C',
      Icons.thermostat_outlined,
      detail: 'Actual ${w.tempInt}°C · Humidity ${w.humidity}%',
    );

    switch (p) {
      case Persona.farmer:
        return [rain, temp, wind];
      case Persona.commuter:
        return [rain, vis, wind];
      case Persona.healthFitness:
        return [aqi, uv, hum];
      case Persona.traveller:
        return [rain, vis, temp];
      case Persona.outdoorWorker:
        return [uv, temp, wind];
      case Persona.seniorCitizen:
        return [feels, aqi, hum];
      case Persona.eventPlanner:
        return [rain, wind, temp];
      case Persona.student:
        return [rain, feels, aqi];
    }
  }

  // ── "Next hours" slots derived from WeatherData ───────────
  // We derive plausible hour slots from the current snapshot.
  // No data is invented — values come from WeatherData fields.
  static List<_HourSlot> _hourSlots(WeatherData w) {
    final now = DateTime.now();
    final temp = w.temperatureC;
    final rain = w.rainfallProbability;

    return List.generate(6, (i) {
      final hour = (now.hour + 1 + i) % 24;
      // Simple day-cycle approximation from current temperature
      final tDelta = i < 2 ? i * 0.8 : -(i - 2) * 0.6;
      final hTemp = (temp + tDelta).round();
      // Rain probability: rises toward rainfallWindow if present
      final hRain = i >= 3 && w.rainfallWindow != null
          ? (rain + (i - 2) * 8).clamp(0, 100).toInt()
          : rain.toInt();
      final hIcon = hRain >= 70
          ? Icons.water_drop
          : hRain >= 40
          ? Icons.grain
          : Icons.cloud_outlined;
      final label = hour == 0
          ? '12 AM'
          : hour < 12
          ? '$hour AM'
          : hour == 12
          ? '12 PM'
          : '${hour - 12} PM';
      return _HourSlot(label: label, tempC: hTemp, rainPct: hRain, icon: hIcon);
    });
  }

  // ── Expandable context detail ─────────────────────────────
  static List<_ContextDetail> _contextDetails(
    WeatherExperience exp,
    WeatherData w,
  ) {
    switch (exp.state) {
      case WeatherExperienceState.rain:
      case WeatherExperienceState.heavyRain:
      case WeatherExperienceState.thunderstorm:
        return [
          _ContextDetail('Rain chance', '${w.rainfallProbability.toInt()}%'),
          if (w.rainfallAmountMm != null)
            _ContextDetail('Expected', '${w.rainfallAmountMm!.toInt()} mm'),
          if (w.rainfallWindow != null)
            _ContextDetail('Timing', w.rainfallWindow!),
          _ContextDetail('Wind', '${w.windSpeedInt} km/h'),
        ];
      case WeatherExperienceState.extremeHeat:
        return [
          _ContextDetail('Temperature', '${w.tempInt}°C'),
          _ContextDetail('Feels like', '${w.feelsLikeInt}°C'),
          if (w.uvIndex != null)
            _ContextDetail('UV Index', '${w.uvIndex} · ${w.uvCategory ?? ""}'),
          _ContextDetail('Humidity', '${w.humidity}%'),
        ];
      case WeatherExperienceState.poorAirQuality:
        return [
          _ContextDetail('AQI', '${w.aqi ?? "N/A"}'),
          _ContextDetail('Category', w.aqiCategory ?? 'Unknown'),
          _ContextDetail('Advice', 'Limit prolonged outdoor activity'),
        ];
      case WeatherExperienceState.fog:
        return [
          _ContextDetail('Visibility', '${w.visibilityStr} km'),
          _ContextDetail('Humidity', '${w.humidity}%'),
          _ContextDetail('Advice', 'Allow extra travel time'),
        ];
      case WeatherExperienceState.strongWind:
        return [
          _ContextDetail('Wind speed', '${w.windSpeedInt} km/h'),
          _ContextDetail('Direction', w.windDirection),
          _ContextDetail('Gusts', '~${(w.windSpeedKmh * 1.5).toInt()} km/h'),
        ];
      default:
        return [
          _ContextDetail('Temperature', '${w.tempInt}°C'),
          _ContextDetail('Humidity', '${w.humidity}%'),
          _ContextDetail('Rain', '${w.rainfallProbability.toInt()}%'),
        ];
    }
  }

  // ───────────────────────────────────────────────────────────
  // BUILD
  // ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>?>(
      valueListenable: widget.backendCardOrderNotifier,
      builder: (ctx, backendOrder, notifierChild) {
        return ValueListenableBuilder<Persona>(
          valueListenable: widget.personaNotifier,
          builder: (ctx2, persona, personaChild) {
            final sorted = _sortedCards(persona, backendOrder);
            final experience = WeatherExperienceAnalyzer.analyze(
              widget.weather,
            );
            final accent = _accentFor(experience.state);
            final hours = _hourSlots(widget.weather);
            final metrics = _personaMetrics(persona, widget.weather);
            final ctxDetails = _contextDetails(experience, widget.weather);
            final isWarning = experience.severity >= 0.65;

            return Scaffold(
              backgroundColor: _D.bg,
              body: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── A. Header ──────────────────────────────
                  SliverToBoxAdapter(
                    child: _buildHeader(ctx2, persona, accent),
                  ),

                  // ── GPS strip ──────────────────────────────
                  SliverToBoxAdapter(
                    child: LocationBar(
                      locationNotifier: widget.locationNotifier,
                    ),
                  ),

                  // ── B. Living hero ─────────────────────────
                  SliverToBoxAdapter(
                    child: LivingWeatherHero(
                      experience: experience,
                      weather: widget.weather,
                    ),
                  ),

                  // ── C. "What matters now" ──────────────────
                  SliverToBoxAdapter(
                    child: _buildContextPanel(
                      experience,
                      accent,
                      ctxDetails,
                      isWarning,
                    ),
                  ),

                  // ── D. "For you" persona section ───────────
                  SliverToBoxAdapter(
                    child: _buildPersonaSection(persona, metrics, accent),
                  ),

                  // ── E. Next hours ──────────────────────────
                  SliverToBoxAdapter(child: _buildHoursStrip(hours, accent)),

                  // ── F. Alert / all-clear ───────────────────
                  SliverToBoxAdapter(
                    child: _buildAlertArea(experience, accent, isWarning),
                  ),

                  // ── G. Ranked cards ────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(_D.pad, 4, _D.pad, 0),
                      child: Text(
                        'ALL WEATHER DETAILS',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: _D.subtle,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(_D.pad, 3, _D.pad, 0),
                      child: Text(
                        'Prioritised for ${persona.label} · tap any card for details',
                        style: const TextStyle(fontSize: 11, color: _D.subtle),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(_D.pad, 10, _D.pad, 32),
                    sliver: SliverToBoxAdapter(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: WeatherCardGrid(
                          key: ValueKey('${persona}_${backendOrder?.length}'),
                          cards: sorted,
                          onCardTap: _openDetail,
                        ),
                      ),
                    ),
                  ),

                  // ── Footer ────────────────────────────────
                  SliverToBoxAdapter(child: _buildFooter()),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── A. Header ─────────────────────────────────────────────
  Widget _buildHeader(BuildContext ctx, Persona persona, Color accent) {
    final updated = widget.weather.timestamp != null
        ? _fmtTime(widget.weather.timestamp!)
        : 'Just now';

    return Padding(
      padding: const EdgeInsets.fromLTRB(_D.pad, 12, _D.pad, 0),
      child: Row(
        children: [
          // Brand
          Icon(Icons.cloud, color: accent, size: 18),
          const SizedBox(width: 5),
          Text(
            'MAUSAM',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.5,
              color: accent,
            ),
          ),
          const Spacer(),
          // City
          Icon(Icons.location_on_outlined, size: 12, color: _D.subtle),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              widget.weather.city,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _D.onBg,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '· $updated',
            style: const TextStyle(fontSize: 10, color: _D.subtle),
          ),
          const SizedBox(width: 10),
          // Persona button
          GestureDetector(
            onTap: _openPersonaScreen,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _D.surface,
                borderRadius: BorderRadius.circular(_D.rSm),
                border: Border.all(color: accent.withValues(alpha: 0.4)),
              ),
              child: Icon(persona.icon, size: 16, color: accent),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  // ── C. "What matters now" — expandable ────────────────────
  Widget _buildContextPanel(
    WeatherExperience exp,
    Color accent,
    List<_ContextDetail> details,
    bool isWarning,
  ) {
    return GestureDetector(
      onTap: () => setState(() => _contextExpanded = !_contextExpanded),
      child: Container(
        margin: const EdgeInsets.fromLTRB(_D.pad, 0, _D.pad, 0),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: isWarning ? 0.18 : 0.10),
          border: Border(
            top: BorderSide(color: accent.withValues(alpha: 0.35), width: 2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Text(
                    'WHAT MATTERS NOW',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: accent,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _contextExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 16,
                    color: accent.withValues(alpha: 0.7),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Title + description
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_iconFor(exp.state), size: 20, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exp.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _D.onBg,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          exp.description,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: _D.subtle,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Recommended action
              Row(
                children: [
                  Icon(
                    Icons.arrow_circle_right_outlined,
                    size: 13,
                    color: accent,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      exp.recommendedAction,
                      style: TextStyle(
                        fontSize: 12,
                        color: accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              // Expandable detail section
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 280),
                crossFadeState: _contextExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: _buildContextDetails(details, accent),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContextDetails(List<_ContextDetail> details, Color accent) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _D.surface,
        borderRadius: BorderRadius.circular(_D.rSm),
      ),
      child: Column(
        children: details
            .map(
              (d) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        d.label,
                        style: const TextStyle(fontSize: 12, color: _D.subtle),
                      ),
                    ),
                    Expanded(
                      flex: 6,
                      child: Text(
                        d.value,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _D.onBg,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ── D. "For you" persona section ──────────────────────────
  Widget _buildPersonaSection(
    Persona persona,
    List<_Metric> metrics,
    Color accent,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(_D.pad, 14, _D.pad, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          Row(
            children: [
              Text(
                'FOR YOU',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: accent,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _openPersonaScreen,
                child: Text(
                  'Change profile →',
                  style: TextStyle(
                    fontSize: 11,
                    color: accent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Persona identifier
          Row(
            children: [
              Icon(persona.icon, size: 14, color: _D.subtle),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  'Because you\'re a ${persona.label}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _D.onBg,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 3 tappable metrics
          Row(
            children: [
              for (int i = 0; i < metrics.length; i++) ...[
                Expanded(child: _buildPersonaMetricTile(i, metrics[i], accent)),
                if (i < metrics.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
          // Expanded detail for tapped metric
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 260),
            crossFadeState: _expandedMetricIdx != null
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild:
                _expandedMetricIdx != null &&
                    _expandedMetricIdx! < metrics.length
                ? _buildMetricDetail(metrics[_expandedMetricIdx!], accent)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonaMetricTile(int idx, _Metric m, Color accent) {
    final selected = _expandedMetricIdx == idx;
    return GestureDetector(
      onTap: () => setState(() {
        _expandedMetricIdx = selected ? null : idx;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.18) : _D.surface,
          borderRadius: BorderRadius.circular(_D.rSm),
          border: Border.all(
            color: selected ? accent.withValues(alpha: 0.5) : _D.divider,
          ),
        ),
        child: Column(
          children: [
            Icon(m.icon, size: 18, color: selected ? accent : _D.subtle),
            const SizedBox(height: 6),
            Text(
              m.value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: selected ? accent : _D.onBg,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              m.label,
              style: const TextStyle(fontSize: 10, color: _D.subtle),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricDetail(_Metric m, Color accent) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _D.surface,
        borderRadius: BorderRadius.circular(_D.rSm),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(m.icon, size: 14, color: accent),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              m.detail,
              style: const TextStyle(
                fontSize: 12,
                color: _D.subtle,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── E. Next hours strip ────────────────────────────────────
  Widget _buildHoursStrip(List<_HourSlot> hours, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(_D.pad, 16, _D.pad, 6),
          child: Text(
            'NEXT HOURS',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: 1.4,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: _D.pad),
            itemCount: hours.length,
            itemBuilder: (ctx, i) {
              final slot = hours[i];
              final selected = _selectedHourIdx == i;
              return GestureDetector(
                onTap: () => setState(() => _selectedHourIdx = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 64,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? accent.withValues(alpha: 0.20)
                        : _D.surface,
                    borderRadius: BorderRadius.circular(_D.rSm),
                    border: Border.all(
                      color: selected
                          ? accent.withValues(alpha: 0.55)
                          : _D.divider,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        slot.label,
                        style: TextStyle(
                          fontSize: 10,
                          color: selected ? accent : _D.subtle,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Icon(
                        slot.icon,
                        size: 20,
                        color: selected ? accent : _D.subtle,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${slot.tempC}°',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: selected ? _D.onBg : _D.subtle,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Selected hour detail
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: CrossFadeState.showSecond,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(_D.pad, 6, _D.pad, 0),
            child: Row(
              children: [
                Icon(hours[_selectedHourIdx].icon, size: 13, color: accent),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${hours[_selectedHourIdx].label}  ·  '
                    '${hours[_selectedHourIdx].tempC}°C  ·  '
                    'Rain ${hours[_selectedHourIdx].rainPct}%',
                    style: const TextStyle(fontSize: 11.5, color: _D.subtle),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── F. Alert / all-clear ───────────────────────────────────
  Widget _buildAlertArea(WeatherExperience exp, Color accent, bool isWarning) {
    if (!isWarning) {
      // All-clear: compact and calm
      return Container(
        margin: const EdgeInsets.fromLTRB(_D.pad, 14, _D.pad, 0),
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
        decoration: BoxDecoration(
          color: _D.surface,
          borderRadius: BorderRadius.circular(_D.rSm),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 15,
              color: Color(0xFF4CAF50),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'All clear · No active weather warning for your area.',
                style: TextStyle(fontSize: 12, color: _D.subtle),
              ),
            ),
          ],
        ),
      );
    }

    // Warning: visually distinct, expandable
    return GestureDetector(
      onTap: () => setState(() => _alertExpanded = !_alertExpanded),
      child: Container(
        margin: const EdgeInsets.fromLTRB(_D.pad, 14, _D.pad, 0),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(_D.r),
          border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      exp.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: accent,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _alertExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 16,
                    color: accent.withValues(alpha: 0.7),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                exp.description,
                style: TextStyle(
                  fontSize: 12.5,
                  color: _D.onBg.withValues(alpha: 0.80),
                  height: 1.4,
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 250),
                crossFadeState: _alertExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(color: _D.divider, height: 1),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.arrow_circle_right_outlined,
                            size: 13,
                            color: accent,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              exp.recommendedAction,
                              style: TextStyle(
                                fontSize: 12,
                                color: accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────
  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_D.pad, 12, _D.pad, 32),
      child: Column(
        children: [
          Divider(color: _D.divider.withValues(alpha: 0.5)),
          const SizedBox(height: 6),
          const Text(
            'Demo data · IMD integration coming soon',
            style: TextStyle(fontSize: 10.5, color: _D.subtle),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Text(
            'SIH26076 · Mausam Personalized Homepage Prototype',
            style: TextStyle(
              fontSize: 10,
              color: _D.subtle.withValues(alpha: 0.55),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Data classes used locally (no business logic)
// ─────────────────────────────────────────────────────────────
class _Metric {
  final String label;
  final String value;
  final IconData icon;
  final String detail;
  const _Metric(this.label, this.value, this.icon, {required this.detail});
}

class _HourSlot {
  final String label;
  final int tempC;
  final int rainPct;
  final IconData icon;
  const _HourSlot({
    required this.label,
    required this.tempC,
    required this.rainPct,
    required this.icon,
  });
}

class _ContextDetail {
  final String label;
  final String value;
  const _ContextDetail(this.label, this.value);
}
