import 'package:flutter/material.dart';
import '../models/weather_data.dart';
import '../state/app_state.dart';
import '../state/location_notifier.dart';
import '../theme/mausam_theme.dart';
import 'advisories_screen.dart';
import 'aqi_uv_screen.dart';
import 'explore_screen.dart';
import 'forecast_screen.dart';
import 'home_screen.dart';

class MainShell extends StatefulWidget {
  final AppPersonaNotifier personaNotifier;
  final WeatherData weather;
  final LocationNotifier locationNotifier;
  final ValueNotifier<List<String>?> backendCardOrderNotifier;

  const MainShell({
    super.key,
    required this.personaNotifier,
    required this.weather,
    required this.locationNotifier,
    required this.backendCardOrderNotifier,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        personaNotifier: widget.personaNotifier,
        weather: widget.weather,
        locationNotifier: widget.locationNotifier,
        backendCardOrderNotifier: widget.backendCardOrderNotifier,
      ),
      AqiUvScreen(weather: widget.weather),
      AdvisoriesScreen(weather: widget.weather),
      ForecastScreen(weather: widget.weather),
      ExploreScreen(
        personaNotifier: widget.personaNotifier,
        weather: widget.weather,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          indicatorColor: MausamTheme.primaryBlue.withValues(alpha: 0.12),
          elevation: 0,
          height: 65,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: MausamTheme.primaryBlue),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.eco_outlined),
              selectedIcon: Icon(Icons.eco, color: MausamTheme.primaryBlue),
              label: 'AQI & UV',
            ),
            NavigationDestination(
              icon: Icon(Icons.shield_outlined),
              selectedIcon: Icon(Icons.shield, color: MausamTheme.primaryBlue),
              label: 'Advisories',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month, color: MausamTheme.primaryBlue),
              label: 'Forecast',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz_rounded),
              selectedIcon: Icon(Icons.more_horiz_rounded, color: MausamTheme.primaryBlue),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}
