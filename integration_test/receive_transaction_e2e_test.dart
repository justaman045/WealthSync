import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'test_helpers.dart';
import 'package:money_control/Config/app_strings.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgetsWithScreenshots('E2E: Receive Transaction Flow', (WidgetTester tester) async {
    // 1-3. App Launch + Splash/Onboarding + Login
    await launchAndSignIn(tester);

    // 4. Verify Home & Tap "Receive" Button on Balance Card
    await createReceiveTransaction(
      tester,
      name: 'Freelance Client',
      amount: '500',
      category: 'Salary',
    );

    // 7a. Open Categories History via the home section -> "View All".
    // Asserted through AppStrings so the section's copy can change without
    // silently breaking this test (AGENTS.md rule: never re-type the literal).
    await pumpAndSettleSafe(tester);
    final categorySectionRow = find.ancestor(
      of: find.text(AppStrings.categoryHistoryTitle),
      matching: find.byType(Row),
    );
    final viewAllQuickSend = find.descendant(
      of: categorySectionRow,
      matching: find.text(AppStrings.viewAll),
    );
    await tester.ensureVisible(viewAllQuickSend);
    await pumpAndSettleSafe(tester);
    await tester.tap(viewAllQuickSend);
    await pumpAndSettleSafe(tester);

    // Verify we are in CategoriesHistoryScreen
    expect(find.text('Categories History'), findsOneWidget);

    // 7b. Select "Salary" category (default tab is Income)
    await pumpAndSettleSafe(tester);
    expect(find.text('Salary'), findsOneWidget);

    // 7c. Open Transaction List for Category
    await tester.tap(find.text('Salary'));
    await pumpAndSettleSafe(tester);

    // Verify Transaction List Screen
    expect(find.text('Transactions: Salary'), findsOneWidget);
    expect(
      find.text('Freelance Client'),
      findsWidgets,
    ); // Sender name (multiple might exist)

    // 7d. Open Transaction Details
    await tester.tap(find.text('Freelance Client').first);
    await pumpAndSettleSafe(tester);

    // Verify Details Screen
    expect(find.text('Transaction Details'), findsWidgets);
    expect(find.text('Money Received!'), findsOneWidget);
    expect(find.text('Freelance Client'), findsOneWidget);
    expect(find.textContaining('500.00'), findsWidgets);
  });
}
