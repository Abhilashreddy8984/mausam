// ============================================================
// test/weather_advisory_test.dart
//
// Comprehensive unit and widget tests for Fix #6:
// - Condition-specific alert classification
// - Exact precaution verification (Haze vs Thunderstorm vs Rain etc.)
// - Official IMD alerts vs Internally calculated weather risks
// - Validity period integrity (no fabrication)
// - Persona relevance across all 8 personas
// - Missing data handling without fabrication
// - WeatherDetailScreen & AlertsScreen UI rendering
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mausam_personalized/data/demo_data.dart';
import 'package:mausam_personalized/models/homepage_response.dart';
import 'package:mausam_personalized/models/persona.dart';
import 'package:mausam_personalized/models/weather_data.dart';
import 'package:mausam_personalized/screens/alerts_screen.dart';
import 'package:mausam_personalized/screens/detail_screen.dart';
import 'package:mausam_personalized/services/advisory_service.dart';
import 'package:mausam_personalized/widgets/mausam_state_views.dart';

WeatherData _buildTestWeather({
  String city = 'Hyderabad',
  String state = 'Telangana',
  double tempC = 28.0,
  double feelsLikeC = 29.0,
  int humidity = 60,
  String condition = 'Partly Cloudy',
  double windKmh = 12.0,
  String windDir = 'SW',
  double? rainMm,
  double visKm = 10.0,
  int? aqi,
  int? uv,
  String? weatherCode,
  WeatherCodeSystem? codeSystem,
  DateTime? timestamp,
  List<WeatherAlert> alerts = const [],
}) {
  return WeatherData(
    city: city,
    state: state,
    temperatureC: tempC,
    feelsLikeC: feelsLikeC,
    humidity: humidity,
    weatherCondition: condition,
    weatherConditionDetail: condition,
    windSpeedKmh: windKmh,
    windDirection: windDir,
    rainfallAmountMm: rainMm,
    visibilityKm: visKm,
    aqi: aqi,
    uvIndex: uv,
    weatherCode: weatherCode,
    weatherCodeSystem: codeSystem,
    timestamp: timestamp,
    alerts: alerts,
  );
}

