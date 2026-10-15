import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Services/income_settings.dart';
import 'package:money_control/Services/savings_settings.dart';
import 'package:money_control/Services/sms_service.dart';
import 'package:money_control/Utils/wealth_math.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `AuthController.disposeUserScopedState()` is the single teardown list shared
/// by the explicit sign-out path and `main.dart`'s `_handleAuthChange`. That
/// list has already drifted twice (a missing `AuditController`, an unawaited
/// cache clear), so this contract pins the *side-effectful* clears that a
/// future edit could silently drop:
///
/// * `LocalCacheService.clearAll()` — else the next account reads the previous
///   account's cached data.
/// * `OfflineQueueService.clearPending()` — the queue file is device-global
///   (not user-scoped), so a leftover queue is replayed by the next account's
///   `syncPendingTransactions()` into the *new* account.
/// * `SmsService.resetCache()` / `RecurringService.resetCache()` — Hive-backed
///   static caches that survive a controller delete.
///
/// `flutter analyze` cannot catch a missing call and neither can any widget
/// test, so this is a deliberate source scan (same rationale as
/// `early_return_guard_test.dart`).
String _extractFunctionBody(String source, String signature) {
  final start = source.indexOf(signature);
  if (start < 0) return '';
  final open = source.indexOf('{', start);
  if (open < 0) return '';
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final c = source[i];
    if (c == '{') {
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0) return source.substring(open, i + 1);
    }
  }
  return '';
}

void main() {
  test('disposeUserScopedState clears every user-scoped side effect', () {
    final source =
        File('lib/Controllers/auth_controller.dart').readAsStringSync();
    final body = _extractFunctionBody(
      source,
      'static Future<void> disposeUserScopedState()',
    );
    expect(body, isNotEmpty, reason: 'could not locate disposeUserScopedState');

    for (final call in const [
      'LocalCacheService.clearAll()',
      'OfflineQueueService.clearPending()',
      'SmsService.resetCache()',
      'RecurringService.resetCache()',
      'IncomeSettings.reset()',
      'SavingsSettings.reset()',
    ]) {
      expect(
        body.contains(call),
        isTrue,
        reason: 'disposeUserScopedState must call $call',
      );
    }
  });

  test('SmsService.resetCache clears the persistent learning prefs', () async {
    SharedPreferences.setMockInitialValues({
      'user_custom_sms_rules': '{"Food":["myshop"]}',
      'category_corrections': '{"myshop":{"category":"Food","count":3}}',
      'unrelated_key': 'keep',
    });
    await SmsService.resetCache();
    final prefs = await SharedPreferences.getInstance();
    // Device-global learning caches must go, or the next account inherits them.
    expect(prefs.getString('user_custom_sms_rules'), isNull);
    expect(prefs.getString('category_corrections'), isNull);
    // Unrelated prefs are untouched.
    expect(prefs.getString('unrelated_key'), 'keep');
  });

  test('IncomeSettings.reset clears prefs and restores defaults', () async {
    SharedPreferences.setMockInitialValues({
      IncomeSettings.modeKey: 'manual',
      IncomeSettings.manualKey: 90000.0,
    });
    await IncomeSettings.load();
    expect(IncomeSettings.mode.value, IncomeMode.manual);
    expect(IncomeSettings.manualMonthly.value, 90000.0);

    await IncomeSettings.reset();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(IncomeSettings.modeKey), isNull);
    expect(prefs.getDouble(IncomeSettings.manualKey), isNull);
    expect(IncomeSettings.mode.value, IncomeMode.autoBlend);
    expect(IncomeSettings.manualMonthly.value, 0.0);
  });

  test('SavingsSettings.reset clears prefs and restores the default', () async {
    SharedPreferences.setMockInitialValues({SavingsSettings.rateKey: 42});
    await SavingsSettings.load();
    expect(SavingsSettings.percent.value, 42);

    await SavingsSettings.reset();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(SavingsSettings.rateKey), isNull);
    expect(SavingsSettings.percent.value, SavingsSettings.defaultPercent);
  });

  test('the extractor returns a non-empty body for a real method', () {
    // Guard the guard: a broken extractor returning '' would make the checks
    // above vacuous if they were only `isNot(contains(...))`.
    final body = _extractFunctionBody(
      'class A {\n  void f() {\n    doThing();\n  }\n}',
      'void f()',
    );
    expect(body, contains('doThing();'));
  });
}
