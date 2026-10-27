import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:money_control/Config/app_strings.dart';
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgetsWithScreenshots('E2E: Subscription Flow (Add, Edit, Pay, Verify)', (
    WidgetTester tester,
  ) async {
    // 1-3. App Launch + Splash/Onboarding + Login
    await launchAndSignIn(tester, account: TestAccount.pro);

    final isPro = await probePro(tester);

    // 4. Navigate to Subscriptions (Recurring Payments) via the AppBar's ⋮ menu.
    // Pro/trial accounts open the feature; free accounts hit the upgrade gate.
    await tapHomeOverflowItem(tester, Icons.event_repeat);
    await waitFor(
      tester,
      isPro ? find.text(AppStrings.subscriptions) : find.text(AppStrings.monthly),
    );

    if (!isPro) {
      await assertUpgradeScreen(tester);
      return;
    }

    await waitFor(tester, find.text(AppStrings.subscriptions));
    expect(find.text(AppStrings.subscriptions), findsOneWidget);
    await waitFor(tester, find.text('Add Subscription'));
    // While the list is empty the screen shows the label twice: the FAB and the
    // empty-state action (CI wipes the account, so it is always empty there).
    // Tap the FAB explicitly rather than the ambiguous text.
    expect(find.text('Add Subscription'), findsWidgets);
    await tapUntilMarker(
      tester,
      find.widgetWithText(FloatingActionButton, 'Add Subscription'),
      find.text('New Subscription'),
    );
    expect(find.text('New Subscription'), findsOneWidget);

    final name = uniqueName('NetflixTest');
    await tester.enterText(find.byType(TextFormField).at(0), name);
    await pumpReal(tester);
    await tester.enterText(find.byType(TextFormField).at(1), '499');
    await pumpReal(tester);

    // Save — then wait for the sheet to actually close (its 'New Subscription'
    // title matches the still-open sheet's TextField, so it can't be the
    // success marker) and the new card to render with its amount. Dismiss the
    // keyboard first so the sheet's height is stable under the tap, then retry
    // the save if the sheet lingers (the Firestore write can briefly stall).
    FocusManager.instance.primaryFocus?.unfocus();
    await pumpAndSettleSafe(tester);
    var saved = false;
    for (var attempt = 0; attempt < 3 && !saved; attempt++) {
      await tapWhenVisible(tester, find.text(AppStrings.save));
      saved = await waitForGoneCheck(
        tester,
        find.text('New Subscription'),
        seconds: 12,
      );
      if (!saved) await pumpReal(tester, const Duration(seconds: 2));
    }
    expect(find.text('New Subscription'), findsNothing);
    await waitFor(tester, find.text('₹499'));

    // Verify Creation
    expect(find.text(name), findsWidgets);
    expect(find.text('₹499'), findsWidgets);

    // 6. Edit Subscription (Change Date)
    // Scope the edit icon to the card we just created — the list holds many
    // payments and `.first` may resolve to an unrelated card.
    final card = find
        .ancestor(of: find.text(name), matching: find.byType(GestureDetector))
        .first;
    final editIcon = find
        .descendant(of: card, matching: find.byIcon(Icons.edit_rounded))
        .first;
    await tapUntilMarker(tester, editIcon, find.text('Edit Subscription'));
    expect(find.text('Edit Subscription'), findsOneWidget);

    // Tap Date Picker Row
    await tapWhenVisible(tester, find.byIcon(Icons.calendar_today));

    // Pick '28' if available, otherwise accept the default, then confirm.
    if (find.text('28').evaluate().isNotEmpty) {
      await tester.tap(find.text('28'));
      await pumpReal(tester);
    }
    await tapWhenVisible(tester, find.text('OK'));

    // Save
    await tapWhenVisible(tester, find.text(AppStrings.save));

    // 7. Pay (Mark as Paid)
    await tapUntilMarker(
      tester,
      find.text(name).first,
      find.text('Subscription Details'),
    );
    expect(find.text('Subscription Details'), findsOneWidget);

    await tapUntilMarker(tester, find.text('Mark Paid'), find.text('Confirm'));

    // Confirm Dialog
    expect(find.text('Confirm'), findsOneWidget);
    await tapUntilMarker(
      tester,
      find.text('Confirm'),
      find.text('Payment History'),
    );

    // Check History List for transaction
    await pumpReal(
      tester,
      const Duration(seconds: 3),
    ); // Wait for Firestore update
    expect(find.text('Payment History'), findsOneWidget);
    expect(find.textContaining('499'), findsWidgets);

    // 8. Verify Home Screen Reflection
    await tapWhenVisible(
      tester,
      find.byIcon(Icons.arrow_back_ios_new_rounded),
    );
    await tapUntilMarker(
      tester,
      find.byIcon(Icons.arrow_back_ios_new_rounded),
      find.text(AppStrings.totalBalance),
    );
    expect(find.text(AppStrings.totalBalance), findsOneWidget);

    // Perform Pull-to-Refresh to ensure list is updated
    await dragToRefresh(tester);

    await waitFor(tester, find.text(name, skipOffstage: false));
    expect(find.text(name, skipOffstage: false), findsWidgets);
    expect(find.textContaining('499', skipOffstage: false), findsWidgets);

    // 9. Verify Details from Home
    await tapUntilMarker(
      tester,
      find.text(name).first,
      find.text('Transaction Details'),
    );
    expect(find.text('Transaction Details'), findsWidgets);
    expect(find.text('Money Sent!'), findsWidgets);
    expect(find.text(name), findsOneWidget);
  });
}
