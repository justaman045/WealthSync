import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:money_control/Components/settings_widgets.dart';
import 'package:money_control/Config/app_strings.dart';
import 'package:money_control/main.dart' as app;
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // General settings: currency round-trip, dark-mode round-trip, and the About
  // screen. Every toggle is restored so later files see a deterministic state.
  testWidgetsWithScreenshots('Misc settings: currency, dark mode, about app', (
    WidgetTester tester,
  ) async {
    await launchAndSignIn(tester);
    await tapNavTab(tester, Icons.tune_rounded, 'Settings');
    await tapUntilMarker(tester, find.text('General'), find.text('Currency (INR)'));

    // ── 1. Currency: INR → USD → INR ────────────────────────────────────────
    await tapWhenVisible(tester, find.text('Currency (INR)'));
    await waitFor(tester, find.text('Select Currency'));
    await tapWhenVisible(tester, find.text('USD (\$)'));
    await waitFor(tester, find.text('Currency (USD)'));
    expect(find.text('Currency (USD)'), findsWidgets);

    await tapWhenVisible(tester, find.text('Currency (USD)'));
    await waitFor(tester, find.text('Select Currency'));
    await tapWhenVisible(tester, find.text('INR (₹)'));
    await waitFor(tester, find.text('Currency (INR)'));
    expect(find.text('Currency (INR)'), findsWidgets);

    // ── 2. Dark Mode: toggle on, verify, toggle back ────────────────────────
    final darkSwitch = find.descendant(
      of: find.ancestor(of: find.text('Dark Mode'), matching: find.byType(SettingsTile)),
      matching: find.byType(Switch),
    );
    await scrollUntilVisible(tester, darkSwitch);
    // The theme is a device-level preference that outlives sign-out and the
    // account wipe, so an earlier file (or a previous run on this install) may
    // have left dark mode on. Normalise before asserting the toggle round-trip.
    if (tester.widget<Switch>(darkSwitch).value) {
      await tester.tap(darkSwitch, warnIfMissed: false);
      await pumpAndSettleSafe(tester);
    }
    expect(tester.widget<Switch>(darkSwitch).value, isFalse);

    await tester.tap(darkSwitch, warnIfMissed: false);
    await pumpAndSettleSafe(tester);
    expect(app.themeController.themeMode, ThemeMode.dark);

    await tester.tap(darkSwitch, warnIfMissed: false);
    await pumpAndSettleSafe(tester);
    expect(app.themeController.themeMode, isNot(ThemeMode.dark));

    // ── 3. About App (Settings → Data & Support) ────────────────────────────
    await popScreen(tester); // General → Settings
    await waitFor(tester, find.text('Data & Support'));
    await tapUntilMarker(tester, find.text('Data & Support'), find.text('About App'));
    await tapWhenVisible(tester, find.text('About App'));
    await waitFor(tester, find.text('About Application'));
    expect(find.text('Acknowledgements'), findsWidgets);
    await popScreen(tester); // About → Data & Support
    await waitFor(tester, find.text('Backup Data'));
    await popScreen(tester); // Data & Support → Settings
    await waitFor(tester, find.text('General'));

    await tapNavTab(tester, Icons.grid_view_rounded, AppStrings.totalBalance);
    await waitForHome(tester);
  });
}
