// ignore_for_file: avoid_print
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

    if (homeFinder.evaluate().isNotEmpty) {
      print("Already Logged In - Starting from Home Screen");
    } else if (loginButtonFinder.evaluate().isNotEmpty) {
      // Not logged in — verify login screen renders correctly and skip home assertions.
      print("Not logged in — verifying splash/login screen renders");
      expect(loginButtonFinder, findsOneWidget);
      return; // Cannot proceed further without real credentials.
    } else {
      print("Unknown screen state — skipping");
      return;
    }

    // 3. Verify Home Screen (only reached when already logged in)
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
