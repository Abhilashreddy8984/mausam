// Basic smoke tests: verify startup state and home screen rendering.

import 'package:flutter_test/flutter_test.dart';

import 'package:mausam_personalized/data/demo_weather_provider.dart';
import 'package:mausam_personalized/main.dart';
import 'package:mausam_personalized/widgets/mausam_state_views.dart';

void main() {
  testWidgets('Mausam app renders loading view at initial launch', (WidgetTester tester) async {
    await tester.pumpWidget(const MausamApp());
    // Initial launch displays loading view without demo-weather flash
    expect(find.byType(MausamLoadingView), findsOneWidget);
    expect(find.text('Fetching local weather...'), findsOneWidget);
  });

  testWidgets('Mausam app renders home screen when weather is provided', (WidgetTester tester) async {
    await tester.pumpWidget(MausamApp(initialWeather: DemoWeatherProvider.getWeather()));
    // App name is visible in the header
    expect(find.text('MAUSAM'), findsOneWidget);
    // Location is shown
    expect(find.text('Hyderabad'), findsOneWidget);
  });
}
