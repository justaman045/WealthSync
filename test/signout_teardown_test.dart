import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
    ]) {
      expect(
        body.contains(call),
        isTrue,
        reason: 'disposeUserScopedState must call $call',
      );
    }
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
