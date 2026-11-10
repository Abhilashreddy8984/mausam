// ============================================================
// test/marine_advisory_test.dart
//
// Final Data-Integrity Audit Test Suite for Fix #6 (Marine Advisory):
// 1. Live Tide Data Integrity: Mumbai, Chennai, Visakhapatnam, and Kochi
//    must NOT display simulated tides as verified. When no live INCOIS
//    telemetry stream is connected, displays "Live tide data unavailable".
// 2. Wave Height Estimation: Wave height is derived from wind conditions
//    via a simplified empirical mapping (with wind duration, fetch, and
//    water-depth limitations explicitly documented as unmodeled).
// 3. Station Coordinates & Basin Mapping:
//    - Port Blair: Andaman Sea (MarineBasin.andamanSea).
//    - Kanyakumari: accurately described as Indian Ocean / Tri-Sea Confluence / Gulf of Mannar.
//    - Mumbai, Kochi, Goa, Mangaluru: Arabian Sea.
//    - Chennai, Visakhapatnam, Paradeep: Bay of Bengal.
// 4. Inland Locations (Hyderabad, Bengaluru, Delhi): Detected as inland
//    (>50 km from coast) and never presented with local coastal alerts.
// 5. Coastal Locations (Mumbai, Chennai, Visakhapatnam, Kochi): Basin assignments
//    strictly match geography.
// 6. UI Widget Integrity & Responsiveness: Displays "Live tide data unavailable"
//    and handles narrow screen widths (320px) without RenderFlex overflow.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mausam_personalized/data/demo_data.dart';
import 'package:mausam_personalized/models/marine_advisory_model.dart';
import 'package:mausam_personalized/models/persona.dart';
import 'package:mausam_personalized/models/weather_data.dart';
import 'package:mausam_personalized/screens/detail_screen.dart';
import 'package:mausam_personalized/services/marine_advisory_service.dart';
import 'package:mausam_personalized/widgets/farmer_advisory_content.dart';
import 'package:mausam_personalized/widgets/marine_advisory_content.dart';

WeatherData _buildTestWeather({
  String city = 'Hyderabad',
  String state = 'Telangana',
  double tempC = 28.0,
  double windKmh = 12.0,
  String windDir = 'SW',
  double visKm = 10.0,
  DateTime? timestamp,
}) {
  return WeatherData(
    city: city,
    state: state,
    temperatureC: tempC,
    feelsLikeC: tempC + 1.0,
    humidity: 60,
    weatherCondition: 'Clear',
    weatherConditionDetail: 'Clear Sky',
    windSpeedKmh: windKmh,
    windDirection: windDir,
    rainfallAmountMm: 0.0,
    visibilityKm: visKm,
    timestamp: timestamp ?? DateTime(2026, 11, 10, 10, 30),
  );
}

