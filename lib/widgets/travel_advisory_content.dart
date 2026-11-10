import 'package:flutter/material.dart';

import '../models/travel_advisory_model.dart';
import '../models/weather_data.dart';
import '../services/api_service.dart';
import '../theme/mausam_theme.dart';

/// Interactive, destination-based Travel Advisory view.
/// Allows users to enter/search a destination, select starting points or routes,
/// and displays real-time weather risks, rainfall, visibility, road conditions,
/// 7-day forecast, and verified safety precautions.
/// Never fabricates unavailable transit or airport data.
class TravelAdvisoryContent extends StatefulWidget {
  final WeatherData? currentWeather;
  final String? initialDestination;

  const TravelAdvisoryContent({
    super.key,
    this.currentWeather,
    this.initialDestination,
  });

  @override
  State<TravelAdvisoryContent> createState() => _TravelAdvisoryContentState();
}

class _TravelAdvisoryContentState extends State<TravelAdvisoryContent> {
  final TextEditingController _destController = TextEditingController();
  final TextEditingController _originController = TextEditingController();

  bool _isRouteMode = false;
  bool _isLoading = false;
  String? _errorMessage;
  TravelAdvisoryModel? _advisory;
  List<LocationSuggestion> _suggestions = [];

  static const List<String> _quickDestinations = [
    'Delhi',
    'Mumbai',
    'Bengaluru',
    'Shimla',
    'Jaipur',
    'Goa',
    'Kolkata',
    'Chennai',
    'Manali',
    'Ooty',
    'Hyderabad',
  ];

  @override
  void initState() {
    super.initState();
    final defaultOrigin = widget.currentWeather?.city.isNotEmpty == true
        ? widget.currentWeather!.city
        : 'Hyderabad';
    _originController.text = defaultOrigin;

    if (widget.initialDestination != null && widget.initialDestination!.trim().isNotEmpty) {
      _destController.text = widget.initialDestination!.trim();
      _fetchAdvisory(widget.initialDestination!.trim());
    }
  }

  @override
  void dispose() {
    _destController.dispose();
    _originController.dispose();
    super.dispose();
  }

  Future<void> _fetchAdvisory(String destination) async {
    final dest = destination.trim();
    if (dest.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _suggestions = [];
    });

    final origin = _isRouteMode && _originController.text.trim().isNotEmpty
        ? _originController.text.trim()
        : null;

