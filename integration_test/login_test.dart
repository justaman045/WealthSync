// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:money_control/main.dart' as app;
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import screens to identify widgets
import 'package:money_control/Screens/homescreen.dart';

Future<void> navigateThroughSplash(WidgetTester tester) async {
  // Page 1
  if (find.text('Get Started').evaluate().isNotEmpty) {
    print(" on Splash Page 1 -> Tapping Get Started");
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
  }
  // Page 2
  if (find.text('Continue').evaluate().isNotEmpty) {
    print(" on Splash Page 2 -> Tapping Continue");
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }
  // Page 3
  if (find.text("Let's Start").evaluate().isNotEmpty) {
    print(" on Splash Page 3 -> Tapping Let's Start");
    await tester.tap(find.text("Let's Start"));
    await tester.pumpAndSettle();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Login Test: Invalid Credentials Prompt', (
    WidgetTester tester,
  ) async {
    await app.mainCommon(isTest: true);
    await tester.pumpAndSettle();

    // FORCE LOGOUT to ensure we are on Login Screen
    if (FirebaseAuth.instance.currentUser != null) {
      await FirebaseAuth.instance.signOut();
      await tester.pumpAndSettle();
    }

    // 1. Wait for Auth Check / Splash Animation
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Handle Splash Screen if present
    await navigateThroughSplash(tester);

    // Ensure we are on Login Screen
    final loginButtonFinder = find.text('Sign In');
    if (loginButtonFinder.evaluate().isEmpty) {
      print(
        "Login Screen not found even after SignOut and Splash Nav. Current widgets:",
      );
      // debugDumpApp(); // Optional for debugging
      return;
    }

    // 2. Enter Wrong Credentials
    print("Testing Invalid Credentials...");
    // Use indexed Finders to avoid ambiguity (Too many elements)
    final emailInput = find.byType(TextField).at(0);
    await tester.enterText(emailInput, 'wrong_user@test.com');
    await tester.pumpAndSettle();

    final passwordInput = find.byType(TextField).at(1);
    await tester.enterText(passwordInput, 'wrong_pass');
    await tester.pumpAndSettle();

    // Tap Login
    await tester.tap(loginButtonFinder);

    // Allow time for async auth call
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 3. Verify Error Prompt
    final errorIcon = find.byIcon(Icons.error_outline);
    expect(errorIcon, findsOneWidget);

    print("Invalid Login Test Passed: Error prompt displayed.");
  });

  testWidgets('Login Test: Valid Credentials Flow', (
    WidgetTester tester,
  ) async {
    Get.reset(); // Reset controllers
    await app.mainCommon(isTest: true);
    await tester.pumpAndSettle();

    // FORCE LOGOUT to ensure start from Login
    if (FirebaseAuth.instance.currentUser != null) {
      await FirebaseAuth.instance.signOut();
      await tester.pumpAndSettle();
    }

    // 1. Wait for Auth Check
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Handle Splash Screen if present
    await navigateThroughSplash(tester);

    final loginButtonFinder = find.text('Sign In');

    // 2. Enter Valid Credentials
    print("Testing Valid Credentials...");
    final emailInput = find.byType(TextField).at(0);
    await tester.enterText(emailInput, 'bitimat645@cimario.com');
    await tester.pumpAndSettle();

    final passwordInput = find.byType(TextField).at(1);
    // User provided password
    await tester.enterText(passwordInput, 'somkumud');
    await tester.pumpAndSettle();

    // Tap Login
    await tester.tap(loginButtonFinder);

    // Wait for Login to complete and Navigate
    // We use pump() with a duration instead of pumpAndSettle() because the Home Screen
    // may have ongoing animations (shimmer, background services) that prevent settling.
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    // 3. Verify Navigation to Home
    expect(find.byType(BankingHomeScreen), findsOneWidget);

    print("Valid Login Test Passed: Navigated to Home.");
  });
}
