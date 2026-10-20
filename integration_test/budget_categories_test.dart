import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:money_control/Config/app_strings.dart';
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgetsWithScreenshots('Category budgets (adaptive Pro) and category management', (
    WidgetTester tester,
  ) async {
    await launchAndSignIn(tester, account: TestAccount.pro);
    final isPro = await probePro(tester);

    // clearAccountData() wiped the categories collection; the Category Budgets
    // screen renders one card per category, so seed one before navigating.
    await seedCategory(name: 'Food', color: 0xFFFF7043);

    // ── 1. Navigate: Settings → General ─────────────────────────────────────
    await tapNavTab(tester, Icons.tune_rounded, 'Settings');
    await tapUntilMarker(tester, find.text('General'), find.text(AppStrings.setBudget));

    // ── 2. Set Budget (Pro-gated) ───────────────────────────────────────────
    await tapUntilMarker(
      tester,
      find.text(AppStrings.setBudget),
      isPro ? find.text(AppStrings.categoryBudgets) : find.text(AppStrings.budgeting),
    );

    if (isPro) {
      await waitFor(tester, find.text(AppStrings.categoryBudgets));
      // Wait for the category cards to finish loading, then set a limit on the
      // first visible card (no need to know which category it is).
      await waitFor(tester, find.byType(TextFormField));
      final firstField = find.byType(TextFormField).first;
      final firstCard =
          find.ancestor(of: firstField, matching: find.byType(Column)).first;

      await tester.enterText(firstField, '5000');
      await pumpReal(tester);
      FocusManager.instance.primaryFocus?.unfocus();
      await pumpAndSettleSafe(tester);

      await tapWhenVisible(
        tester,
        find.descendant(of: firstCard, matching: find.text('Update')),
      );
      await waitFor(tester, find.textContaining('Budget saved for'));
    } else {
      await waitFor(tester, find.text(AppStrings.budgeting));
      expect(find.text(AppStrings.budgeting), findsWidgets);
    }

    await popScreen(tester); // back to General
    await waitFor(tester, find.text(AppStrings.manageCategories));

    // ── 3. Manage Categories: add + delete a fresh category ────────────────
    await tapUntilMarker(tester, find.text(AppStrings.manageCategories), find.byIcon(Icons.add));

    final catName = uniqueName('Cat');
    await tapUntilMarker(tester, find.byIcon(Icons.add), find.text('New Category'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Category Name'),
      catName,
    );
    await pumpReal(tester);
    await tapWhenVisible(tester, find.text(AppStrings.save));
    await pumpReal(tester, const Duration(seconds: 2));

    // The new tile is appended at the end of the lazy grid — scroll to it.
    await scrollUntilVisible(tester, find.text(catName));
    expect(find.text(catName), findsWidgets);

    // Long-press the tile to delete it (fresh category → usage count 0).
    await longPressItem(tester, find.text(catName));
    await waitFor(tester, find.text('Delete Category'));
    await tapWhenVisible(tester, find.widgetWithText(TextButton, 'Delete'));
    await pumpReal(tester, const Duration(seconds: 3));
    expect(find.text(catName), findsNothing);

    await popScreen(tester); // back to General
    await waitFor(tester, find.text(AppStrings.setBudget));
    await popScreen(tester); // back to Settings tab

    // ── 4. Back to the home tab ─────────────────────────────────────────────
    await tapNavTab(tester, Icons.grid_view_rounded, AppStrings.totalBalance);
    expect(find.text(AppStrings.totalBalance), findsWidgets);
  });
}