    final result = await ApiService.fetchTravelAdvisory(
      destination: dest,
      origin: origin,
    );

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _advisory = result;
        _isLoading = false;
        _destController.text = result.destination;
      });
    } else {
      setState(() {
        _advisory = null;
        _isLoading = false;
        _errorMessage =
            "Could not find weather data for '$dest'. Please verify the spelling or select a valid location.";
      });
    }
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.trim().length < 2) {
      if (_suggestions.isNotEmpty) {
        setState(() => _suggestions = []);
      }
      return;
    }

    final results = await ApiService.searchLocations(query);
    if (mounted) {
      setState(() {
        _suggestions = results;
      });
    }
  }

  void _clearDestination() {
    setState(() {
      _destController.clear();
      _advisory = null;
      _errorMessage = null;
      _suggestions = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Destination Input & Route Selection Card
        _buildSearchCard(),
        const SizedBox(height: 12),

        // Quick Suggestion Chips
        _buildQuickChips(),
        const SizedBox(height: 16),

        // 2. Loading State
        if (_isLoading) _buildLoadingCard(),

        // 3. Error State
        if (_errorMessage != null && !_isLoading) _buildErrorCard(),

        // 4. Content / Result State
        if (!_isLoading && _advisory != null)
          _buildAdvisoryResult(_advisory!)
        else if (!_isLoading && _errorMessage == null)
          _buildInitialPrompt(),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSearchCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: MausamTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: MausamTheme.primaryBlue, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Select Travel Destination',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MausamTheme.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _isRouteMode = !_isRouteMode),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _isRouteMode ? 'Single City' : '+ Route Mode',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Route Mode: Origin Input Field
          if (_isRouteMode) ...[
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _originController,
                decoration: InputDecoration(
                  hintText: 'Starting location (e.g. Current Location)',
                  hintStyle: const TextStyle(fontSize: 13, color: MausamTheme.textMuted),
                  prefixIcon: const Icon(Icons.trip_origin_rounded, size: 16, color: Color(0xFF64748B)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.my_location_rounded, size: 16, color: MausamTheme.primaryBlue),
                    tooltip: 'Use current location',
                    onPressed: () {
                      final city = widget.currentWeather?.city.isNotEmpty == true
                          ? widget.currentWeather!.city
                          : 'Hyderabad';
                      _originController.text = city;
                      setState(() {});
                    },
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                style: const TextStyle(fontSize: 13, color: MausamTheme.textPrimary),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Destination Input Field
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: TextField(
              controller: _destController,
              onChanged: _onSearchChanged,
              onSubmitted: (v) => _fetchAdvisory(v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Enter destination city (e.g. Mumbai, Delhi, Shimla)...',
                hintStyle: const TextStyle(fontSize: 13, color: MausamTheme.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: MausamTheme.primaryBlue),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_destController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: MausamTheme.textMuted),
                        onPressed: _clearDestination,
                      ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_rounded, color: MausamTheme.primaryBlue),
                      onPressed: () => _fetchAdvisory(_destController.text),
                    ),
                  ],
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: MausamTheme.textPrimary),
            ),
          ),

          // Autocomplete suggestion dropdown
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: MausamTheme.cardShadow,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _suggestions.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final s = _suggestions[idx];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined, size: 18, color: MausamTheme.primaryBlue),
                    title: Text(s.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    subtitle: Text(s.displayName, style: const TextStyle(fontSize: 11, color: MausamTheme.textMuted)),
                    onTap: () {
                      _destController.text = s.name;
                      _fetchAdvisory(s.name);
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickChips() {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _quickDestinations.length,
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final city = _quickDestinations[idx];
          final isSelected = _destController.text.trim().toLowerCase() == city.toLowerCase();
          return GestureDetector(
            onTap: () {
              _destController.text = city;
              _fetchAdvisory(city);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? MausamTheme.primaryBlue : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? MausamTheme.primaryBlue : const Color(0xFFCBD5E1),
                ),
                boxShadow: isSelected ? MausamTheme.cardShadow : null,
              ),
              child: Text(
                city,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : MausamTheme.textPrimary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInitialPrompt() {
    return Column(
      children: [
        _buildScenicRoadBanner(),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: MausamTheme.cardDecoration(),
          child: Column(
            children: [
              const Icon(Icons.explore_outlined, size: 42, color: MausamTheme.primaryBlue),
              const SizedBox(height: 10),
              const Text(
                'Enter Destination to Generate Advisory',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: MausamTheme.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Check real-time highway risks, visibility, rainfall probabilities, and tailored travel precautions for any city.',
                style: TextStyle(fontSize: 12, color: MausamTheme.textSecondary, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      decoration: MausamTheme.cardDecoration(),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(color: MausamTheme.primaryBlue, strokeWidth: 3),
            const SizedBox(height: 16),
            Text(
              'Analyzing travel conditions for ${_destController.text.trim()}...',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: MausamTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Resolving coordinates and fetching live meteorological data...',
              style: TextStyle(fontSize: 11.5, color: MausamTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(MausamTheme.radiusCard),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_off_rounded, color: Color(0xFFDC2626), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Invalid Destination Location',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF991B1B)),
                ),
                const SizedBox(height: 4),
                Text(
                  _errorMessage ?? 'Location could not be resolved.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C), height: 1.35),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Try popular destinations: Delhi, Mumbai, Bengaluru, Shimla, Jaipur, Goa.',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF991B1B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvisoryResult(TravelAdvisoryModel adv) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Destination Header Bar
        _buildResolvedHeader(adv),
        const SizedBox(height: 12),

        // Hero Scenic Banner using assets/images/travel_advisory.png
        _buildScenicRoadBanner(
          destinationName: adv.destination,
          conditionText: adv.condition,
          temp: adv.temperature,
        ),
        const SizedBox(height: 16),

        // Travel Risk Banner
        _buildRiskBanner(adv),
        const SizedBox(height: 16),

        // Key Metrics Grid (2x2)
        _buildMetricsGrid(adv),
        const SizedBox(height: 16),

        // Road Surface & Highway Conditions Card
        _buildRoadConditionCard(adv),
        const SizedBox(height: 16),

        // Official Warnings / Alerts (if present or clean status)
        _buildWarningsCard(adv),
        const SizedBox(height: 16),

        // Practical Travel Safety Precautions
        _buildPrecautionsCard(adv),
        const SizedBox(height: 16),

        // Public Transport & Airport Status (Always honestly displaying Data Unavailable)
        _buildTransitStatusCard(adv),
        const SizedBox(height: 16),

        // 7-Day Destination Outlook
        _buildForecastStrip(adv.forecast),
        const SizedBox(height: 16),

        // Attribution & Timestamp Footer
        _buildAttributionFooter(adv),
      ],
    );
  }

  Widget _buildResolvedHeader(TravelAdvisoryModel adv) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.pin_drop_rounded, size: 18, color: MausamTheme.primaryBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  adv.routeSummary ?? adv.destinationResolved,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: MausamTheme.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${adv.latitude.toStringAsFixed(3)}° N, ${adv.longitude.toStringAsFixed(3)}° E',
                  style: const TextStyle(fontSize: 10.5, color: MausamTheme.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 18, color: MausamTheme.primaryBlue),
            tooltip: 'Refresh Advisory',
            onPressed: () => _fetchAdvisory(adv.destination),
          ),
        ],
      ),
    );
  }

  Widget _buildScenicRoadBanner({String? destinationName, String? conditionText, double? temp}) {
    return Container(
      height: 160,
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
              'assets/images/travel_advisory.png',
              width: double.infinity,
              height: 160,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4C1D95), Color(0xFF6D28D9)],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.directions_car_rounded, size: 48, color: Colors.white),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'DESTINATION TRAVEL ADVISORY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF5B21B6),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    destinationName != null && destinationName.isNotEmpty
                        ? destinationName
                        : 'Plan Your Journey',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (conditionText != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      temp != null ? '$conditionText • ${temp.round()}°C' : conditionText,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskBanner(TravelAdvisoryModel adv) {
    Color bg;
    Color border;
    Color iconColor;
    IconData icon;

    switch (adv.riskLevel.toLowerCase()) {
      case 'high':
        bg = const Color(0xFFFEF2F2);
        border = const Color(0xFFFECACA);
        iconColor = const Color(0xFFDC2626);
        icon = Icons.warning_rounded;
        break;
      case 'moderate':
        bg = const Color(0xFFFFFBEB);
        border = const Color(0xFFFDE68A);
        iconColor = const Color(0xFFD97706);
        icon = Icons.info_rounded;
        break;
      default:
        bg = const Color(0xFFF0FDF4);
        border = const Color(0xFFBBF7D0);
        iconColor = const Color(0xFF16A34A);
        icon = Icons.check_circle_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(MausamTheme.radiusCard),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  adv.riskTitle,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: iconColor),
                ),
                const SizedBox(height: 2),
                Text(
                  adv.riskDescription,
                  style: const TextStyle(fontSize: 12, color: MausamTheme.textPrimary, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(TravelAdvisoryModel adv) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        _buildMetricTile(
          title: 'Rainfall',
          value: '${adv.rainfallMm ?? 0} mm',
          subtitle: '${adv.rainfallProbability?.toInt() ?? 0}% probability',
          icon: Icons.umbrella_rounded,
          color: const Color(0xFF3B82F6),
        ),
        _buildMetricTile(
          title: 'Visibility',
          value: '${adv.visibilityKm} km',
          subtitle: adv.visibilityKm <= 2.0 ? 'Fog Hazard' : 'Good Visibility',
          icon: Icons.remove_red_eye_rounded,
          color: adv.visibilityKm <= 2.0 ? const Color(0xFFDC2626) : const Color(0xFF0EA5E9),
        ),
        _buildMetricTile(
          title: 'Wind Speed',
          value: '${adv.windSpeed.round()} km/h',
          subtitle: adv.windDirection,
          icon: Icons.air_rounded,
          color: const Color(0xFF6366F1),
        ),
        _buildMetricTile(
          title: 'Condition',
          value: adv.condition,
          subtitle: 'Risk: ${adv.riskLevel.toUpperCase()}',
          icon: Icons.shield_outlined,
          color: _getRiskColor(adv.riskLevel),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: MausamTheme.cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
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
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 10.5, color: MausamTheme.textMuted, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: MausamTheme.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoadConditionCard(TravelAdvisoryModel adv) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: MausamTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.directions_car_rounded, size: 18, color: MausamTheme.primaryBlue),
              SizedBox(width: 8),
              Text(
                'Road & Highway Conditions',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: MausamTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            adv.roadCondition,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.4),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.sensors_off_outlined, size: 14, color: MausamTheme.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  adv.roadDataStatus,
                  style: const TextStyle(fontSize: 11, color: MausamTheme.textMuted, height: 1.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWarningsCard(TravelAdvisoryModel adv) {
    if (adv.warnings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(MausamTheme.radiusCard),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: const [
            Icon(Icons.verified_outlined, size: 18, color: Color(0xFF16A34A)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'No active severe weather warnings for this destination.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: MausamTheme.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: adv.warnings.map((w) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(MausamTheme.radiusCard),
            border: Border.all(color: const Color(0xFFFED7AA)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFEA580C)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF9A3412))),
                    const SizedBox(height: 2),
                    Text(w.description, style: const TextStyle(fontSize: 12, color: Color(0xFF7C2D12), height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPrecautionsCard(TravelAdvisoryModel adv) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(MausamTheme.radiusCard),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.shield_outlined, size: 18, color: Color(0xFF7C3AED)),
              SizedBox(width: 8),
              Text(
                'Travel Precautions & Recommendations',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF5B21B6)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...adv.travelPrecautions.map((p) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                  Expanded(
                    child: Text(
                      p,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.35),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTransitStatusCard(TravelAdvisoryModel adv) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: MausamTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.commute_rounded, size: 18, color: MausamTheme.primaryBlue),
              SizedBox(width: 8),
              Text(
                'Transit & Infrastructure Status',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: MausamTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTransitRow(Icons.directions_bus_outlined, 'Public Transport', adv.publicTransportStatus),
          const SizedBox(height: 8),
          _buildTransitRow(Icons.flight_outlined, 'Airport Status', adv.airportStatus),
          const SizedBox(height: 8),
          _buildTransitRow(Icons.train_outlined, 'Metro Status', 'Data unavailable'),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.info_outline_rounded, size: 14, color: MausamTheme.textMuted),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Mausam does not fabricate transit disruptions or flight schedules. Live feeds will appear here once official transport APIs are connected.',
                  style: TextStyle(fontSize: 11, color: MausamTheme.textMuted, height: 1.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransitRow(IconData icon, String label, String status) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 12, color: MausamTheme.textSecondary)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            status,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
          ),
        ),
      ],
    );
  }

  Widget _buildForecastStrip(List<TravelForecastDayModel> forecast) {
    if (forecast.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '7-Day Destination Outlook',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: MausamTheme.textPrimary),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: forecast.length,
            separatorBuilder: (_, index) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final d = forecast[idx];
              return Container(
                width: 74,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                decoration: MausamTheme.cardDecoration(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(d.dayName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: MausamTheme.textSecondary)),
                    const SizedBox(height: 4),
                    Icon(_getConditionIcon(d.condition), size: 20, color: const Color(0xFFF59E0B)),
                    const SizedBox(height: 4),
                    Text(
                      '${d.maxTempC.round()}° / ${d.minTempC.round()}°',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: MausamTheme.textPrimary),
                    ),
                    if (d.rainProbability != null && d.rainProbability! > 0)
                      Text(
                        '${d.rainProbability!.toInt()}%',
                        style: const TextStyle(fontSize: 9.5, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAttributionFooter(TravelAdvisoryModel adv) {
    return Center(
      child: Text(
        'Source: ${adv.source}',
        style: const TextStyle(fontSize: 11, color: MausamTheme.textMuted),
        textAlign: TextAlign.center,
      ),
    );
  }

  Color _getRiskColor(String level) {
    switch (level.toLowerCase()) {
      case 'high':
        return const Color(0xFFDC2626);
      case 'moderate':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF16A34A);
    }
  }

  IconData _getConditionIcon(String cond) {
    final c = cond.toLowerCase();
    if (c.contains('thunder')) return Icons.bolt_rounded;
    if (c.contains('rain') || c.contains('drizzle')) return Icons.umbrella_rounded;
    if (c.contains('snow')) return Icons.ac_unit_rounded;
    if (c.contains('fog') || c.contains('mist')) return Icons.cloud_outlined;
    if (c.contains('cloud')) return Icons.wb_cloudy_rounded;
    return Icons.wb_sunny_rounded;
  }
}
