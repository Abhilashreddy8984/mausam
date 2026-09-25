// ============================================================
// screens/main_shell.dart
// Bottom-nav shell. Receives AppPersonaNotifier, WeatherData,
// and LocationNotifier from main.dart and threads them into
// the screens that need them.
// ============================================================

import 'package:flutter/material.dart';

import '../models/weather_data.dart';
import '../state/app_state.dart';
import '../state/location_notifier.dart';
import 'home_screen.dart';
import 'explore_screen.dart';
import 'alerts_screen.dart';

class MainShell extends StatefulWidget {
  final AppPersonaNotifier personaNotifier;
  final WeatherData weather;
  final LocationNotifier locationNotifier;

  const MainShell({
    super.key,
    required this.personaNotifier,
    required this.weather,
    required this.locationNotifier,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    // LocationNotifier is only needed by HomeScreen for the
    // location bar — Explore and Alerts don't use it.
    final pages = [
      HomeScreen(
        personaNotifier: widget.personaNotifier,
        weather: widget.weather,
        locationNotifier: widget.locationNotifier,
      ),
      ExploreScreen(
        personaNotifier: widget.personaNotifier,
        weather: widget.weather,
      ),
      const AlertsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
  selectedIndex: _currentIndex,
  onDestinationSelected: (i) => setState(() => _currentIndex = i),
  backgroundColor: Colors.white,
  surfaceTintColor: Colors.transparent,
  indicatorColor: primary.withValues(alpha: 0.12),
  elevation: 0,
  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
  destinations: const [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.explore_outlined),
      selectedIcon: Icon(Icons.explore),
      label: 'Explore',
    ),
    NavigationDestination(
      icon: Icon(Icons.notifications_outlined),
      selectedIcon: Icon(Icons.notifications),
      label: 'Alerts',
    ),
  ],
),
    );
  }
}
