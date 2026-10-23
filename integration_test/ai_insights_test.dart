import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:money_control/Config/app_strings.dart';
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgetsWithScreenshots('AI Insights full flow', (
    WidgetTester tester,
  ) async {
    final sw = Stopwatch()..start();
    void mark(String step) {
      debugPrint('AI_STEP ${sw.elapsed.inSeconds}s: $step');
    }

    await launchAndSignIn(tester);
    mark('signed in');

    // Seed one expense so the insights engine has data to aggregate (it shows a
    // no-data message otherwise). A single expense is enough for the forecast
    // and category insights — the income seeding step was dropped because it
    // pushed the file's runtime onto the emulator's ~7m software-GL crash line.
    await createTransaction(
      tester,
      receive: false,
      name: uniqueName('Ana'),
      amount: '500',
    );
    mark('transaction created');

    // ── 1. AI Insights tab ──────────────────────────────────────────────────
    await tapNavTab(
      tester,
      Icons.auto_awesome_outlined,
      AppStrings.aiInsights,
    );
    mark('AI tab tapped');
    await waitFor(tester, find.text(AppStrings.aiForecastTitle));
    expect(find.text(AppStrings.aiForecastTitle), findsWidgets);
    mark('forecast visible');

    await scrollUntilVisible(tester, find.textContaining('Category Insights'));
    expect(find.textContaining('Category Insights'), findsWidgets);
    mark('category insights visible');

    // ── 2. Back to the home tab ─────────────────────────────────────────────
    await tapNavTab(tester, Icons.grid_view_rounded, AppStrings.totalBalance);
    expect(find.text(AppStrings.totalBalance), findsWidgets);
    mark('back home');
  });
}
