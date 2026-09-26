import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Services/local_backup_service.dart';

/// The write paths call [LocalBackupService.backupUserTransactions] after every
/// add/edit/delete, and each call is a full server-side read of the whole
/// transactions collection. These tests pin the scheduling that keeps that from
/// degrading into one read per write, using the `fetchOverride` seam so no live
/// backend is involved.
void main() {
  setUp(LocalBackupService.resetSchedulingForTest);
  tearDown(LocalBackupService.resetSchedulingForTest);

  Future<void> backup([String email = 'a@b.com']) =>
      LocalBackupService.backupUserTransactions(email, reportErrors: false);

  setUp(() {
    LocalBackupService.writeOverride = (_, __) async {};
  });

  test('empty email is a no-op and never reads', () async {
    var fetches = 0;
    LocalBackupService.fetchOverride = (_) async {
      fetches++;
      return <Map<String, dynamic>>[];
    };

    await LocalBackupService.backupUserTransactions('', reportErrors: false);

    expect(fetches, 0);
  });

  test('concurrent writes coalesce instead of one read per write', () async {
    var fetches = 0;
    LocalBackupService.minInterval = Duration.zero;
    LocalBackupService.fetchOverride = (_) async {
      fetches++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return <Map<String, dynamic>>[];
    };

    await Future.wait([for (var i = 0; i < 5; i++) backup()]);

    // One read for the burst, plus at most one trailing read to pick up writes
    // that landed while the first read was in flight — never five.
    expect(fetches, lessThanOrEqualTo(2));
  });

  test('a write during an in-flight read is not dropped', () async {
    final gate = Completer<void>();
    var fetches = 0;
    LocalBackupService.minInterval = Duration.zero;
    LocalBackupService.fetchOverride = (_) async {
      fetches++;
      await gate.future;
      return <Map<String, dynamic>>[];
    };

    final first = backup();
    await Future<void>.delayed(Duration.zero);
    // Piggybacks on the in-flight run, so it must not be awaited before the
    // gate opens or the test deadlocks against its own first future.
    final second = backup();
    gate.complete();
    await Future.wait([first, second]);

    expect(fetches, 2);
  });

  test('separate accounts are tracked independently', () async {
    var fetches = 0;
    LocalBackupService.minInterval = Duration.zero;
    LocalBackupService.fetchOverride = (_) async {
      fetches++;
      return <Map<String, dynamic>>[];
    };

    await Future.wait([backup('one@b.com'), backup('two@b.com')]);

    expect(fetches, 2);
  });

  test('a write inside the throttle window is flushed by a trailing run',
      () async {
    var fetches = 0;
    LocalBackupService.minInterval = const Duration(milliseconds: 100);
    LocalBackupService.fetchOverride = (_) async {
      fetches++;
      return <Map<String, dynamic>>[];
    };

    await backup();
    expect(fetches, 1, reason: 'first write reads straight away');

    await backup();
    expect(fetches, 1, reason: 'inside the window, so no read yet');

    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(fetches, 2, reason: 'trailing run flushes the dirty write');
  });

  test('force reads inside the throttle window instead of deferring', () async {
    var fetches = 0;
    LocalBackupService.minInterval = const Duration(seconds: 30);
    LocalBackupService.fetchOverride = (_) async {
      fetches++;
      return <Map<String, dynamic>>[];
    };

    await backup();
    expect(fetches, 1);

    await LocalBackupService.backupUserTransactions('a@b.com', force: true);

    expect(fetches, 2, reason: 'the explicit Settings action must really read');
  });
}
