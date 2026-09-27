import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naval_advmobprog/main.dart';

// The widget integration test suite verifies app startup, navigation, and settings toggles
void main() {
  testWidgets('E-Commerce App initial render and settings navigation test',
      (WidgetTester tester) async {
    // boots up the main app widget and waits for all initial animations and frames to settle
    await tester.pumpWidget(const NavalAdvMobProg());
    await tester.pumpAndSettle();

    // checks that the settings gear icon is visible in the top navigation bar on the Home screen
    final settingsIconFinder = find.byIcon(Icons.settings);
    expect(settingsIconFinder, findsOneWidget);

    // taps the settings icon and waits for the screen push transition animation to finish
    await tester.tap(settingsIconFinder);
    await tester.pumpAndSettle();

    // confirms that the Settings screen loaded properly by checking for the title and Dark Mode option
    expect(find.text("Settings"), findsOneWidget);
    expect(find.text("Dark Mode"), findsOneWidget);

    // locates the theme switch control on the Settings screen
    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);

    // simulates a user tapping the switch to flip between light and dark mode, then waits for the UI to refresh
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
  });
}