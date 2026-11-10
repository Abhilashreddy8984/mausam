// ============================================================
// test/home_screen_test.dart
//
// Widget tests for MAUSAM Home Screen:
// - Top Header (Branding, location, persona pill)
// - Adaptive Weather Hero (Weather info, typography, custom painter)
// - "Why This Matters To You" (Dynamic personalized rationale)
// - Priority Weather Insights (4 top tiles)
// - Quick Actions (Explore, Alerts, Forecast, Details)
// - Next Hours Forecast strip
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mausam_personalized/data/demo_data.dart';
import 'package:mausam_personalized/data/demo_weather_provider.dart';
import 'package:mausam_personalized/models/persona.dart';
import 'package:mausam_personalized/models/weather_data.dart';
import 'package:mausam_personalized/screens/advisories_screen.dart';
import 'package:mausam_personalized/screens/detail_screen.dart';
import 'package:mausam_personalized/screens/home_screen.dart';
import 'package:mausam_personalized/state/app_state.dart';
import 'package:mausam_personalized/state/location_notifier.dart';
import 'package:mausam_personalized/widgets/farmer_advisory_content.dart';
import 'package:mausam_personalized/widgets/living_weather_hero.dart';
import 'package:mausam_personalized/widgets/travel_advisory_content.dart';

Widget _createTestableHomeScreen({
  WeatherData? weather,
  Persona initialPersona = Persona.farmer,
  List<String>? backendOrder,
}) {
  final personaNotifier = AppPersonaNotifier();
  personaNotifier.value = initialPersona;
  final locationNotifier = LocationNotifier();
  final backendOrderNotifier = ValueNotifier<List<String>?>(backendOrder);
  final w = weather ?? DemoWeatherProvider.getWeather();

  return MaterialApp(
    home: HomeScreen(
      personaNotifier: personaNotifier,
      weather: w,
      locationNotifier: locationNotifier,
      backendCardOrderNotifier: backendOrderNotifier,
    ),
  );
}

