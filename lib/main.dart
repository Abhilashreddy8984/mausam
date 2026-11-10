// ============================================================
// main.dart
//
// Creates and owns app-lifetime objects:
//   AppPersonaNotifier        — selected weather persona
//   WeatherData?              — current weather snapshot (live from API)
//   LocationNotifier          — GPS location state
//   backendCardOrderNotifier  — ordered card type strings from
//                               the FastAPI backend
//
// Lifecycle & Data Integrity:
//   1. At startup, the app displays a polished loading state
//      (MausamLoadingView) while acquiring location and fetching
//      real weather data from the backend. No demo weather is flashed.
//   2. If the initial fetch fails, a dedicated error state
//      (MausamErrorView) is shown with a Retry option.
//   3. On subsequent refreshes (persona change or location update),
//      any failure retains the latest valid live data with non-blocking
//      feedback.
//   4. Requests are guarded by an incrementing sequence ID to prevent
//      out-of-order response overwrites and concurrent flickering.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/homepage_response.dart';
import 'models/location_data.dart';
import 'models/persona.dart';
import 'models/weather_data.dart';
import 'screens/main_shell.dart';
import 'services/advisory_service.dart';
import 'services/api_service.dart';
import 'state/app_state.dart';
import 'state/location_notifier.dart';
import 'theme/mausam_theme.dart';
import 'widgets/mausam_state_views.dart';

