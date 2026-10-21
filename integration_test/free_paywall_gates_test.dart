import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:money_control/Config/app_strings.dart';
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Runs on the FREE account. launchAndSignIn() forces trialEndDate to the past
  // and subscriptionStatus='free', so a stale/lapsed account can never
  // silently grant a trial and skip these gates.
  testWidgetsWithScreenshots('Free paywall gates', (WidgetTester tester) async {
    await launchAndSignIn(tester);

    // ── 1. Home AppBar Pro-gated shortcuts all route to the paywall ─────────
    // Each of these is behind its own admin kill-switch (recurring,
    // lent_money, forecast, goals). When an admin sets one to `hidden` the
    // button is removed for everyone, so requiring it unconditionally hung the
    // test on the full timeout. Assert the paywall for whichever are present
    // and skip the hidden ones — the gate can only be tested where it exists.
    var gatedChecked = 0;
    for (final icon in <IconData>[
      Icons.event_repeat, // Subscriptions (recurring payments)
      Icons.handshake_outlined, // Lent Money
      Icons.trending_up, // Forecast
      Icons.flag_outlined, // Goals
    ]) {
      if (!await isVisible(tester, find.byIcon(icon))) continue;
      await tapWhenVisible(tester, find.byIcon(icon));
      await assertUpgradeScreen(tester); // asserts paywall, closes back home
      gatedChecked++;
    }
    // A totally flag-stripped home screen would make this test vacuous.
    expect(
      gatedChecked,
      greaterThan(0),
      reason: 'no Pro-gated AppBar shortcut was present to verify',
    );

    // ── 2. QR FAB is Pro-gated too ──────────────────────────────────────────
    // Gated by `qr_scan`; skip when an admin has hidden it.
    if (await isVisible(tester, find.byIcon(Icons.qr_code_scanner))) {
      await tapWhenVisible(tester, find.byIcon(Icons.qr_code_scanner));
      await assertUpgradeScreen(tester);
    }

    // ── 3. Budgets: Settings → General → Set Budget shows the lock ─────────
    await tapNavTab(tester, Icons.tune_rounded, 'Settings');
    await tapUntilMarker(tester, find.text('General'), find.text(AppStrings.setBudget));
    await tapUntilMarker(tester, find.text(AppStrings.setBudget), find.text(AppStrings.budgeting));
    expect(find.text(AppStrings.budgeting), findsWidgets);
    expect(find.text(AppStrings.upgradeToPro), findsWidgets);
    await popScreen(tester); // back to General
    await waitFor(tester, find.text(AppStrings.manageCategories));

    // Pop back to the Settings root so the bottom nav bar is reachable again
    // (tapNavTab needs it to switch tabs — the General subpage has none).
    await popScreen(tester); // General → Settings root
    await waitFor(tester, find.text('Data & Support'));

    // NOTE: the SMS Import gate (Settings → Automation) is intentionally NOT
    // covered here — SmsImportScreen requests READ_SMS in initState, which pops
    // an un-dismissable Android system dialog on the CI emulator.

    // ── 4. Analytics exports are Pro-gated behind the ⋮ menu ────────────────
    await tapNavTab(
      tester,
      Icons.pie_chart_outline_rounded,
      'Analytics & Reports',
    );
    for (final entry in <(String, String)>[
      ('Export CSV', 'Data Export'),
      ('Tax Summary PDF', 'Tax Summary'),
      ('Share Report', 'Share Report'),
    ]) {
      await tapWhenVisible(tester, find.byIcon(Icons.more_vert));
      await tapWhenVisible(tester, find.text(entry.$1));
      await waitFor(tester, find.text(entry.$2));
      expect(find.text(entry.$2), findsWidgets);
      await dismissDialogs(tester); // closes the ProLock bottom sheet
      await pumpReal(tester);
    }

    // ── 5. Back home ────────────────────────────────────────────────────────
    await tapNavTab(tester, Icons.grid_view_rounded, AppStrings.totalBalance);
    expect(find.text(AppStrings.totalBalance), findsWidgets);
  });
}