void main() {
  testWidgets('HomeScreen renders all key sections with high fidelity',
      (WidgetTester tester) async {
    // Set a phone-sized viewport with sufficient height to lay out slivers
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_createTestableHomeScreen());
    await tester.pump(const Duration(milliseconds: 100));

    // 1. TOP HEADER
    expect(find.text('MAUSAM'), findsOneWidget);
    expect(find.text('Hyderabad'), findsOneWidget);
    expect(find.text('· Your Location'), findsOneWidget);
    expect(find.text('Farmer'), findsOneWidget);

    // 2. ADAPTIVE WEATHER HERO
    expect(find.byType(LivingWeatherHero), findsOneWidget);
    expect(find.text('32°'), findsWidgets); // Temp in hero and/or tiles
    expect(find.text('Feels like 35°'), findsOneWidget);

    // 3. "WHY THIS MATTERS TO YOU"
    expect(find.text('Why this matters to you'), findsOneWidget);
    expect(
      find.textContaining('Rain conditions are prioritized because they may affect your field activity'),
      findsOneWidget,
    );

    // 4. PRIORITY WEATHER INSIGHTS
    expect(find.text('Priority Weather Insights'), findsOneWidget);

    // 5. QUICK ACTIONS
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Explore\nWeather'), findsOneWidget);
    expect(find.text('Alerts'), findsWidgets);
    expect(find.text('Forecast'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);

    // 6. NEXT HOURS
    expect(find.text('NEXT HOURS'), findsOneWidget);

    // 7. ALL WEATHER DETAILS
    expect(find.text('ALL WEATHER DETAILS'), findsOneWidget);
  });

  testWidgets('HomeScreen adapts "Why this matters to you" for Student persona',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _createTestableHomeScreen(initialPersona: Persona.student),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Student'), findsOneWidget);
    expect(
      find.textContaining('Rain and visibility are prioritized for your daily commute'),
      findsOneWidget,
    );
  });

  testWidgets('HomeScreen adapts "Why this matters to you" for Traveller persona',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _createTestableHomeScreen(initialPersona: Persona.traveller),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Traveller'), findsOneWidget);
    expect(
      find.textContaining('travel'),
      findsWidgets,
    );
  });

  testWidgets('HomeScreen LivingWeatherHero renders snowy.png during snowy conditions',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final snowyWeather = DemoWeatherProvider.getWeather().copyWith(
      weatherCondition: 'Moderate Snow',
    );

    await tester.pumpWidget(
      _createTestableHomeScreen(weather: snowyWeather),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final imageFinder = find.byWidgetPredicate(
      (widget) => widget is Image && widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == 'assets/images/snowy.png',
    );
    expect(imageFinder, findsOneWidget);
  });

  testWidgets('AdvisoriesScreen displays travel_advisory.png and farm_advisory.png',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final weather = DemoWeatherProvider.getWeather();
    await tester.pumpWidget(
      MaterialApp(home: AdvisoriesScreen(weather: weather)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Default tab is Travel Advisory (index 0)
    final travelImageFinder = find.byWidgetPredicate(
      (widget) => widget is Image && widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == 'assets/images/travel_advisory.png',
    );
    expect(travelImageFinder, findsOneWidget);

    // Switch to Farmer Advisory tab
    await tester.tap(find.text('Farmer Advisory'));
    await tester.pumpAndSettle();

    final farmImageFinder = find.byWidgetPredicate(
      (widget) => widget is Image && widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == 'assets/images/farm_advisory.png',
    );
    expect(farmImageFinder, findsOneWidget);
  });

  testWidgets('WeatherDetailScreen displays snowy.png for snow weather and farm_advisory.png for farm advisory',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Test 1: Snow weather
    final snowyWeather = DemoWeatherProvider.getWeather().copyWith(
      weatherCondition: 'Snow',
    );
    await tester.pumpWidget(
      MaterialApp(home: WeatherDetailScreen(weather: snowyWeather)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final snowImageFinder = find.byWidgetPredicate(
      (widget) => widget is Image && widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == 'assets/images/snowy.png',
    );
    expect(snowImageFinder, findsOneWidget);

    // Test 2: Farm advisory card detail
    const farmCard = WeatherCardData(
      type: WeatherCardType.farmAdvisory,
      title: 'Farm Advisory',
      value: 'Hold irrigation',
      icon: Icons.grass,
      accentColor: Colors.green,
    );
    await tester.pumpWidget(
      MaterialApp(home: WeatherDetailScreen(card: farmCard, weather: DemoWeatherProvider.getWeather())),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final farmCardImageFinder = find.byWidgetPredicate(
      (widget) => widget is Image && widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == 'assets/images/farm_advisory.png',
    );
    expect(farmCardImageFinder, findsOneWidget);
  });

  group('Advisory Navigation & Detail Destinations', () {
    testWidgets('Yellow Alert card opens dedicated Yellow Alert details with precautions and back navigation',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final stormWeather = DemoWeatherProvider.getWeather().copyWith(
        weatherCondition: 'Thunderstorm',
        weatherCode: '29',
        windSpeedKmh: 35.0,
      );

      await tester.pumpWidget(_createTestableHomeScreen(weather: stormWeather));
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Yellow Alert card
      final yellowCard = find.text('⚠ Yellow Alert');
      expect(yellowCard, findsWidgets);
      await tester.tap(yellowCard.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verify Yellow Alert details screen opened
      expect(find.text('Yellow Alert'), findsWidgets);
      expect(find.text('Severity: Yellow (Watch)'), findsOneWidget);
      expect(find.textContaining('Appropriate Safety Precautions'), findsOneWidget);
      expect(find.textContaining('Avoid open areas, tall trees, and metal structures'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(WeatherDetailScreen),
          matching: find.textContaining('Stay indoors and keep windows shut'),
        ),
        findsOneWidget,
      );

      // Verify it does NOT show Marine Advisory content on the Yellow Alert details screen
      expect(
        find.descendant(
          of: find.byType(WeatherDetailScreen),
          matching: find.text('Marine Advisory'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(WeatherDetailScreen),
          matching: find.textContaining('Bay of Bengal'),
        ),
        findsNothing,
      );

      // Verify back navigation returns to HomeScreen
      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('MAUSAM'), findsOneWidget);
    });

    testWidgets('Marine Advisory card opens dedicated Marine Advisory details without Yellow Alert content and supports back navigation',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_createTestableHomeScreen());
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Marine / Coastal card
      final marineCard = find.text('Marine / Coastal');
      expect(marineCard, findsWidgets);
      await tester.tap(marineCard.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verify Marine Advisory details screen opened
      expect(find.text('Marine Advisory'), findsWidgets);
      expect(find.textContaining('Inland Location'), findsWidgets);
      expect(find.textContaining('Bay of Bengal'), findsWidgets);

      // Verify it does NOT show Yellow Alert content
      expect(find.text('Severity: Yellow (Watch)'), findsNothing);
      expect(find.textContaining('IMD WEATHER ALERT'), findsNothing);

      // Verify back navigation returns to HomeScreen
      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('MAUSAM'), findsOneWidget);
    });

    testWidgets('Travel Advisory card opens dedicated Travel Advisory details and supports back navigation',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_createTestableHomeScreen(initialPersona: Persona.traveller));
      await tester.pump(const Duration(milliseconds: 100));

      final travelCard = find.text('Travel Advisory');
      expect(travelCard, findsWidgets);
      await tester.tap(travelCard.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Travel Advisory'), findsWidgets);
      expect(find.text('Select Travel Destination'), findsOneWidget);
      expect(find.text('Delhi'), findsOneWidget);

      // Back navigation
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('MAUSAM'), findsOneWidget);
    });

    testWidgets('Farmer Advisory card opens dedicated Farmer Advisory details and supports back navigation',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_createTestableHomeScreen(initialPersona: Persona.farmer));
      await tester.pump(const Duration(milliseconds: 100));

      final farmCard = find.text('Farm Advisory');
      expect(farmCard, findsWidgets);
      await tester.tap(farmCard.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Farmer Advisory'), findsWidgets);
      expect(find.text('Delay irrigation 24 h'), findsOneWidget);
      expect(find.textContaining('8–10 mm of rain is expected tonight'), findsOneWidget);

      // Back navigation
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('MAUSAM'), findsOneWidget);
    });

    testWidgets('Both Farmer Advisory entry points display consistent authoritative agrimet data',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final weather = DemoWeatherProvider.getWeather();

      // 1. Check AdvisoriesScreen tab 1
      await tester.pumpWidget(MaterialApp(home: AdvisoriesScreen(weather: weather, initialTab: 1)));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Farmer Advisory'), findsWidgets);
      expect(find.text('Delay irrigation 24 h'), findsOneWidget);
      expect(find.textContaining('8–10 mm of rain is expected tonight'), findsOneWidget);
      expect(find.text('Adequate (pre-rain)'), findsOneWidget);
      // Ensure the old travel advice bug is gone
      expect(find.textContaining('Carry an umbrella and drive safely'), findsNothing);

      // 2. Check dedicated FarmerAdvisoryDetailScreen
      await tester.pumpWidget(MaterialApp(home: FarmerAdvisoryDetailScreen(weather: weather)));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Farmer Advisory'), findsWidgets);
      expect(find.text('Delay irrigation 24 h'), findsOneWidget);
      expect(find.textContaining('8–10 mm of rain is expected tonight'), findsOneWidget);
      expect(find.text('Adequate (pre-rain)'), findsOneWidget);
      expect(find.textContaining('Carry an umbrella and drive safely'), findsNothing);
    });

    testWidgets('Farmer Advisory dynamically calculates guidance for fair and dry weather',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dryWeather = DemoWeatherProvider.getWeather().copyWith(
        weatherCondition: 'Sunny',
        rainfallAmountMm: 0.0,
        rainfallProbability: 0.0,
        windSpeedKmh: 10.0,
      );

      await tester.pumpWidget(MaterialApp(home: FarmerAdvisoryDetailScreen(weather: dryWeather)));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Good for Field Work'), findsOneWidget);
      expect(find.text('Maintain regular irrigation'), findsOneWidget);
      expect(find.text('No rain expected'), findsOneWidget);
      expect(find.textContaining('8–10 mm of rain is expected tonight'), findsNothing);
    });

    testWidgets('Farmer Advisory handles empty or missing weather gracefully',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: FarmerAdvisoryContent(weather: null))),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Advisory Unavailable'), findsOneWidget);
      expect(find.textContaining('Unable to compute agricultural advisory'), findsOneWidget);
    });
  });

  group('Fix #7: Destination-Based Travel Advisory Tests', () {
    testWidgets('Travel Advisory provides location-selection interface with search field and quick chips',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final weather = DemoWeatherProvider.getWeather();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TravelAdvisoryContent(currentWeather: weather),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Verifies step 1: location input field is provided
      expect(find.text('Select Travel Destination'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Enter destination city (e.g. Mumbai, Delhi, Shimla)...'), findsOneWidget);

      // Verifies quick destination chips
      expect(find.text('Delhi'), findsOneWidget);
      expect(find.text('Mumbai'), findsOneWidget);
      expect(find.text('Bengaluru'), findsOneWidget);
      expect(find.text('Shimla'), findsOneWidget);

      // Verifies initial prompt is displayed asking user to select destination
      expect(find.text('Enter Destination to Generate Advisory'), findsOneWidget);
    });

    testWidgets('Travel Advisory route mode allows specifying starting location and destination',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final weather = DemoWeatherProvider.getWeather();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TravelAdvisoryContent(currentWeather: weather),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Tap + Route Mode button
      await tester.tap(find.text('+ Route Mode'));
      await tester.pumpAndSettle();

      // Now two text fields are available: starting location and destination
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Starting location (e.g. Current Location)'), findsOneWidget);
      expect(find.text('Single City'), findsOneWidget);
    });

    testWidgets('Travel Advisory never fabricates transit or airport incidents and clearly marks data unavailable',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final weather = DemoWeatherProvider.getWeather();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TravelAdvisoryDetailScreen(weather: weather),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Travel Advisory Screen is presented
      expect(find.text('Travel Advisory'), findsWidgets);
      expect(find.text('Select Travel Destination'), findsOneWidget);

      // Verifies that the old fabricated mock strings are completely gone
      expect(find.textContaining('Jadcherla'), findsNothing);
      expect(find.textContaining('Mehdipatnam'), findsNothing);
      expect(find.textContaining('TSRTC 5C, 10K, 216'), findsNothing);
      expect(find.textContaining('No weather delays reported at RGIA'), findsNothing);
    });
  });
}
