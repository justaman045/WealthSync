// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:money_control/Config/app_strings.dart';
import 'package:money_control/main.dart' as app;
import 'package:firebase_auth/firebase_auth.dart';
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgetsWithScreenshots('Login Test: Invalid Credentials Prompt', (
    WidgetTester tester,
  ) async {
    // resetTestData() initializes Firebase (mainCommon's ThemeController touches
    // FirebaseAuth.instance immediately) and wipes the persisted account's data.
    await resetTestData();
    await app.mainCommon(isTest: true);
    await pumpAndSettleSafe(tester);

    // FORCE LOGOUT to ensure we are on Login Screen
    if (FirebaseAuth.instance.currentUser != null) {
      await FirebaseAuth.instance.signOut();
      await pumpAndSettleSafe(tester, timeout: const Duration(seconds: 5));
    }

    // Handle splash walkthrough, then land on Login.
    await handleSplashAndOnboarding(tester);
    await pumpAndSettleSafe(tester);

    final loginButtonFinder = find.text(AppStrings.signIn);
    if (loginButtonFinder.evaluate().isEmpty) {
      // A `return` here would register the test as PASSED while never asserting
      // the negative-credentials prompt — a silent skip hiding a real failure
      // (sign-out or splash-nav broke). Fail loudly with the visible screen.
      final visibleTexts = find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data)
          .whereType<String>()
          .take(30)
          .toList();
      fail(
        'Login screen not found after sign out and splash nav. '
        'Expected "${AppStrings.signIn}". Visible texts: $visibleTexts',
      );
    }

    // Enter Wrong Credentials
    print('Testing Invalid Credentials...');
    final emailInput = find.byType(TextField).at(0);
    await tester.enterText(emailInput, 'wrong_user@test.com');
    await pumpAndSettleSafe(tester);

    final passwordInput = find.byType(TextField).at(1);
    await tester.enterText(passwordInput, 'wrong_pass');
    await pumpAndSettleSafe(tester);

    // Dismiss keyboard so the Sign In button is not covered.
    FocusManager.instance.primaryFocus?.unfocus();
    await pumpAndSettleSafe(tester);
    await tester.ensureVisible(loginButtonFinder);
    await pumpAndSettleSafe(tester);

    await tester.tap(loginButtonFinder, warnIfMissed: false);
    await pumpAndSettleSafe(tester, timeout: const Duration(seconds: 5));

    // Verify Error Prompt
    final errorIcon = find.byIcon(Icons.error_outline);
    expect(errorIcon, findsOneWidget);

    print('Invalid Login Test Passed: Error prompt displayed.');
  });
}
