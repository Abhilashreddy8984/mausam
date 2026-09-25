// ============================================================
// main.dart
//
// Creates and owns three app-lifetime objects:
//   AppPersonaNotifier  — selected weather persona
//   WeatherData         — current weather snapshot (demo)
//   LocationNotifier    — GPS location state
//
// All three are passed explicitly into MainShell so every
// screen that needs them receives them without InheritedWidget
// lookup issues across navigator boundaries.
//
// ┌─────────────────────────────────────────────────────────┐
// │  FUTURE API INTEGRATION POINT                           │
// │                                                         │
// │  Step 1 — location already wired:                       │
// │    locationNotifier.value.data contains lat/lon once    │
// │    the user grants permission.                          │
// │                                                         │
// │  Step 2 — pass coordinates to WeatherService:           │
// │    final loc = locationNotifier.value.data;             │
// │    if (loc != null) {                                   │
// │      _weather = await WeatherService()                  │
// │          .fetchWeather(loc.latitude, loc.longitude);    │
// │      setState(() {});   // or use a ValueNotifier       │
// │    }                                                    │
// │                                                         │
// │  Step 3 — listen for location changes to auto-refresh:  │
// │    locationNotifier.addListener(_onLocationChanged);    │
// └─────────────────────────────────────────────────────────┘
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/demo_weather_provider.dart';
import 'models/weather_data.dart';
import 'screens/main_shell.dart';
import 'state/app_state.dart';
import 'state/location_notifier.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const MausamApp());
}

class MausamApp extends StatefulWidget {
  const MausamApp({super.key});

  @override
  State<MausamApp> createState() => _MausamAppState();
}

class _MausamAppState extends State<MausamApp> {
  final AppPersonaNotifier _personaNotifier = AppPersonaNotifier();
  final LocationNotifier _locationNotifier = LocationNotifier();
  late final WeatherData _weather;

  @override
  void initState() {
    super.initState();
    // ── FUTURE API INTEGRATION POINT ──────────────────────
    // Replace with a real WeatherService call that accepts
    // lat/lon from _locationNotifier.value.data once resolved.
    _weather = DemoWeatherProvider.getWeather();
  }

  @override
  void dispose() {
    _personaNotifier.dispose();
    _locationNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mausam – Personalized Weather',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: EdgeInsets.zero,
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
          titleMedium: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          bodyMedium: TextStyle(fontSize: 14),
          bodySmall: TextStyle(fontSize: 12),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: MainShell(
        personaNotifier: _personaNotifier,
        weather: _weather,
        locationNotifier: _locationNotifier,
      ),
    );
  }
}
