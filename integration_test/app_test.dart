// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:money_control/main.dart' as app;

// Import screens to identify widgets (if needed, or verify text presence)
// import 'package:money_control/Screens/homescreen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('End-to-End App Flow: Login -> Home -> Navigation', (
    WidgetTester tester,
  ) async {
    // 1. Launch App via safe test entry point
    await app.mainCommon(isTest: true);
    await tester.pumpAndSettle();

    // 2. Handling Authentication State
    // Allow time for Firebase Auth to initialize and check state
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Check if we are at the Login Screen by looking for specific text
    final loginButtonFinder = find.text('Sign In');
    final homeFinder = find.text('Welcome Back');

    if (loginButtonFinder.evaluate().isNotEmpty) {
      print("Starting from Login Screen");

      final emailField = find.ancestor(
        of: find.text('Email Address'),
        matching: find.byType(Column),
      );
      final emailInput = find.descendant(
        of: emailField,
        matching: find.byType(TextField),
      );

      await tester.enterText(emailInput, 'test@example.com');
      await tester.pumpAndSettle();

      final passwordField = find.ancestor(
        of: find.text('Password'),
        matching: find.byType(Column),
      );
      final passwordInput = find.descendant(
        of: passwordField,
        matching: find.byType(TextField),
      );

      await tester.enterText(passwordInput, 'password123');
      await tester.pumpAndSettle();

      // Tap Login
      await tester.tap(loginButtonFinder);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    } else if (homeFinder.evaluate().isNotEmpty) {
      print("Already Logged In - Starting from Home Screen");
    }

    // 3. Verify Home Screen
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Recent Transactions'), findsOneWidget);

    // 4. Navigation Test
    // Tap 'Analytics' in Bottom Nav (Index 1)
    final analyticsTab = find.text('Analytics');
    await tester.tap(analyticsTab);
    await tester.pumpAndSettle();

    // Verify we are on Analytics Screen
    expect(find.text('Analytics'), findsOneWidget);

    // Tap 'Wealth' (Index 3)
    final wealthTab = find.text('Wealth');
    await tester.tap(wealthTab);
    await tester.pumpAndSettle();

    expect(find.text('Wealth'), findsOneWidget);

    // Return to Home
    final homeTab = find.text('Home');
    await tester.tap(homeTab);
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);

    print("E2E Test Completed Successfully!");
  });
}
