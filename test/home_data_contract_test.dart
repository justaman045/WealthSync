import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Config/feature_flags.dart';

/// Source contracts for the home data-flow fixes.
///
/// The home screen itself is too Firebase-bound to mount in a unit test (see
/// `a11y_semantics_test.dart`), so the wiring that made data stale is pinned
/// here. Each assertion maps to a bug that shipped:
///
///   * the balance disagreed with the wealth builder on taxed transactions,
///   * quick-send ranking was only recomputed when *categories* changed,
///   * pull-to-refresh paused 1.5 s and refreshed nothing,
///   * a dead stream was never re-opened,
///   * the offline queue only replayed at launch/sign-in,
///   * "no transactions yet" was shown before the first snapshot,
///   * hiding the OS widget also stopped persisting the portfolio balance.
String _read(String path) =>
    File(path).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');

void main() {
  group('TransactionController', () {
    final source = _read('lib/Controllers/transaction_controller.dart');

    test('balance uses total (amount - tax), like WealthService', () {
      expect(source, contains('balance += tx.total;'));
      // The old sender/recipient branches subtracted tax only on the sender.
      expect(source, isNot(contains('balance -= tx.amount.abs()')));
    });

    test('transaction changes re-rank the quick-send categories', () {
      // The debounced transaction worker must do both jobs.
      expect(source, contains('fetchSortedCategories(); _updateHomeWidget();'));
    });

    test('refreshData no longer fakes a delay or blanks the cards', () {
      final refresh = _methodBody(source, 'Future<void> refreshData()');
      expect(refresh, isNot(contains('Future.delayed')));
      expect(refresh, isNot(contains('isLoading.value = true')));
      expect(refresh, contains('refreshStreamsIfDead()'));
      expect(refresh, contains('_hydrateStreak()'));
    });

    test('an exhausted retry budget is surfaced instead of shimmering', () {
      expect(source, contains('isStreamDead.value = true;'));
      expect(source, contains('void refreshStreamsIfDead()'));
    });

    test('the streak is hydrated from the user doc', () {
      expect(source, contains('Future<void> _hydrateStreak()'));
      expect(source, contains("data['streakCount']"));
      expect(source, contains("data['lastStreakDate']"));
    });

    test('portfolio balance is written even when the OS widget is hidden', () {
      final update = _methodBody(source, 'void _updateHomeWidget()');
      final portfolio = update.indexOf(
        'WealthService.updateBalance(totalBalance);',
      );
      final killSwitch = update.indexOf("isHidden('home_widget')");
      expect(portfolio, isNonNegative);
      expect(killSwitch, isNonNegative);
      expect(
        portfolio,
        lessThan(killSwitch),
        reason: 'the portfolio write must not sit behind the UI kill-switch',
      );
    });
  });

  group('Home screen refresh', () {
    final source = _read('lib/Screens/homescreen.dart');

    test('pull-to-refresh asks every data owner to refresh', () {
      final refresh = _methodBody(source, 'Future<void> _onRefresh()');
      expect(refresh, contains('syncPendingTransactions()'));
      expect(refresh, contains('_transactionController.refreshData()'));
      expect(refresh, contains('_profileController.refreshFromFirestore()'));
      expect(refresh, contains('checkSubscriptionStatus()'));
      expect(refresh, contains('LentMoneyController'));
    });

    test('the greeting shows a skeleton, not a literal ellipsis', () {
      expect(source, isNot(contains("'...'")));
      expect(source, contains('_namePlaceholder'));
    });

    test('lite mode is reactive', () {
      expect(source, contains('PerformanceController.to.liteMode.value'));
      // The value must be read inside the scroll-view Obx, not at the top of
      // build() where a toggle cannot rebuild it.
      final build = _methodBody(source, 'Widget build(BuildContext context)');
      expect(
        build.indexOf('PerformanceController.to.liteMode.value'),
        greaterThan(build.indexOf('child: Obx(')),
      );
    });
  });

  group('Home widgets', () {
    test('the recent list distinguishes loading from empty', () {
      final source = _read('lib/Components/recent_payment_list.dart');
      final loaded = source.indexOf('hasLoadedOnce');
      final empty = source.indexOf('recentTxs.isEmpty');
      expect(loaded, isNonNegative);
      expect(empty, isNonNegative);
      expect(loaded, lessThan(empty));
      expect(source, contains('isStreamDead'));
    });

    test('the recent list consumes the date-sorted projection', () {
      final source = _read('lib/Components/recent_payment_list.dart');
      // The repository stream is ordered by `createdAt`, so reading it directly
      // put a backdated transaction above a newer one. The widget must read the
      // controller's date-sorted list instead.
      expect(
        source,
        contains('final recentTxs = controller.recentTransactions;'),
      );
    });

    test('the summary strip is admin-toggleable', () {
      final source = _read('lib/Screens/homescreen.dart');
      expect(source, contains("flagKey: 'home_month_summary'"));
      expect(source, contains('HomeMonthSummaryCard()'));
      // Registered in the same change, or the gate falls back to "enabled".
      expect(FeatureFlag.find('home_month_summary'), isNotNull);
    });

    test('the summary card renders amounts through PrivacyText', () {
      final source = _read('lib/Components/home_month_summary.dart');
      expect(source, contains('PrivacyText('));
      expect(source, contains('monthIncomeRx'));
      expect(source, contains('monthSpendRx'));
    });

    test('reconnect replays queued writes and re-opens the stream', () {
      final source = _read('lib/main.dart');
      final reconnect = _methodBody(source, 'void _initReconnectHandling()');
      expect(reconnect, contains('syncPendingTransactions()'));
      expect(reconnect, contains('refreshStreamsIfDead()'));
    });
  });
}

/// Returns the body of a method declaration, starting at its name.
///
/// Brace-matched so an assertion cannot accidentally read a neighbouring
/// method. Falls back to the remainder of the file when no match is found —
/// the caller then fails on a missing `contains`, which is the intent.
String _methodBody(String source, String signature) {
  final start = source.indexOf(signature);
  if (start < 0) return '';
  final open = source.indexOf('{', start);
  if (open < 0) return '';
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final c = source[i];
    if (c == '{') depth++;
    if (c == '}') {
      depth--;
      if (depth == 0) return source.substring(open, i + 1);
    }
  }
  return source.substring(open);
}
