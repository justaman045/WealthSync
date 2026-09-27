import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'test_helpers.dart';
import 'package:money_control/Config/app_strings.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgetsWithScreenshots('Transaction Management: add, history, edit, delete', (
    WidgetTester tester,
  ) async {
    await launchAndSignIn(tester);

    final receivedName = uniqueName('Recv');
    final sentName = uniqueName('Sent');

    // Add one income and one expense transaction through the UI.
    await createTransaction(
      tester,
      receive: true,
      name: receivedName,
      amount: '800',
      category: 'Salary',
    );
    await createTransaction(
      tester,
      receive: false,
      name: sentName,
      amount: '250',
      category: 'Food',
    );

    // Open Transaction History from the home "Recent Transactions" header.
    // SectionTitle puts its onTap on the trailing 'View All' link (the second
    // one on home — the first belongs to the category-history section).
    await tapUntilMarker(
      tester,
      find.text(AppStrings.viewAll).at(1),
      find.text('Transaction History'),
    );
    expect(find.text('Transaction History'), findsWidgets);

    // Both transactions should be listed.
    await scrollUntilVisible(tester, find.text(sentName));
    expect(find.text(sentName), findsWidgets);
    await scrollUntilVisible(tester, find.text(receivedName));
    expect(find.text(receivedName), findsWidgets);

    // Open the expense transaction details and verify the sign/amount.
    await tapUntilMarker(tester, find.text(sentName).first, find.text('Transaction Details'));
    expect(find.text('Money Sent!'), findsWidgets);
    expect(find.textContaining('250.00'), findsWidgets);

    // Delete it from the details screen (confirm dialog path).
    await deleteCurrentEntry(tester);
    await waitFor(tester, find.text('Transaction History'));
    await pumpReal(tester, const Duration(seconds: 3));
    expect(find.text(sentName), findsNothing);

    // Edit the received transaction: swipe right to reveal the Edit action.
    await swipeAndTap(tester, receivedName, 'Edit', swipeLeft: false);
    await waitFor(tester, find.text('Edit Transaction'));
    expect(find.text('Edit Transaction'), findsOneWidget);

    final amountField = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          double.tryParse(w.controller?.text.replaceAll(',', '') ?? '') ==
              800,
    );
    await tester.enterText(amountField, '950');
    await pumpReal(tester);

    FocusManager.instance.primaryFocus?.unfocus();
    await pumpAndSettleSafe(tester);
    await tapUntilMarker(tester, find.text('Save Changes'), find.text('Transaction History'));
    await pumpReal(tester, const Duration(seconds: 3));

    // Verify the updated amount appears in the history list.
    await scrollUntilVisible(tester, find.textContaining('950.00'));
    expect(find.textContaining('950.00'), findsWidgets);

    // Delete the received transaction via the swipe action path.
    await swipeAndConfirmDelete(tester, receivedName);
    expect(find.text(receivedName), findsNothing);

    await backToHome(tester);
  });
}
