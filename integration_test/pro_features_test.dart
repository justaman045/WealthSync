import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:money_control/Config/app_strings.dart';
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Runs on the PRO account (PRO_TEST_EMAIL, configured with
  // subscriptionStatus:'pro' in the Firebase console). Verifies that the
  // home AppBar Pro shortcuts open their real screens — NOT the paywall —
  // i.e. the subscription state genuinely unlocks the features. No data is
  // mutated here (the adaptive tests on this account exercise the add/edit/
  // delete flows).
  testWidgetsWithScreenshots('Pro unlocks real screens (recurring, lent, goals, forecast)', (
    WidgetTester tester,
  ) async {
    await launchAndSignIn(tester, account: TestAccount.pro);

    await tapHomeOverflowItem(tester, Icons.event_repeat);
    await waitFor(tester, find.text(AppStrings.subscriptions));
    expect(find.text(AppStrings.subscriptions), findsWidgets);
    await popScreen(tester);
    await waitForHome(tester);

    await tapHomeOverflowItem(tester, Icons.handshake_outlined);
    await waitFor(tester, find.text(AppStrings.lentMoneyTracker));
    expect(find.text(AppStrings.lentMoneyTracker), findsWidgets);
    await popScreen(tester);
    await waitForHome(tester);

    await tapHomeOverflowItem(tester, Icons.flag_outlined);
    await waitFor(tester, find.text(AppStrings.goals));
    expect(find.text(AppStrings.goals), findsWidgets);
    await popScreen(tester);
    await waitForHome(tester);

    await tapHomeOverflowItem(tester, Icons.trending_up);
    await waitFor(tester, find.text('Monthly Forecast'));
    expect(find.text('Monthly Forecast'), findsWidgets);
    await popScreen(tester);
    await waitForHome(tester);
  });
}
