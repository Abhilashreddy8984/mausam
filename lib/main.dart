// ============================================================
// main.dart
//
// Creates and owns four app-lifetime objects:
//   AppPersonaNotifier        — selected weather persona
//   WeatherData               — current weather snapshot (demo)
//   LocationNotifier          — GPS location state
//   backendCardOrderNotifier  — ordered card type strings from
//                               the FastAPI backend (null = not
//                               yet fetched or backend unavailable)
//
// Backend integration:
//   When the app starts, or when the persona changes, this widget
//   calls ApiService.fetchHomepage() and stores the ranked card
//   type list in backendCardOrderNotifier.
//
//   HomeScreen reads backendCardOrderNotifier to reorder its
//   card catalogue. If the backend is unavailable it falls back
//   to the local persona.cardPriority ordering transparently.
//
// ┌─────────────────────────────────────────────────────────┐
// │  FUTURE API INTEGRATION POINT (weather data)            │
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
import 'models/persona.dart';
import 'models/weather_data.dart';
import 'screens/main_shell.dart';
import 'services/api_service.dart';
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

  /// Ranked card type strings from the FastAPI backend.
  /// null  = backend not yet contacted, or last fetch failed.
  /// HomeScreen treats null as "use local fallback ordering".
  final ValueNotifier<List<String>?> _backendCardOrderNotifier =
      ValueNotifier<List<String>?>(null);

  late final WeatherData _weather;

  @override
  void initState() {
    super.initState();
    // ── Demo weather data (replaced by real API in a later step) ──
    _weather = DemoWeatherProvider.getWeather();

    // ── Initial backend fetch with the default persona ────────
    _fetchBackendOrder(_personaNotifier.value);

    // ── Re-fetch whenever the user changes their persona ──────
    _personaNotifier.addListener(_onPersonaChanged);
  }

  /// Called every time the user switches persona.
  void _onPersonaChanged() {
    _fetchBackendOrder(_personaNotifier.value);
  }

  /// Calls the FastAPI /homepage endpoint for the given persona
  /// using the current weather city as the city parameter.
  ///
  /// On success  → updates [_backendCardOrderNotifier] with the
  ///               ranked list of card type strings.
  /// On failure  → sets [_backendCardOrderNotifier] to null so
  ///               HomeScreen falls back to local ordering.
  Future<void> _fetchBackendOrder(Persona persona) async {
    // Map Flutter Persona enum → backend persona string.
    final personaStr = _backendPersonaString(persona);

    // Use the city from the current WeatherData snapshot.
    // Once real GPS → weather is wired, this will use the
    // detected city from locationNotifier automatically.
    final city = _weather.city;

    final response = await ApiService.fetchHomepage(
      persona: personaStr,
      city: city,
    );

    if (response != null) {
      _backendCardOrderNotifier.value = response.rankedCardTypes;
    } else {
      // Backend unavailable — clear so HomeScreen uses local ordering.
      _backendCardOrderNotifier.value = null;
    }
  }

  /// Maps Flutter's Persona enum values to the backend persona strings.
  ///
  /// The backend supports: farmer, student, traveller, health,
  /// commuter, outdoor_worker, senior, event_planner.
  static String _backendPersonaString(Persona persona) {
    switch (persona) {
      case Persona.farmer:
        return 'farmer';
      case Persona.student:
        return 'student';
      case Persona.traveller:
        return 'traveller';
      case Persona.healthFitness:
        return 'health';
      case Persona.commuter:
        return 'commuter';
      case Persona.outdoorWorker:
        return 'outdoor_worker';
      case Persona.seniorCitizen:
        return 'senior';
      case Persona.eventPlanner:
        return 'event_planner';
    }
  }

  @override
  void dispose() {
    _personaNotifier.removeListener(_onPersonaChanged);
    _personaNotifier.dispose();
    _locationNotifier.dispose();
    _backendCardOrderNotifier.dispose();
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
        backendCardOrderNotifier: _backendCardOrderNotifier,
      ),
    );
  }
}
