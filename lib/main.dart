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
import 'models/location_data.dart';
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

    // ── Re-fetch when GPS location is resolved ────────────────
    // This ensures that if the user grants location permission after
    // app start, the next ranking request uses the real detected city
    // and coordinates instead of the demo fallback.
    _locationNotifier.addListener(_onLocationChanged);
  }

  /// Called every time the user switches persona.
  void _onPersonaChanged() {
    _fetchBackendOrder(_personaNotifier.value);
  }

  /// Called when the GPS location state changes.
  /// Only triggers a backend re-fetch when a successful location fix
  /// arrives — avoids redundant calls during loading or error states.
  void _onLocationChanged() {
    if (_locationNotifier.value.status == LocationStatus.success) {
      _fetchBackendOrder(_personaNotifier.value);
    }
  }

  /// Calls the FastAPI /homepage endpoint for the given persona.
  ///
  /// Location resolution priority:
  ///   1. GPS city from LocationNotifier (if permission granted + fix obtained)
  ///   2. Fallback: demo weather city ("Hyderabad")
  ///
  /// GPS coordinates (latitude + longitude) are passed to the backend
  /// when available so they reach RankingContext for future use by
  /// coordinate-aware weather providers (e.g. IMD).
  ///
  /// On success  → updates [_backendCardOrderNotifier] with the
  ///               ranked list of card type strings.
  /// On failure  → sets [_backendCardOrderNotifier] to null so
  ///               HomeScreen falls back to local ordering.
  Future<void> _fetchBackendOrder(Persona persona) async {
    final personaStr = _backendPersonaString(persona);

    // ── Resolve city and GPS coordinates from LocationNotifier ──
    // locationData is non-null only when GPS permission was granted
    // AND a successful fix was obtained.
    final locationData = _locationNotifier.value.data;

    // Use GPS-detected city when available; fall back to demo city.
    // LocationData.city may itself be null if reverse-geocoding failed —
    // fall back to demo city in that case too.
    final city = (locationData?.city != null && locationData!.city!.isNotEmpty)
        ? locationData.city!
        : _weather.city; // "Hyderabad" from DemoWeatherProvider

    // GPS coordinates — only sent when both are available
    final latitude = locationData?.latitude;
    final longitude = locationData?.longitude;

    _logLocation(city, latitude, longitude);

    final response = await ApiService.fetchHomepage(
      persona: personaStr,
      city: city,
      latitude: latitude,
      longitude: longitude,
    );

    if (response != null) {
      _backendCardOrderNotifier.value = response.rankedCardTypes;
    } else {
      // Backend unavailable — clear so HomeScreen uses local ordering.
      _backendCardOrderNotifier.value = null;
    }
  }

  /// Debug log for location resolution — only in debug builds.
  void _logLocation(String city, double? lat, double? lon) {
    assert(() {
      if (lat != null && lon != null) {
        debugPrint(
          '[MausamLocation] GPS city: $city '
          'lat: ${lat.toStringAsFixed(4)} '
          'lon: ${lon.toStringAsFixed(4)}',
        );
      } else {
        debugPrint('[MausamLocation] No GPS fix — using fallback city: $city');
      }
      return true;
    }());
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
    _locationNotifier.removeListener(_onLocationChanged);
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
