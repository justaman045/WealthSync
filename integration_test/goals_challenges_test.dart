import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:money_control/Config/app_strings.dart';
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgetsWithScreenshots(
    'Goals (adaptive Pro) and Savings Challenges full flow',
    (WidgetTester tester) async {
      await launchAndSignIn(tester, account: TestAccount.pro);
      final isPro = await probePro(tester);

      // ── 1. Goals (pro-gated home icon) ──────────────────────────────────────
      await tapUntilMarker(
        tester,
        find.byIcon(Icons.flag_outlined),
        isPro ? find.text(AppStrings.goals) : find.text(AppStrings.monthly),
      );

      if (isPro) {
        await waitFor(tester, find.text(AppStrings.goals));
        expect(find.text(AppStrings.goals), findsWidgets);

        final goalName = uniqueName('Goal');
        await tapUntilMarker(
          tester,
          find.text(AppStrings.newGoal),
          find.widgetWithText(TextField, 'e.g. Emergency Fund, New iPhone'),
        );

        await tester.enterText(
          find.widgetWithText(TextField, 'e.g. Emergency Fund, New iPhone'),
          goalName,
        );
        await pumpReal(tester);
        await tester.enterText(find.widgetWithText(TextField, '0.00'), '10000');
        await pumpReal(tester);

        FocusManager.instance.primaryFocus?.unfocus();
        await pumpAndSettleSafe(tester);
        await tapUntilMarker(
          tester,
          find.text(AppStrings.createGoal),
          find.text(goalName),
        );

        // Back on the goals list; the new goal card shows 0% progress and the
        // aggregate "Total Progress" summary card is rendered above the list.
        await waitFor(tester, find.text(goalName));
        expect(find.text('0%'), findsWidgets);
        expect(find.text(AppStrings.totalProgress), findsWidgets);

        // ── Edit the goal via the card's overflow menu ──────────────────────
        var goalCard = find
            .ancestor(
              of: find.text(goalName),
              matching: find.byType(GestureDetector),
            )
            .first;
        await waitFor(tester, goalCard);
        await tapWhenVisible(
          tester,
          find.descendant(of: goalCard, matching: find.byIcon(Icons.more_vert)),
        );
        await waitFor(tester, find.text(AppStrings.edit));
        await tapWhenVisible(tester, find.text(AppStrings.edit));

        // The edit screen prefills the existing name and saves in place.
        await waitFor(tester, find.text(AppStrings.editGoal));
        final renamedGoal = uniqueName('Renamed');
        await tester.enterText(
          find.widgetWithText(TextField, goalName),
          renamedGoal,
        );
        await pumpReal(tester);
        FocusManager.instance.primaryFocus?.unfocus();
        await pumpAndSettleSafe(tester);
        await tapUntilMarker(
          tester,
          find.text(AppStrings.saveChanges),
          find.text(renamedGoal),
        );
        await waitFor(tester, find.text(renamedGoal));
        expect(find.text(goalName), findsNothing);
        expect(find.text(AppStrings.totalProgress), findsWidgets);

        // Long-press the renamed card to delete it. The text alone may match a
        // transient SnackBar, so wait for the actual card (GestureDetector).
        goalCard = find
            .ancestor(
              of: find.text(renamedGoal),
              matching: find.byType(GestureDetector),
            )
            .first;
        await waitFor(tester, goalCard);
        await longPressItem(tester, goalCard);
        await waitFor(tester, find.text('Delete Goal?'));
        await tapWhenVisible(tester, find.text(AppStrings.delete));
        await pumpReal(tester, const Duration(seconds: 3));
        expect(find.text(renamedGoal), findsNothing);

        await backToHome(tester);
      } else {
        await assertUpgradeScreen(tester);
      }

      // ── 2. Savings Challenges (gated by the `challenges` kill-switch) ───────
      // Make sure we are truly back on the home screen and no overlay (SnackBar
      // from the goal deletion, etc.) is swallowing the AppBar tap. The emoji
      // icon lives only on the home AppBar and the Challenges screen itself.
      await waitFor(tester, find.text(AppStrings.totalBalance));
      await dismissDialogs(tester);
      if (!await isVisible(tester, find.byIcon(Icons.emoji_events_outlined))) {
        // An admin has `challenges` hidden, so the entry point is removed for
        // everyone. Skip rather than hang for the file timeout — the app is
        // behaving per the feature-flag contract. Re-enable it from Settings →
        // Admin Utils → Feature Flags to exercise this section.
        return;
      }
      // The challenges button is the rightmost AppBar action; on the narrow
      // CI emulator its center sits within 24px of the screen edge, which the
      // default tap margin rejects. Use a tighter margin for this tap.
      await tapUntilMarker(
        tester,
        find.byIcon(Icons.emoji_events_outlined).first,
        find.text('Savings Challenges'),
        tapMargin: 8,
      );
      expect(find.text('Active'), findsWidgets);
      expect(find.text('Library'), findsWidgets);

      final challengeName = uniqueName('Save');
      await tapUntilMarker(
        tester,
        find.text('Custom'),
        find.text('Custom Challenge'),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Challenge Name'),
        challengeName,
      );
      await pumpReal(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Or enter custom days'),
        '14',
      );
      await pumpReal(tester);

      FocusManager.instance.primaryFocus?.unfocus();
      await pumpAndSettleSafe(tester);
      await tapUntilMarker(
        tester,
        find.text('Start Challenge'),
        find.text(challengeName),
      );

      // The custom challenge appears on the Active tab with days remaining.
      expect(find.text(challengeName), findsWidgets);
      expect(find.textContaining('d left'), findsWidgets);

      // Delete it via the close button on the challenge's own card.
      final nameRow = find
          .ancestor(of: find.text(challengeName), matching: find.byType(Row))
          .first;
      await tapWhenVisible(
        tester,
        find.descendant(of: nameRow, matching: find.byIcon(Icons.close)),
      );
      await pumpReal(tester, const Duration(seconds: 3));
      expect(find.text(challengeName), findsNothing);

      await backToHome(tester);
    },
  );
}