void main() {
  group('Fix #6 Data Integrity Audit: 1. Live Tide Data Verification', () {
    test('Mumbai, Chennai, Visakhapatnam and Kochi do not display simulated tides as verified', () {
      final stationsToVerify = ['mumbai', 'chennai', 'visakhapatnam', 'kochi'];

      for (final id in stationsToVerify) {
        final station = MarineAdvisoryService.kSupportedCoastalStations
            .firstWhere((s) => s.id == id);

        final advisory = MarineAdvisoryService.computeMarineAdvisory(
          station: station,
          weather: _buildTestWeather(city: station.name, windKmh: 15.0),
        );

        // Since no live INCOIS telemetry endpoint is connected:
        expect(advisory.hasLiveTideData, isFalse,
            reason: '${station.name} must not claim live tide data without an active INCOIS stream');
        expect(advisory.hasVerifiedTides, isFalse,
            reason: '${station.name} must not label estimates as verified');
        expect(advisory.tides, isEmpty,
            reason: '${station.name} must not contain fabricated/simulated tide entries');
      }
    });

    test('All catalog coastal stations have live tide telemetry set to false by default', () {
      for (final st in MarineAdvisoryService.kSupportedCoastalStations) {
        expect(st.hasTideTelemetry, isFalse,
            reason: '${st.name} should have hasTideTelemetry false until live API feed is connected');
      }
    });
  });

  group('Fix #6 Data Integrity Audit: 2. Simplified Wave Height & Sea State Estimation', () {
    test('Wave height is explicitly flagged as estimated and notes limitations in citation', () {
      final mumbai = MarineAdvisoryService.kSupportedCoastalStations
          .firstWhere((s) => s.id == 'mumbai');

      final advisory = MarineAdvisoryService.computeMarineAdvisory(
        station: mumbai,
        weather: _buildTestWeather(city: 'Mumbai', windKmh: 20.0),
      );

      expect(advisory.isWaveHeightEstimated, isTrue);
      expect(advisory.isSeaConditionsEstimated, isTrue);
      expect(advisory.waveHeightDisplay, contains('(Estimated)'));
      expect(advisory.sourceCitation, contains('Simplified wind-based wave estimate'));
      expect(advisory.sourceCitation, contains('unmodeled fetch, duration & bathymetry'));
    });

    test('Wave height scales with wind velocity using empirical thresholds', () {
      final mumbai = MarineAdvisoryService.kSupportedCoastalStations
          .firstWhere((s) => s.id == 'mumbai');

      // Low wind (5 km/h) -> calm sea
      final calm = MarineAdvisoryService.computeMarineAdvisory(
        station: mumbai,
        weather: _buildTestWeather(city: 'Mumbai', windKmh: 5.0),
      );
      expect(calm.waveHeightMeters, lessThan(1.0));
      expect(calm.seaConditions.toLowerCase(), contains('calm'));
      expect(calm.riskLevel, MarineRiskLevel.normal);

      // Moderate wind (30 km/h) -> moderate wave action
      final moderate = MarineAdvisoryService.computeMarineAdvisory(
        station: mumbai,
        weather: _buildTestWeather(city: 'Mumbai', windKmh: 30.0),
      );
      expect(moderate.waveHeightMeters, inInclusiveRange(1.0, 1.8));
      expect(moderate.riskLevel, MarineRiskLevel.caution);

      // Gale wind (60 km/h) -> severe sea warning
      final gale = MarineAdvisoryService.computeMarineAdvisory(
        station: mumbai,
        weather: _buildTestWeather(city: 'Mumbai', windKmh: 60.0),
      );
      expect(gale.waveHeightMeters, greaterThanOrEqualTo(3.5));
      expect(gale.riskLevel, MarineRiskLevel.severe);
      expect(gale.marineWarning, isNotNull);
    });
  });

  group('Fix #6 Data Integrity Audit: 3. Coastal Coordinates & Basin Mapping', () {
    test('Port Blair is correctly mapped to Andaman Sea', () {
      final portBlair = MarineAdvisoryService.kSupportedCoastalStations
          .firstWhere((s) => s.id == 'port_blair');
      expect(portBlair.basin, MarineBasin.andamanSea);
      expect(portBlair.basin.shortLabel, 'Andaman Sea');
      expect(portBlair.coastalZone, contains('Andaman Sea'));
    });

    test('Kanyakumari accurately describes its geographical region (Confluence / Gulf of Mannar)', () {
      final kanyakumari = MarineAdvisoryService.kSupportedCoastalStations
          .firstWhere((s) => s.id == 'kanyakumari');
      expect(kanyakumari.basin, MarineBasin.indianOcean);
      expect(kanyakumari.coastalZone, contains('Confluence'));
      expect(kanyakumari.basin.label, contains('Tri-Sea Confluence'));
    });

    test('Coordinates and basin assignments match authentic geographic truth for all key stations', () {
      final mumbai = MarineAdvisoryService.kSupportedCoastalStations.firstWhere((s) => s.id == 'mumbai');
      expect(mumbai.latitude, closeTo(18.9220, 0.01));
      expect(mumbai.longitude, closeTo(72.8347, 0.01));
      expect(mumbai.basin, MarineBasin.arabianSea);

      final chennai = MarineAdvisoryService.kSupportedCoastalStations.firstWhere((s) => s.id == 'chennai');
      expect(chennai.latitude, closeTo(13.0827, 0.01));
      expect(chennai.longitude, closeTo(80.2707, 0.01));
      expect(chennai.basin, MarineBasin.bayOfBengal);

      final vizag = MarineAdvisoryService.kSupportedCoastalStations.firstWhere((s) => s.id == 'visakhapatnam');
      expect(vizag.latitude, closeTo(17.6868, 0.01));
      expect(vizag.longitude, closeTo(83.2185, 0.01));
      expect(vizag.basin, MarineBasin.bayOfBengal);

      final kochi = MarineAdvisoryService.kSupportedCoastalStations.firstWhere((s) => s.id == 'kochi');
      expect(kochi.latitude, closeTo(9.9312, 0.01));
      expect(kochi.longitude, closeTo(76.2673, 0.01));
      expect(kochi.basin, MarineBasin.arabianSea);
    });

    test('Haversine distance calculation is mathematically sound', () {
      final distMumbaiChennai = MarineAdvisoryService.calculateDistanceKm(
        18.9220, 72.8347, // Mumbai
        13.0827, 80.2707, // Chennai
      );
      expect(distMumbaiChennai, inInclusiveRange(1000.0, 1060.0));

      final distZero = MarineAdvisoryService.calculateDistanceKm(18.9220, 72.8347, 18.9220, 72.8347);
      expect(distZero, closeTo(0.0, 0.001));
    });
  });

  group('Fix #6 Data Integrity Audit: 4. Inland Locations (Hyderabad, Bengaluru, Delhi)', () {
    test('Hyderabad is correctly detected as inland and not presented with local marine warnings', () {
      final res = MarineAdvisoryService.resolveNearestStation(city: 'Hyderabad');
      expect(res.isUserInland, isTrue);
      expect(res.distanceKm, greaterThan(300.0));

      // Demo card catalogue must show nearest coast instead of local tide
      final cards = buildWeatherCardCatalogue(_buildTestWeather(city: 'Hyderabad'));
      final marineCard = cards.firstWhere((c) => c.type == WeatherCardType.marineTide);
      expect(marineCard.subtitle, contains('Nearest Coast:'));
      expect(marineCard.subtitle, contains(res.station.name));
    });

    test('Bengaluru is correctly detected as inland', () {
      final res = MarineAdvisoryService.resolveNearestStation(city: 'Bengaluru');
      expect(res.isUserInland, isTrue);
      expect(res.distanceKm, inInclusiveRange(250.0, 350.0)); // ~290 km to Mangaluru/Chennai
    });

    test('Delhi is correctly detected as deeply inland (>800 km from coast)', () {
      final res = MarineAdvisoryService.resolveNearestStation(city: 'Delhi');
      expect(res.isUserInland, isTrue);
      expect(res.distanceKm, greaterThan(800.0));
    });
  });

  group('Fix #6 Data Integrity Audit: 5. Coastal Locations (Mumbai, Chennai, Visakhapatnam, Kochi)', () {
    test('Mumbai resolves strictly to Arabian Sea (Konkan Coast), NEVER Bay of Bengal', () {
      final res = MarineAdvisoryService.resolveNearestStation(city: 'Mumbai');
      expect(res.isUserInland, isFalse);
      expect(res.distanceKm, lessThan(50.0));
      expect(res.station.basin, MarineBasin.arabianSea);
      expect(res.station.basin.shortLabel, 'Arabian Sea');
      expect(res.station.name, contains('Mumbai'));
    });

    test('Chennai resolves strictly to Bay of Bengal (Coromandel Coast)', () {
      final res = MarineAdvisoryService.resolveNearestStation(city: 'Chennai');
      expect(res.isUserInland, isFalse);
      expect(res.distanceKm, lessThan(50.0));
      expect(res.station.basin, MarineBasin.bayOfBengal);
      expect(res.station.basin.shortLabel, 'Bay of Bengal');
    });

    test('Visakhapatnam resolves strictly to Bay of Bengal (Andhra Coast)', () {
      final res = MarineAdvisoryService.resolveNearestStation(city: 'Visakhapatnam');
      expect(res.isUserInland, isFalse);
      expect(res.distanceKm, lessThan(50.0));
      expect(res.station.basin, MarineBasin.bayOfBengal);
    });

    test('Kochi resolves strictly to Arabian Sea (Malabar Coast)', () {
      final res = MarineAdvisoryService.resolveNearestStation(city: 'Kochi');
      expect(res.isUserInland, isFalse);
      expect(res.distanceKm, lessThan(50.0));
      expect(res.station.basin, MarineBasin.arabianSea);
    });
  });

  group('Fix #6 Data Integrity Audit: 6. UI Widget Rendering & Responsiveness', () {
    testWidgets('Tide card displays "Live tide data unavailable" when no live INCOIS feed is active', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final weather = _buildTestWeather(city: 'Mumbai');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarineAdvisoryContent(weather: weather),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Live tide data unavailable'), findsWidgets);
      expect(find.text('Live Data Unavailable'), findsOneWidget);
      expect(find.textContaining('No active INCOIS tide gauge telemetry stream connected'), findsOneWidget);

      expect(find.textContaining('12:38 IST'), findsNothing);
      expect(find.textContaining('18:52 IST'), findsNothing);
    });

    testWidgets('Wave height tile clearly indicates "(Estimated)"', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final weather = _buildTestWeather(city: 'Mumbai', windKmh: 14.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarineAdvisoryContent(weather: weather),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wave Height (Estimated)'), findsOneWidget);
      expect(find.text('Sea State (Estimated)'), findsOneWidget);
      expect(find.textContaining('(Estimated)'), findsWidgets);
    });

    testWidgets('MarineAdvisoryContent renders without RenderFlex overflow on narrow screen (320px width)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final weather = _buildTestWeather(city: 'Mumbai');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarineAdvisoryContent(weather: weather),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Must render at 320px width without RenderFlex overflow');
      expect(find.text('Marine Advisory', skipOffstage: false), findsWidgets);
    });

    testWidgets('FarmerAdvisoryContent renders without RenderFlex overflow on narrow screen (320px width)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final weather = _buildTestWeather(city: 'Nagpur');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FarmerAdvisoryContent(weather: weather),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Must render at 320px width without RenderFlex overflow');
      expect(find.text('Farmer Advisory'), findsOneWidget);
    });

    testWidgets('WeatherDetailScreen correctly opens MarineAdvisoryContent', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final weather = _buildTestWeather(city: 'Mumbai');

      await tester.pumpWidget(
        MaterialApp(
          home: WeatherDetailScreen(
            card: const WeatherCardData(
              type: WeatherCardType.marineTide,
              title: 'Marine & Tide',
              value: '1.2 m waves',
              icon: Icons.waves_rounded,
              accentColor: Color(0xFF0284C7),
            ),
            weather: weather,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Marine Advisory'), findsWidgets);
      expect(find.byType(MarineAdvisoryContent), findsOneWidget);
    });
  });
}