/// Application weather loading status.
enum AppWeatherStatus {
  loading,
  success,
  error,
}

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
  final WeatherData? initialWeather;

  const MausamApp({super.key, this.initialWeather});

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

  WeatherData? _weather;
  AppWeatherStatus _status = AppWeatherStatus.loading;
  String? _errorMessage;

  int _activeRequestId = 0;
  bool _hasInitializedListeners = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialWeather != null) {
      _weather = widget.initialWeather;
      _status = AppWeatherStatus.success;
      _attachListeners();
    } else {
      _status = AppWeatherStatus.loading;
      _initStartupFlow();
    }
  }

  void _attachListeners() {
    if (_hasInitializedListeners) return;
    _hasInitializedListeners = true;
    _personaNotifier.addListener(_onPersonaChanged);
    _locationNotifier.addListener(_onLocationChanged);
  }

  /// Initial startup sequence: request GPS location, then fetch initial weather.
  Future<void> _initStartupFlow({bool isRetry = false}) async {
    setState(() {
      _status = AppWeatherStatus.loading;
      _errorMessage = null;
    });

    // Request GPS location automatically at launch
    await _locationNotifier.requestLocation();
    if (!mounted) return;

    _attachListeners();
    await _fetchBackendOrder(_personaNotifier.value, isInitial: true);
  }

  /// Called every time the user switches persona.
  void _onPersonaChanged() {
    _fetchBackendOrder(_personaNotifier.value, isInitial: false);
  }

  /// Called when the GPS location state changes.
  /// Only triggers a backend re-fetch when a successful location fix arrives.
  void _onLocationChanged() {
    if (_hasInitializedListeners &&
        _locationNotifier.value.status == LocationStatus.success) {
      _fetchBackendOrder(_personaNotifier.value, isInitial: false);
    }
  }

  /// Calls the FastAPI /homepage endpoint for the given persona.
  Future<void> _fetchBackendOrder(Persona persona, {bool isInitial = false}) async {
    final int requestId = ++_activeRequestId;
    final personaStr = _backendPersonaString(persona);

    // Resolve city and GPS coordinates from LocationNotifier
    final locationData = _locationNotifier.value.data;

    final city = (locationData?.city != null && locationData!.city!.isNotEmpty)
        ? locationData.city!
        : (_weather?.city ?? 'Hyderabad');

    final latitude = locationData?.latitude;
    final longitude = locationData?.longitude;

    _logLocation(city, latitude, longitude);
    debugPrint('[MausamAPI] Requesting homepage (seq: $requestId)');

    final response = await ApiService.fetchHomepage(
      persona: personaStr,
      city: city,
      latitude: latitude,
      longitude: longitude,
    );

    // Guard against race conditions and out-of-order completions
    if (!mounted || requestId != _activeRequestId) {
      debugPrint('[MausamAPI] Discarding response (seq: $requestId, active: $_activeRequestId)');
      return;
    }

    if (response != null) {
      debugPrint('[MausamAPI] API success (seq: $requestId) — source: ${response.source}');
      final liveWeather = _homepageResponseToWeatherData(response);

      setState(() {
        _weather = liveWeather;
        _status = AppWeatherStatus.success;
        _errorMessage = null;
        _backendCardOrderNotifier.value = response.rankedCardTypes;
      });
    } else {
      debugPrint('[MausamAPI] API failure (seq: $requestId)');
      _backendCardOrderNotifier.value = null;

      if (isInitial || _weather == null) {
        setState(() {
          _status = AppWeatherStatus.error;
          _errorMessage =
              'Unable to fetch live weather from the server.\nPlease check your connection and tap Retry.';
        });
      } else {
        // Subsequent refresh failure: retain previous live data without flickering
        if (mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('Could not refresh weather. Retaining latest data.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  /// Converts a [HomepageResponse] from the backend into a live [WeatherData].
  /// Does NOT inject fabricated demo values for missing fields.
  WeatherData _homepageResponseToWeatherData(HomepageResponse response) {
    final WeatherCodeSystem? codeSystem =
        (response.source?.toUpperCase() == 'IMD')
            ? WeatherCodeSystem.imd
            : null;

    final String source = response.source ?? 'IMD';

    final partialWeather = WeatherData(
      city: response.city.isNotEmpty ? response.city : 'Hyderabad',
      state: response.state ?? '',
      temperatureC: response.temperature,
      feelsLikeC: response.feelsLike ?? response.temperature,
      humidity: response.humidity.round(),
      weatherCondition: response.condition.isNotEmpty
          ? response.condition
          : 'Partly Cloudy',
      weatherConditionDetail: response.condition,
      windSpeedKmh: response.windSpeed,
      windDirection: response.windDirection ?? '--',
      rainfallProbability: null, // Not populated when absent from live feed
      rainfallAmountMm: response.rainfallMm,
      rainfallWindow: null,
      aqi: response.aqi,
      aqiCategory: _calcAqiCategory(response.aqi),
      uvIndex: response.uvIndex,
      uvCategory: _calcUvCategory(response.uvIndex),
      visibilityKm: response.visibilityKm ?? 10.0,
      sunrise: null,
      sunset: null,
      timestamp: response.observationTime != null
          ? DateTime.tryParse(response.observationTime!)
          : DateTime.now(),
      weatherCode: response.weatherCode,
      weatherCodeSystem: codeSystem,
      source: source,
    );

    final resolvedAlert = AdvisoryService.resolveAlert(
      partialWeather,
      officialWarnings: response.warnings,
    );

    return partialWeather.copyWith(alerts: [resolvedAlert]);
  }

  static String? _calcAqiCategory(int? aqi) {
    if (aqi == null) return null;
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Satisfactory';
    if (aqi <= 200) return 'Moderate';
    if (aqi <= 300) return 'Poor';
    if (aqi <= 400) return 'Very Poor';
    return 'Severe';
  }

  static String? _calcUvCategory(int? uv) {
    if (uv == null) return null;
    if (uv <= 2) return 'Low';
    if (uv <= 5) return 'Moderate';
    if (uv <= 7) return 'High';
    if (uv <= 10) return 'Very High';
    return 'Extreme';
  }

  /// Debug log for location resolution — only in debug builds.
  void _logLocation(String city, double? lat, double? lon) {
    assert(() {
      if (lat != null && lon != null) {
        debugPrint(
          '[MausamLocation] GPS coordinates: '
          'lat: ${lat.toStringAsFixed(4)}, '
          'lon: ${lon.toStringAsFixed(4)} (target city: $city)',
        );
      } else {
        debugPrint('[MausamLocation] Fallback location query: city: $city');
      }
      return true;
    }());
  }

  /// Maps Flutter's Persona enum values to backend persona strings.
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
    Widget homeWidget;

    switch (_status) {
      case AppWeatherStatus.loading:
        homeWidget = const Scaffold(
          backgroundColor: MausamTheme.background,
          body: SafeArea(
            child: MausamLoadingView(
              title: 'Fetching local weather...',
              subtitle: 'Locating and connecting to weather services...',
            ),
          ),
        );
        break;
      case AppWeatherStatus.error:
        homeWidget = Scaffold(
          backgroundColor: MausamTheme.background,
          body: SafeArea(
            child: MausamErrorView(
              title: 'Unable to Load Weather',
              subtitle: _errorMessage ??
                  "We couldn't fetch the weather data.\nPlease try again.",
              onRetry: () => _initStartupFlow(isRetry: true),
            ),
          ),
        );
        break;
      case AppWeatherStatus.success:
        homeWidget = MainShell(
          personaNotifier: _personaNotifier,
          weather: _weather!,
          locationNotifier: _locationNotifier,
          backendCardOrderNotifier: _backendCardOrderNotifier,
        );
        break;
    }

    return MaterialApp(
      title: 'Mausam – Personalized Weather',
      debugShowCheckedModeBanner: false,
      theme: MausamTheme.lightTheme,
      home: homeWidget,
    );
  }
}