void main() {
  group('Fix #6: Condition-Specific Weather Alert Classification', () {
    test('Haze condition generates visibility precautions and NEVER thunderstorm precautions', () {
      final hazeWeather = _buildTestWeather(
        condition: 'Haze',
        weatherCode: '5',
        windKmh: 3.0,
        rainMm: 0.0,
        visKm: 2.5,
      );

      final alert = AdvisoryService.resolveAlert(hazeWeather);

      // Verify hazard type and title
      expect(alert.hazardType, WeatherHazardType.hazeFog);
      expect(alert.condition, 'Haze');
      expect(alert.title, contains('Haze'));

      // Critical check: Precautions MUST relate to visibility and headlights
      expect(
        alert.precautions.any((p) => p.toLowerCase().contains('headlights') || p.toLowerCase().contains('fog lights')),
        isTrue,
        reason: 'Haze alert must contain headlight/fog light guidance',
      );
      expect(
        alert.precautions.any((p) => p.toLowerCase().contains('following distance') || p.toLowerCase().contains('visibility')),
        isTrue,
        reason: 'Haze alert must contain following distance / visibility guidance',
      );

      // Critical check: Precautions MUST NOT contain thunderstorm or lightning advice
      for (final precaution in alert.precautions) {
        final lower = precaution.toLowerCase();
        expect(lower.contains('thunderstorm'), isFalse, reason: 'Haze must not display thunderstorm precautions');
        expect(lower.contains('lightning'), isFalse, reason: 'Haze must not display lightning precautions');
        expect(lower.contains('tall trees'), isFalse, reason: 'Haze must not display tree-shelter precautions');
        expect(lower.contains('unplug sensitive electrical'), isFalse, reason: 'Haze must not display electrical surge precautions');
      }

      // Validity period must NOT be fabricated
      expect(alert.validPeriod, isNull, reason: 'Validity period must not be fabricated when absent from source');
    });

    test('Thunderstorm condition generates lightning and shelter precautions', () {
      final stormWeather = _buildTestWeather(
        condition: 'Thunderstorm with Gusty Winds',
        weatherCode: '29',
        windKmh: 38.0,
        rainMm: 14.0,
      );

      final alert = AdvisoryService.resolveAlert(stormWeather);

      expect(alert.hazardType, WeatherHazardType.thunderstorm);
      expect(alert.severity, AlertSeverity.medium);
      expect(
        alert.precautions.any((p) => p.toLowerCase().contains('indoors') || p.toLowerCase().contains('shut')),
        isTrue,
      );
      expect(
        alert.precautions.any((p) => p.toLowerCase().contains('tall isolated trees') || p.toLowerCase().contains('open fields')),
        isTrue,
      );
    });

    test('Heavy rainfall generates waterlogging and drainage precautions', () {
      final rainWeather = _buildTestWeather(
        condition: 'Heavy Rain',
        weatherCode: '9',
        rainMm: 55.0,
      );

      final alert = AdvisoryService.resolveAlert(rainWeather);

      expect(alert.hazardType, WeatherHazardType.heavyRain);
      expect(alert.severity, AlertSeverity.high);
      expect(
        alert.precautions.any((p) => p.toLowerCase().contains('waterlogged underpasses') || p.toLowerCase().contains('flooded')),
        isTrue,
      );
      expect(
        alert.precautions.any((p) => p.toLowerCase().contains('drain')),
        isTrue,
      );
    });

    test('Strong wind generates structural and flying debris precautions', () {
      final windWeather = _buildTestWeather(
        condition: 'Windy',
        windKmh: 45.0,
      );

      final alert = AdvisoryService.resolveAlert(windWeather);

      expect(alert.hazardType, WeatherHazardType.strongWind);
      expect(
        alert.precautions.any((p) => p.toLowerCase().contains('loose outdoor objects') || p.toLowerCase().contains('hoardings')),
        isTrue,
      );
    });

    test('Extreme heat generates hydration and peak sun avoidance precautions', () {
      final heatWeather = _buildTestWeather(
        tempC: 42.0,
        feelsLikeC: 44.0,
        condition: 'Heatwave',
      );

      final alert = AdvisoryService.resolveAlert(heatWeather);

      expect(alert.hazardType, WeatherHazardType.heatwave);
      expect(
        alert.precautions.any((p) => p.toLowerCase().contains('water') || p.toLowerCase().contains('hydrated')),
        isTrue,
      );
      expect(
        alert.precautions.any((p) => p.toLowerCase().contains('11 am') || p.toLowerCase().contains('sun')),
        isTrue,
      );
    });
  });

  group('Fix #6: Provenance & Missing Data Integrity', () {
    test('Distinguishes official IMD alert from internally calculated advisory', () {
      final weather = _buildTestWeather(
        condition: 'Haze',
        visKm: 2.0,
      );

      // Without official warnings -> marked calculated
      final calculatedAlert = AdvisoryService.resolveAlert(weather);
      expect(calculatedAlert.source, AlertSource.calculated);
      expect(calculatedAlert.isOfficial, isFalse);

      // With official IMD warning in payload -> marked official IMD
      final officialAlert = AdvisoryService.resolveAlert(
        weather,
        officialWarnings: [
          const BackendWeatherWarning(
            warningType: 'Yellow Alert',
            severity: 'moderate',
            title: 'Dense Fog Warning',
            description: 'Dense fog likely over Hyderabad district',
            district: 'Hyderabad',
            validFrom: '10:00 AM',
            validUntil: '02:00 PM',
            source: 'IMD',
          ),
        ],
      );

      expect(officialAlert.source, AlertSource.officialImd);
      expect(officialAlert.isOfficial, isTrue);
      expect(officialAlert.title, 'Dense Fog Warning');
      expect(officialAlert.validPeriod, 'Valid: 10:00 AM – 02:00 PM');
    });

    test('Does not fabricate missing validity or rainfall data', () {
      final weatherWithoutRain = _buildTestWeather(
        condition: 'Partly Cloudy',
        rainMm: null,
      );

      final alert = AdvisoryService.resolveAlert(weatherWithoutRain);
      expect(alert.rainImpact, 'Precipitation data unavailable');
      expect(alert.validPeriod, isNull);
    });

    test('Normal weather conditions do not generate false emergency alarms', () {
      final normalWeather = _buildTestWeather(
        condition: 'Clear Sky',
        tempC: 25.0,
        windKmh: 10.0,
        rainMm: 0.0,
        visKm: 10.0,
      );

      final alert = AdvisoryService.resolveAlert(normalWeather);
      expect(alert.hazardType, WeatherHazardType.normal);
      expect(alert.severity, AlertSeverity.low);
      expect(alert.isActive, isFalse);
      expect(alert.severityLabel, 'Normal Conditions');
    });
  });

  group('Fix #6: Persona-Specific Tailored Advisories', () {
    test('Farmer receives agrimet guidance for irrigation and field work', () {
      final rainyWeather = _buildTestWeather(
        condition: 'Rain Showers',
        rainMm: 12.0,
      );
      final rainyAlert = AdvisoryService.resolveAlert(rainyWeather);
      final farmerAdv = AdvisoryService.getPersonaAdvisory(Persona.farmer, rainyWeather, rainyAlert);

      expect(farmerAdv.headline.toLowerCase(), contains('hold irrigation'));
      expect(farmerAdv.recommendation.toLowerCase(), contains('postpone scheduled irrigation'));
      expect(farmerAdv.actionableTip.toLowerCase(), contains('drainage'));
    });

    test('Student receives campus transit and gear guidance', () {
      final rainyWeather = _buildTestWeather(
        condition: 'Rain Showers',
        rainMm: 10.0,
      );
      final rainyAlert = AdvisoryService.resolveAlert(rainyWeather);
      final studentAdv = AdvisoryService.getPersonaAdvisory(Persona.student, rainyWeather, rainyAlert);

      expect(studentAdv.headline.toLowerCase(), contains('rainy commute'));
      expect(studentAdv.recommendation.toLowerCase(), contains('umbrella'));
    });

    test('Traveller receives highway route visibility guidance during Haze', () {
      final hazeWeather = _buildTestWeather(
        condition: 'Haze',
        visKm: 2.0,
      );
      final hazeAlert = AdvisoryService.resolveAlert(hazeWeather);
      final travellerAdv = AdvisoryService.getPersonaAdvisory(Persona.traveller, hazeWeather, hazeAlert);

      expect(travellerAdv.headline.toLowerCase(), contains('visibility'));
      expect(travellerAdv.recommendation.toLowerCase(), contains('low beams'));
    });

    test('Commuter receives transit delay and waterlogging guidance during heavy rain', () {
      final rainyWeather = _buildTestWeather(
        condition: 'Heavy Rain',
        rainMm: 25.0,
      );
      final rainyAlert = AdvisoryService.resolveAlert(rainyWeather);
      final commuterAdv = AdvisoryService.getPersonaAdvisory(Persona.commuter, rainyWeather, rainyAlert);

      expect(commuterAdv.headline.toLowerCase(), contains('waterlogging'));
      expect(commuterAdv.recommendation.toLowerCase(), contains('extra transit time'));
    });

    test('Health persona receives indoor shift guidance during poor AQI', () {
      final smoggyWeather = _buildTestWeather(
        aqi: 280,
      );
      final alert = AdvisoryService.resolveAlert(smoggyWeather);
      final healthAdv = AdvisoryService.getPersonaAdvisory(Persona.healthFitness, smoggyWeather, alert);

      expect(healthAdv.headline.toLowerCase(), contains('poor air quality'));
      expect(healthAdv.recommendation.toLowerCase(), contains('indoors'));
    });

    test('Outdoor worker receives lightning safety halt guidance during thunderstorms', () {
      final stormWeather = _buildTestWeather(
        condition: 'Thunderstorm',
      );
      final stormAlert = AdvisoryService.resolveAlert(stormWeather);
      final workerAdv = AdvisoryService.getPersonaAdvisory(Persona.outdoorWorker, stormWeather, stormAlert);

      expect(workerAdv.headline.toLowerCase(), contains('lightning'));
      expect(workerAdv.fieldSuitability.toLowerCase(), contains('halt'));
    });

    test('Senior citizen receives heat shelter guidance during high heat', () {
      final hotWeather = _buildTestWeather(
        tempC: 41.0,
      );
      final alert = AdvisoryService.resolveAlert(hotWeather);
      final seniorAdv = AdvisoryService.getPersonaAdvisory(Persona.seniorCitizen, hotWeather, alert);

      expect(seniorAdv.headline.toLowerCase(), contains('high temperature'));
      expect(seniorAdv.recommendation.toLowerCase(), contains('indoors'));
    });

    test('Event planner receives wind reinforcement guidance during high winds', () {
      final windyWeather = _buildTestWeather(
        windKmh: 42.0,
      );
      final alert = AdvisoryService.resolveAlert(windyWeather);
      final plannerAdv = AdvisoryService.getPersonaAdvisory(Persona.eventPlanner, windyWeather, alert);

      expect(plannerAdv.headline.toLowerCase(), contains('canopies'));
      expect(plannerAdv.recommendation.toLowerCase(), contains('anchor'));
    });
  });

  group('Fix #6: UI Rendering on Detail Screen & Alerts Screen', () {
    testWidgets('Yellow Alert detail screen renders Haze precautions without thunderstorm mismatch', (tester) async {
      final hazeWeather = _buildTestWeather(
        condition: 'Haze',
        weatherCode: '5',
        windKmh: 3.0,
        rainMm: 0.0,
        visKm: 2.5,
      );

      final alert = AdvisoryService.resolveAlert(hazeWeather);
      final weatherWithAlert = hazeWeather.copyWith(alerts: [alert]);

      await tester.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: WeatherDetailScreen(
            card: const WeatherCardData(
              type: WeatherCardType.weatherAlert,
              title: 'Weather Alert',
              value: '⚠ Yellow Alert',
              icon: Icons.warning_amber_rounded,
              accentColor: Color(0xFFF57F17),
              isAlert: true,
            ),
            weather: weatherWithAlert,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the badge indicates calculated advisory (not claiming fake official IMD)
      expect(find.text('WEATHER ADVISORY'), findsOneWidget);

      // Verify condition is Haze
      expect(find.text('Haze'), findsWidgets);

      // Verify low-beam / fog lights precautions ARE present
      expect(find.textContaining('low-beam headlights'), findsOneWidget);

      // Verify thunderstorm precautions ARE NOT present
      expect(find.textContaining('until the thunderstorm passes'), findsNothing);
      expect(find.textContaining('open areas, tall trees'), findsNothing);
      expect(find.textContaining('unplug sensitive electrical appliances'), findsNothing);
    });

    testWidgets('AlertsScreen displays No Alerts state when conditions are normal', (tester) async {
      final normalWeather = _buildTestWeather(
        condition: 'Fair',
        tempC: 24.0,
        visKm: 10.0,
        rainMm: 0.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AlertsScreen(weather: normalWeather),
        ),
      );
      await tester.pumpAndSettle();

      // No fake 25 Sep alerts! Displays clean no-alerts view
      expect(find.byType(MausamNoAlertsView), findsOneWidget);
    });

    testWidgets('AlertsScreen displays condition-specific alert when hazard is active', (tester) async {
      final stormWeather = _buildTestWeather(
        condition: 'Thunderstorm',
        weatherCode: '29',
        windKmh: 35.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AlertsScreen(weather: stormWeather),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thunderstorm Advisory'), findsOneWidget);
      expect(find.textContaining('windows and doors firmly shut'), findsOneWidget);
    });
  });
}
