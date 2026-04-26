import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:money_control/main.dart' as app;
import 'package:get/get.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Get.testMode = true;

  testWidgets('E2E: Subscription Flow (Add, Edit, Pay, Verify)', (
    WidgetTester tester,
  ) async {
    // 1. App Launch
    app.mainCommon(isTest: true);
    await tester.pump(const Duration(milliseconds: 1500));

    // 2. Splash Screen Handling
    await tester.pumpAndSettle(const Duration(seconds: 2));
    if (find.text('Get Started').evaluate().isNotEmpty) {
      await tester.tap(find.text('Get Started'));
      await tester.pump(const Duration(milliseconds: 1500));
    }
    if (find.text('Continue').evaluate().isNotEmpty) {
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 1500));
    }
    if (find.text("Let's Start").evaluate().isNotEmpty) {
      await tester.tap(find.text("Let's Start"));
      await tester.pump(const Duration(milliseconds: 1500));
    }

    // 3. Login
    await tester.pump(const Duration(milliseconds: 1500));
    if (find.text('Sign In').evaluate().isNotEmpty) {
      final emailField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            (widget.decoration?.hintText?.contains('email') ?? false),
      );
      await tester.enterText(emailField, 'bitimat645@cimario.com');
      await tester.pump(const Duration(milliseconds: 1500));

      final passwordField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            (widget.decoration?.hintText?.contains('password') ?? false),
      );
      await tester.enterText(passwordField, 'somkumud');
      await tester.pump(const Duration(milliseconds: 1500));

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
    }

    // 4. Navigate to Subscriptions Screen
    expect(find.text('Total Balance'), findsOneWidget);

    // Find Subscription Icon in AppBar (Icons.event_repeat)
    // It's the second action button usually
    final subscriptionIcon = find.byIcon(Icons.event_repeat);
    await tester.tap(subscriptionIcon);
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Subscriptions'), findsOneWidget);
    expect(find.text('Add Subscription'), findsOneWidget);

    // 5. Add Subscription
    await tester.tap(find.text('Add Subscription'));
    await tester.pump(const Duration(milliseconds: 1500));

    // Form Fill
    expect(find.text('New Subscription'), findsOneWidget);

    // Or just find by hint/label logic if ancestor is tricky. Let's try simpler first.
    // Finding by type is order dependent.
    // Name is 1st, Amount is 2nd.

    await tester.enterText(find.byType(TextFormField).at(0), 'Netflix Test');
    await tester.enterText(find.byType(TextFormField).at(1), '499');

    // Save
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 1500));

    // Verify Creation
    expect(
      find.text('Netflix Test'),
      findsWidgets,
    ); // Might appear multiple times if not unique, but should find it.
    expect(find.text('₹499'), findsWidgets);

    // 6. Edit Subscription (Change Date)
    // Find Edit Icon (pencil) on the card
    final editIcon = find.byIcon(Icons.edit_rounded).first;
    await tester.tap(editIcon);
    await tester.pump(const Duration(milliseconds: 1500));

    expect(find.text('Edit Subscription'), findsOneWidget);

    // Tap Date Picker Row
    // It has "Next Payment:" text
    await tester.tap(find.byIcon(Icons.calendar_today));
    await tester.pump(const Duration(milliseconds: 1500));

    // Select a future date (e.g. 28th of current month or next, let's just pick a valid day)
    // We'll just tap 'OK' to confirm whatever default is selected or try to pick '28'.
    // Default is usually today + 30 days in the code logic for new, but here we are editing.
    // Let's just tap 'OK' to keep it simple, or '28' if visible.
    // Actually the user requirement is "edit the due date to any date in future".
    // Let's pick '28' if available, otherwise just OK is fine as long as it saves.
    if (find.text('28').evaluate().isNotEmpty) {
      await tester.tap(find.text('28'));
    }
    await tester.tap(find.text('OK'));
    await tester.pump(const Duration(milliseconds: 1500));

    // Save
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 1500));

    // 7. Pay (Mark as Paid)
    // Open Details by tapping the card body (not the edit icon).
    await tester.tap(find.text('Netflix Test').first);
    await tester.pump(const Duration(milliseconds: 1500));

    expect(find.text('Subscription Details'), findsOneWidget);

    // Tap "Mark Paid"
    await tester.tap(find.text('Mark Paid'));
    await tester.pump(const Duration(milliseconds: 1500));

    // Confirm Dialog
    expect(find.text('Confirm'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pump(const Duration(milliseconds: 1500));

    // Verify "Mark Paid" button might be gone or disabled, or History updated.
    // Check History List for transaction
    await tester.pump(const Duration(seconds: 3)); // Wait for firestore update
    expect(find.text('Payment History'), findsOneWidget);
    // Should see date and amount in list
    expect(find.textContaining('499'), findsWidgets);

    // 8. Verify Home Screen Reflection
    await tester.tap(
      find.byIcon(Icons.arrow_back_ios_new_rounded),
    ); // Back to Sub list
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.tap(
      find.byIcon(Icons.arrow_back_ios_new_rounded),
    ); // Back to Home
    await tester.pump(const Duration(milliseconds: 1500));

    expect(find.text('Total Balance'), findsOneWidget);

    // Check Recent Transactions for "Netflix Test" (Wait for stream)
    // Perform Pull-to-Refresh to ensure list is updated
    await tester.drag(find.byType(RefreshIndicator), const Offset(0, 300));
    await tester.pump(const Duration(seconds: 3));

    // Should be at the top of the list (or in the list at least)
    expect(find.text('Netflix Test', skipOffstage: false), findsWidgets);
    expect(
      find.textContaining('499', skipOffstage: false),
      findsWidgets,
    ); // Outflow

    // 9. Verify Details from Home
    // Scroll to it if needed
    final netflixItem = find.text('Netflix Test').first;
    await tester.scrollUntilVisible(
      netflixItem,
      500.0,
      scrollable: find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(netflixItem);
    await tester.pump(const Duration(milliseconds: 1500));

    expect(find.text('Transaction Details'), findsWidgets);
    expect(find.text('Money Sent!'), findsWidgets);
    expect(find.text('Netflix Test'), findsOneWidget);
  });
}
