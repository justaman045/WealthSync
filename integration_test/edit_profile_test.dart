import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:money_control/main.dart' as app;

import 'package:get/get.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Get.testMode = true;

  testWidgets('E2E: Edit Profile Flow', (WidgetTester tester) async {
    // 1. App Launch
    app.mainCommon(isTest: true);
    await tester.pumpAndSettle();

    // 2. Splash Screen Handling (3 Pages)
    // Page 1: Get Started
    await tester.pumpAndSettle(const Duration(seconds: 2));
    if (find.text('Get Started').evaluate().isNotEmpty) {
      debugPrint("Tapping Get Started");
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
    }

    // Page 2: Continue
    if (find.text('Continue').evaluate().isNotEmpty) {
      debugPrint("Tapping Continue");
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    // Page 3: Let's Start
    if (find.text("Let's Start").evaluate().isNotEmpty) {
      debugPrint("Tapping Let's Start");
      await tester.tap(find.text("Let's Start"));
      await tester.pumpAndSettle();
    }

    // 3. Login (Conditional)
    await tester.pumpAndSettle();

    // Check if "Sign In" button or text exists to determine if we are on Login Screen
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

    // 4. Verify Home Screen
    // Verify by "Welcome back" or "Total Balance"
    expect(find.textContaining('Welcome'), findsWidgets);
    expect(find.text('Total Balance'), findsOneWidget);

    // 5. Navigate to Edit Profile
    // Tap the profile image (Hero tag 'profile_pic') in the AppBar
    // It's wrapped in a GestureDetector inside Leading or Title
    // Finding by Hero tag in test is tricky directly, let's find by type/descendant
    // In homescreen.dart: Leading -> GestureDetector -> Obx -> Hero(tag: 'profile_pic')

    // Attempt to tap the profile picture in the leading slot of AppBar
    final profilePic = find.byType(Hero).first;
    // Or closer matcher:
    // final profilePic = find.descendant(of: find.byType(AppBar), matching: find.byType(GestureDetector)).first;

    await tester.tap(profilePic);
    await tester.pumpAndSettle();

    // 6. Verify Edit Profile Screen
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('First Name'), findsOneWidget);
    expect(find.text('Last Name'), findsOneWidget);
    expect(find.text('Phone Number'), findsOneWidget);

    // 7. Interact with Fields

    // Edit First Name
    // Find textfield below "First Name" label
    // Use widgetWithText logic or similar structure
    // _buildGlassTextField creates a Column with Label and then Container > TextFormField

    // Strategy: Find TextFormField that has "First Name" label nearby?
    // Or just find by initial value if known? The user is existing.
    // Let's assume we can find the fields by order or by finding the Label and looking "down".
    // Since we know the order: First Name, Last Name, Date of Birth, Email, Phone, Address

    final textFields = find.byType(TextFormField);
    // Index 0: First Name
    // Index 1: Last Name
    // Index 2: Email (Enabled=false)
    // Index 3: Phone
    // Index 4: Address

    await tester.enterText(textFields.at(0), 'UpdatedName');
    await tester.pumpAndSettle();

    await tester.enterText(textFields.at(1), 'UpdatedLast');
    await tester.pumpAndSettle();

    await tester.enterText(textFields.at(3), '1234567890'); // Phone
    await tester.pumpAndSettle();

    // 8. Select Date of Birth
    // Find "Select Date" or existing date text
    // actually just tap calendar icon below

    // Actually, let's look for "Date of Birth" label and tap the container below it (which is a GestureDetector)
    // Simplified: Tap the date picker row.
    // The code has: Text(label) ... GestureDetector(... child: Row(... Text(date) ... Icon(calendar) ) )

    // Tap the calendar icon to be safe
    final calendarIcon = find.byIcon(Icons.calendar_today_rounded);
    await tester.tap(calendarIcon);
    await tester.pumpAndSettle();

    // In Date Picker Dialog, select the 15th of current month (or just 'OK' to accept default/today)
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // 9. Save Changes
    final saveButton = find.text('SAVE CHANGES');
    await tester.dragUntilVisible(
      saveButton,
      find.byType(SingleChildScrollView),
      const Offset(0, -500), // Scroll down
    );
    await tester.pumpAndSettle();

    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // 10. Verify Success (Logic specific: Snackbar suppressed in test mode)
    // expect(find.text('Success'), findsOneWidget);
    // Wait slightly for async save to complete
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Wait for snackbar to disappear or navigate back
    // If not auto-nav back, user stays on screen. The code shows only Snackbar, no pop.

    // 11. Verify Changes Persisted (Locally in fields)
    expect(find.text('UpdatedName'), findsWidgets);
    expect(find.text('UpdatedLast'), findsWidgets);

    // 12. Navigate Back
    final backButton = find.byIcon(Icons.arrow_back_ios);
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    // Verify Home
    expect(find.textContaining('Welcome'), findsWidgets);

    // Verify Name updated on Home (if it shows First Name)
    // HomeScreen logic: Shows Reference to userModel.firstName
    expect(find.text('UpdatedName'), findsOneWidget);
  });
}
