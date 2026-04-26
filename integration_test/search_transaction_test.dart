import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:money_control/main.dart' as app;
import 'package:get/get.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Get.testMode = true; // Ensure safe GetX usage

  testWidgets('E2E: Search Transaction Flow', (WidgetTester tester) async {
    // 1. App Launch
    app.mainCommon(isTest: true);
    await tester.pumpAndSettle();

    // 2. Splash Screen Handling
    await tester.pumpAndSettle(const Duration(seconds: 2));
    if (find.text('Get Started').evaluate().isNotEmpty) {
      debugPrint("Tapping Get Started");
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
    }
    if (find.text('Continue').evaluate().isNotEmpty) {
      debugPrint("Tapping Continue");
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
    if (find.text("Let's Start").evaluate().isNotEmpty) {
      debugPrint("Tapping Let's Start");
      await tester.tap(find.text("Let's Start"));
      await tester.pumpAndSettle();
    }

    // 3. Login
    await tester.pumpAndSettle();
    if (find.text('Sign In').evaluate().isNotEmpty) {
      final emailField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            (widget.decoration?.hintText?.contains('email') ?? false),
      );
      await tester.enterText(emailField, 'bitimat645@cimario.com');
      await tester.pumpAndSettle();

      final passwordField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            (widget.decoration?.hintText?.contains('password') ?? false),
      );
      await tester.enterText(passwordField, 'somkumud');
      await tester.pumpAndSettle();

      final loginButton = find.text('Sign In');
      await tester.tap(loginButton);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    }

    // 4. Verify Home Screen & Tap Search Icon
    expect(find.text('Total Balance'), findsOneWidget);

    // Find Search Icon in AppBar (Hero tag 'search_bar' or Icon)
    final searchIcon = find.byIcon(Icons.search);
    await tester.tap(searchIcon);
    await tester.pumpAndSettle();

    // 5. Verify Search Screen
    expect(find.text('Search Transactions'), findsOneWidget);
    expect(
      find.textContaining('Search by name, amount'),
      findsOneWidget,
    ); // Hint text

    final searchField = find.byType(TextField);

    // 6. Test Case A: Search by Name "Freelance"
    debugPrint("Testing Search by Name...");
    await tester.enterText(searchField, 'Freelance');
    await tester.pumpAndSettle(
      const Duration(seconds: 1),
    ); // Wait for debounce/results

    expect(
      find.text('Freelance Client'),
      findsWidgets,
    ); // Should find transaction

    // Clear Search
    await tester.enterText(searchField, '');
    await tester.pumpAndSettle();

    // 7. Test Case B: Search by Amount "500"
    debugPrint("Testing Search by Amount...");
    await tester.enterText(searchField, '500');
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.textContaining('500'), findsWidgets);

    // Clear Search
    await tester.enterText(searchField, '');
    await tester.pumpAndSettle();

    // 8. Test Case C: Search by Category "Salary"
    debugPrint("Testing Search by Category...");
    await tester.enterText(searchField, 'Salary');
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Salary'), findsWidgets); // Category text

    // 9. Open Details
    // Tap the first result (Salary/Freelance Client transaction)
    debugPrint("Navigating to Details...");

    // Assuming 'Freelance Client' is visible in the list from the "Salary" search (since it's the sender of the Salary)
    // or we can tap the list item container
    await tester.tap(find.text('Freelance Client').first);
    await tester.pumpAndSettle();

    // 10. Verify Transaction Result Screen
    expect(find.text('Transaction Details'), findsWidgets);
    expect(find.text('Money Received!'), findsOneWidget);
    expect(find.textContaining('500.00'), findsWidgets);
    expect(find.text('Freelance Client'), findsOneWidget);
  });
}
