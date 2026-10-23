import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:money_control/Config/app_strings.dart';
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgetsWithScreenshots('Lent Money Tracker + Split Bill (adaptive Pro)', (
    WidgetTester tester,
  ) async {
    await launchAndSignIn(tester, account: TestAccount.pro);
    final isPro = await probePro(tester);

    // Pro-gated entry point, in the home AppBar's ⋮ menu.
    await tapHomeOverflowItem(tester, Icons.handshake_outlined);
    await waitFor(
      tester,
      isPro
          ? find.text(AppStrings.lentMoneyTracker)
          : find.text(AppStrings.monthly),
    );

    if (!isPro) {
      await assertUpgradeScreen(tester);
      return;
    }

    await waitFor(tester, find.text(AppStrings.lentMoneyTracker));
    expect(find.text('Owed to You'), findsWidgets);

    // ── 1. Add a lent entry ─────────────────────────────────────────────────
    final friendA = uniqueName('Amit');
    await tapUntilMarker(
      tester,
      find.text(AppStrings.add),
      find.text(AppStrings.lentToFriend),
    );

    await tester.enterText(find.widgetWithText(TextField, '0.00'), '2000');
    await pumpReal(tester);
    await tester.enterText(
      find.widgetWithText(TextField, "Friend's Name"),
      friendA,
    );
    await pumpReal(tester);

    FocusManager.instance.primaryFocus?.unfocus();
    await pumpAndSettleSafe(tester);
    await tapUntilMarker(tester, find.text('Save Entry'), find.text(friendA));

    expect(find.text(friendA), findsWidgets);

    // ── 2. Split a bill (creates N lent entries) ────────────────────────────
    await tapUntilMarker(
      tester,
      find.byIcon(Icons.call_split_rounded),
      find.text('Split a Bill'),
    );

    final p1 = uniqueName('Ravi');
    final p2 = uniqueName('Neha');
    await tester.enterText(
      find.widgetWithText(TextField, '0.00').first,
      '300',
    );
    await pumpReal(tester);

    final nameFields = find.widgetWithText(TextField, 'Name');
    await tester.enterText(nameFields.at(0), p1);
    await pumpReal(tester);
    await tester.enterText(nameFields.at(1), p2);
    await pumpReal(tester);

    FocusManager.instance.primaryFocus?.unfocus();
    await pumpAndSettleSafe(tester);
    await tapUntilMarker(tester, find.text('Create Split Entries'), find.text(p1));

    // Both participants become lent entries on the tracker list.
    expect(find.text(p1), findsWidgets);
    expect(find.text(p2), findsWidgets);

    // ── 3. Clean up all three entries ───────────────────────────────────────
    await swipeAndConfirmDelete(tester, p2);
    await swipeAndConfirmDelete(tester, p1);
    await swipeAndConfirmDelete(tester, friendA);
    expect(find.text(p1), findsNothing);
    expect(find.text(p2), findsNothing);
    expect(find.text(friendA), findsNothing);

    await backToHome(tester);
  });
}
