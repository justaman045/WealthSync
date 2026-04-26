// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:money_control/main.dart' as app;
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:money_control/Screens/homescreen.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Screens/add_transaction.dart';

import 'package:money_control/Components/quick_send.dart';
import 'package:shimmer/shimmer.dart';

// Helper to navigate splash screen
Future<void> navigateThroughSplash(WidgetTester tester) async {
  if (find.text('Get Started').evaluate().isNotEmpty) {
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
  }
  if (find.text('Continue').evaluate().isNotEmpty) {
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }
  if (find.text("Let's Start").evaluate().isNotEmpty) {
    await tester.tap(find.text("Let's Start"));
    await tester.pumpAndSettle();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Add Transaction Flow', (WidgetTester tester) async {
    // 1. App Start & Login Logic
    await app.mainCommon(isTest: true);
    await tester.pumpAndSettle();

    if (FirebaseAuth.instance.currentUser != null) {
      await FirebaseAuth.instance.signOut();
      await tester.pumpAndSettle();
    }

    await tester.pumpAndSettle(const Duration(seconds: 3));
    await navigateThroughSplash(tester);

    // Login
    final emailInput = find.byType(TextField).at(0);
    final passwordInput = find.byType(TextField).at(1);
    final loginButton = find.text('Sign In');

    await tester.enterText(emailInput, 'bitimat645@cimario.com');
    await tester.pumpAndSettle();
    await tester.enterText(passwordInput, 'somkumud'); // Valid password
    await tester.pumpAndSettle();
    await tester.tap(loginButton);

    // Wait for Home Screen
    bool homeFound = false;
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (find.byType(BankingHomeScreen).evaluate().isNotEmpty) {
        homeFound = true;
        break;
      }
    }
    expect(homeFound, isTrue, reason: "Failed to reach Home Screen");
    await tester.pumpAndSettle();

    // 2. Wait for Shimmer (Loading) to Finish in QuickSendRow
    // QuickSendRow shows Shimmer when loading.
    for (int i = 0; i < 10; i++) {
      // Wait up to 10 seconds
      await tester.pump(const Duration(seconds: 1));
      final quickSend = find.byType(QuickSendRow);
      final shimmer = find.descendant(
        of: quickSend,
        matching: find.byType(Shimmer),
      );
      if (shimmer.evaluate().isEmpty) {
        break;
      }
    }

    // 2. Ensure Category Exists
    final controller = Get.find<TransactionController>();

    if (controller.categories.isEmpty) {
      print("Controller reports no categories. Seeding 'Food'...");
      try {
        await controller.addCategory("Food");
      } catch (e) {
        print("Error seeding category: $e");
      }
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }

    await tester.pumpAndSettle();

    // 3. Tap First Icon in QuickSendRow
    // We look for Text in QuickSendRow (Row -> _neonQuickSender -> Text)
    final quickSendFinder = find.byType(QuickSendRow);

    final categoryTextFinder = find.descendant(
      of: quickSendFinder,
      matching: find.byType(Text),
    );

    // Filter out "No categories found"
    final validCategoryFinders = categoryTextFinder.evaluate().where((element) {
      final textWidget = element.widget as Text;
      return textWidget.data != "No categories found";
    }).toList();

    if (validCategoryFinders.isEmpty) {
      debugDumpApp();
      fail(
        "No valid category text found in QuickSendRow after seeding attempt.",
      );
    }

    // Tap the first valid category text
    final firstCategoryText = (validCategoryFinders.first.widget as Text).data;
    print("Tapping category: $firstCategoryText");
    await tester.tap(find.text(firstCategoryText!));

    await tester.pumpAndSettle();

    // 4. Verify Payment Screen
    expect(find.byType(PaymentScreen), findsOneWidget);

    // 5. Fill Transaction Form
    final amountField = find.byType(TextField).at(0); // Amount is usually first
    await tester.enterText(amountField, "150");
    await tester.pumpAndSettle();

    final nameField = find.byType(TextField).at(1); // Name second
    await tester.enterText(nameField, "Test Lunch");
    await tester.pumpAndSettle();

    // 6. Save
    // Find "SEND" button. Use .last to avoid ambiguity.
    final targetButton = find.text("SEND").last;

    await tester.ensureVisible(
      targetButton,
    ); // Scroll validation using ensureVisible
    await tester.tap(targetButton);

    // 7. Verify Success & Return
    await tester.pumpAndSettle();

    // Should be back at Home
    expect(find.byType(BankingHomeScreen), findsOneWidget);

    print("Add Transaction Test Passed: Transaction added successfully.");
  });
}
