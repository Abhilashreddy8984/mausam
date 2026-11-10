import 'package:flutter/material.dart';

import '../models/weather_data.dart';
import '../theme/mausam_theme.dart';
import '../widgets/farmer_advisory_content.dart';
import '../widgets/travel_advisory_content.dart';

class AdvisoriesScreen extends StatefulWidget {
  final WeatherData weather;
  final int initialTab; // 0 for Travel, 1 for Farmer

  const AdvisoriesScreen({
    super.key,
    required this.weather,
    this.initialTab = 0,
  });

  @override
  State<AdvisoriesScreen> createState() => _AdvisoriesScreenState();
}

class _AdvisoriesScreenState extends State<AdvisoriesScreen> {
  late int _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MausamTheme.background,
      appBar: AppBar(
        title: Text(_selectedTab == 0 ? 'Travel Advisory' : 'Farmer Advisory'),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: Column(
        children: [
          // Segmented tab toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSegmentButton(
                      title: 'Travel Advisory',
                      icon: Icons.flight_takeoff_rounded,
                      isActive: _selectedTab == 0,
                      onTap: () => setState(() => _selectedTab = 0),
                    ),
                  ),
                  Expanded(
                    child: _buildSegmentButton(
                      title: 'Farmer Advisory',
                      icon: Icons.grass_rounded,
                      isActive: _selectedTab == 1,
                      onTap: () => setState(() => _selectedTab = 1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: _selectedTab == 0
                  ? _buildTravelAdvisory(widget.weather)
                  : _buildFarmerAdvisory(widget.weather),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String title,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isActive ? MausamTheme.cardShadow : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? MausamTheme.primaryBlue : MausamTheme.textMuted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? MausamTheme.textPrimary : MausamTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Screen 3: TRAVEL ADVISORY ──────────────────────────────
  Widget _buildTravelAdvisory(WeatherData weather) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: TravelAdvisoryContent(currentWeather: weather),
    );
  }

  // ── Screen 4: FARMER ADVISORY ──────────────────────────────
  Widget _buildFarmerAdvisory(WeatherData weather) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: FarmerAdvisoryContent(weather: weather),
    );
  }
}
