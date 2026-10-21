import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Services/local_backup_service.dart';

/// The automatic backup overwrites the only local copy it keeps. That is
/// harmless while the data only grows, but after a mass deletion the next
/// write replaces the pre-deletion history with the emptied one — and the
/// recovery path is gone. On 2026-10-21 that exact sequence destroyed 791
/// transactions: the account was wiped, the next write fired the automatic
/// backup, and the only local copy was overwritten with the empty collection.
///
/// These tests pin the shrink-guard: a backup that would hold *fewer*
/// documents than the one already on disk preserves the previous snapshot
/// instead of destroying it.
void main() {
  setUp(LocalBackupService.resetSchedulingForTest);
  tearDown(LocalBackupService.resetSchedulingForTest);

  const email = 'a@b.com';

  /// The two storage slots, as the service addresses them. Taken from the
  /// service itself so the test cannot drift from the key format.
  late String currentKey;
  late String preservedKey;

  /// An in-memory stand-in for the two on-disk snapshots.
  late Map<String, String> store;

  /// A fetch that returns [count] synthetic transactions.
  void serverHas(int count) {
    LocalBackupService.fetchOverride = (_) async => [
      for (var i = 0; i < count; i++)
        {'id': 't$i', 'amount': -10.0},
    ];
  }

  setUp(() {
    store = <String, String>{};
    currentKey = LocalBackupService.debugCurrentKey(email);
    preservedKey = LocalBackupService.debugPreservedKey(email);
    LocalBackupService.writeOverride = (key, data) async {
      store[key] = data;
    };
    LocalBackupService.readOverride = (key) async => store[key];
    LocalBackupService.minInterval = Duration.zero;
  });

  test('a shrinking backup preserves the previous snapshot', () async {
    // The account holds 791 transactions and the mirror reflects that.
    serverHas(791);
    await LocalBackupService.backupUserTransactions(email, reportErrors: false);
    expect(jsonDecode(store[currentKey]!), hasLength(791));
    expect(store.containsKey(preservedKey), isFalse);

    // The account is wiped. The next write fires the automatic backup, which
    // now reads an empty collection.
    serverHas(0);
    await LocalBackupService.backupUserTransactions(email, reportErrors: false);

    // The mirror is emptied ...
    expect(jsonDecode(store[currentKey]!), isEmpty);
    // ... but the pre-deletion history survived.
    expect(jsonDecode(store[preservedKey]!), hasLength(791));
  });

  test('a growing backup does not create a preserved snapshot', () async {
    serverHas(10);
    await LocalBackupService.backupUserTransactions(email, reportErrors: false);

    serverHas(20);
    await LocalBackupService.backupUserTransactions(email, reportErrors: false);

    expect(jsonDecode(store[currentKey]!), hasLength(20));
    // Nothing was lost, so there is nothing to preserve.
    expect(store.containsKey(preservedKey), isFalse);
  });

  test('an equal-size backup does not create a preserved snapshot', () async {
    serverHas(10);
    await LocalBackupService.backupUserTransactions(email, reportErrors: false);

    serverHas(10);
    await LocalBackupService.backupUserTransactions(email, reportErrors: false);

    expect(store.containsKey(preservedKey), isFalse);
  });

  test('the preserved snapshot is never replaced by a smaller one', () async {
    serverHas(100);
    await LocalBackupService.backupUserTransactions(email, reportErrors: false);

    serverHas(10);
    await LocalBackupService.backupUserTransactions(email, reportErrors: false);
    expect(jsonDecode(store[preservedKey]!), hasLength(100));

    // A second, even smaller shrink must not downgrade the preserved copy.
    serverHas(3);
    await LocalBackupService.backupUserTransactions(email, reportErrors: false);
    expect(jsonDecode(store[preservedKey]!), hasLength(100));
  });

  test('the best available snapshot is the larger of mirror and preserved',
      () async {
    serverHas(50);
    await LocalBackupService.backupUserTransactions(email, reportErrors: false);

    serverHas(0);
    await LocalBackupService.backupUserTransactions(email, reportErrors: false);

    final best = await LocalBackupService.bestAvailableBackup(email);
    expect(best, hasLength(50));
  });

  test('hasUserBackup is true when only the preserved snapshot survives',
      () async {
    // The mirror was emptied by a wipe and the shrink-guard kept the history.
    serverHas(50);
    await LocalBackupService.backupUserTransactions(email, reportErrors: false);
    serverHas(0);
    await LocalBackupService.backupUserTransactions(email, reportErrors: false);

    // Without the preserved slot, this reported false and the UI told the
    // user "No local backup found. Tap 'Backup Data' first." — while the
    // data was sitting on the device.
    expect(await LocalBackupService.hasUserBackup(email), isTrue);
    expect(await LocalBackupService.hasPreservedBackup(email), isTrue);
  });

  test('the preserved snapshot is offered separately for an explicit restore',
      () async {
    serverHas(50);
    await LocalBackupService.backupUserTransactions(email, reportErrors: false);
    serverHas(0);
    await LocalBackupService.backupUserTransactions(email, reportErrors: false);

    final preserved =
        await LocalBackupService.readPreservedBackup(email);
    expect(preserved, hasLength(50));
    expect(preserved.first['id'], 't0');
  });

  test('a first-ever backup has nothing to preserve', () async {
    serverHas(5);
    await LocalBackupService.backupUserTransactions(email, reportErrors: false);

    expect(store.containsKey(currentKey), isTrue);
    expect(store.containsKey(preservedKey), isFalse);
  });

  test('the preserved key cannot collide with a real account key', () {
    // An account literally named "preserved_x@y.com" must not share a slot
    // with the preserved snapshot of some other account. A sanitized email
    // never contains a space, which is what makes the marker unambiguous.
    final other = LocalBackupService.debugCurrentKey('preserved_x@y.com');
    expect(other, isNot(preservedKey));
    expect(
      LocalBackupService.debugPreservedKey('a@b.com'),
      isNot(LocalBackupService.debugCurrentKey('a@b.com')),
    );
  });

  test('an unreadable current snapshot does not break the backup', () async {
    // Corrupt payload: the guard must swallow it and still write the mirror.
    store[currentKey] = 'not json at all';
    serverHas(7);

    await LocalBackupService.backupUserTransactions(email, reportErrors: false);

    expect(jsonDecode(store[currentKey]!), hasLength(7));
  });

  test('a failure to preserve does not fail the backup', () async {
    serverHas(20);
    await LocalBackupService.backupUserTransactions(email, reportErrors: false);

    // The preserved write blows up.
    final originalWrite = LocalBackupService.writeOverride!;
    LocalBackupService.writeOverride = (key, data) async {
      if (key == preservedKey) throw Exception('disk full');
      return originalWrite(key, data);
    };
    LocalBackupService.readOverride = (key) async {
      if (key == preservedKey) throw Exception('disk full');
      return store[key];
    };

    serverHas(1);
    await LocalBackupService.backupUserTransactions(email, reportErrors: false);

    // The mirror was still written — a broken guard must not cost the user
    // their backup.
    expect(jsonDecode(store[currentKey]!), hasLength(1));
  });
}
