// Basic smoke test: verify the Mausam app renders without crashing.

import 'package:flutter_test/flutter_test.dart';

import 'package:mausam_personalized/main.dart';

void main() {
  testWidgets('Mausam app renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MausamApp());
    // App name is visible in the header
    expect(find.text('MAUSAM'), findsOneWidget);
    // Location is shown
    expect(find.text('Hyderabad'), findsOneWidget);
  });
}
