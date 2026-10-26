import 'dart:convert';
import 'dart:io';


import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Services/backup_cipher.dart';
import 'package:money_control/Services/local_backup_service.dart';

/// The on-device mirror is a complete copy of the user's transaction history and
/// used to sit in the app sandbox as plain JSON while the privacy policy
/// promised encryption. `test/backup_cipher_test.dart` covers the envelope
/// itself; these tests cover the *wiring*, which is the part that silently
/// regresses: that the mirror — and the preserved pre-deletion slot beside it —
/// really go through it on the way to disk, and that the read path still hands
/// the user's documents back.
///
/// The three existing seams (`fetchOverride`/`writeOverride`/`readOverride`)
/// all short-circuit *before* the cipher, which is why this group uses
/// `backupDirOverride` and the real file path instead. A test built on the
/// write seam would stay green if the seal were dropped.
void main() {
  late Directory tempDir;

  Map<String, dynamic> tx(
    String id, {
    double amount = -100,
    String note = 'Coffee',
  }) =>
      {
        'id': id,
        'amount': amount,
        'note': note,
        // The real `_fetchAll` converts Firestore types to JSON-safe values
        // before this point, so the mirror only ever holds encodable data.
        'date': '2026-01-02T00:00:00.000Z',
      };

  Future<File> slot(String name) async => File('${tempDir.path}/$name');

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wealthsync_mirror_test');
    LocalBackupService.resetSchedulingForTest();
    LocalBackupService.backupDirOverride = () async => tempDir;
    // No keystore on a test host: pin a known key so the seal/open pair is
    // exercised for real instead of falling back to plaintext.
    BackupCipher.useKeyForTest(List<int>.filled(32, 7));
  });

  tearDown(() async {
    LocalBackupService.resetSchedulingForTest();
    BackupCipher.resetForTest();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('the on-device mirror is sealed', () {
    test('the file on disk is an envelope, not the user\'s JSON', () async {
      LocalBackupService.fetchOverride = (_) async => [tx('t1'), tx('t2')];

      await LocalBackupService.backupUserTransactions(
        'a@b.com',
        reportErrors: false,
        force: true,
      );

      final raw = await (await slot('tx_a_b_com.json')).readAsString();
      expect(
        BackupCipher.isSealed(raw),
        isTrue,
        reason: 'the mirror sat in the sandbox as plain JSON — the whole point '
            'of BackupCipher is that it does not',
      );
      expect(raw.contains('Coffee'), isFalse);
      expect(raw.contains('"amount"'), isFalse);
    });

    test('a sealed mirror still reads back as the same documents', () async {
      LocalBackupService.fetchOverride =
          (_) async => [tx('t1'), tx('t2', note: 'Bus')];

      await LocalBackupService.backupUserTransactions(
        'a@b.com',
        reportErrors: false,
        force: true,
      );

      final restored =
          await LocalBackupService.readUserTransactionsBackup('a@b.com');
      expect(restored, hasLength(2));
      expect(
        restored.map((e) => e['note']),
        containsAll(<String>['Coffee', 'Bus']),
      );
      expect(await LocalBackupService.hasUserBackup('a@b.com'), isTrue);
    });

    test('the preserved pre-deletion slot is sealed too', () async {
      LocalBackupService.fetchOverride =
          (_) async => [tx('a'), tx('b'), tx('c')];
      await LocalBackupService.backupUserTransactions(
        'a@b.com',
        reportErrors: false,
        force: true,
      );

      // A mass deletion: the next run holds fewer documents, so the previous
      // snapshot moves into the preserved slot.
      LocalBackupService.fetchOverride = (_) async => [tx('a')];
      await LocalBackupService.backupUserTransactions(
        'a@b.com',
        reportErrors: false,
        force: true,
      );

      final preserved = await (await slot('txprev_a_b_com.json')).readAsString();
      expect(
        BackupCipher.isSealed(preserved),
        isTrue,
        reason: 'a second plaintext full copy would defeat the first seal',
      );
      expect(preserved.contains('Coffee'), isFalse);

      // …and it is still the copy the restore path picks, i.e. sealing did not
      // cost the recovery path its data.
      final best = await LocalBackupService.bestAvailableBackup('a@b.com');
      expect(best, hasLength(3));
    });

    test('a payload this install cannot open reads as "no backup"', () async {
      // A file written by another install (different keystore key), or one
      // corrupted on disk. It must not throw and must not present the user with
      // a decode error they cannot act on.
      await (await slot('tx_a_b_com.json')).writeAsString(
        '${BackupCipher.prefix}${base64Encode(List<int>.filled(48, 9))}',
      );

      expect(
        await LocalBackupService.readUserTransactionsBackup('a@b.com'),
        isEmpty,
      );
      expect(await LocalBackupService.hasUserBackup('a@b.com'), isFalse);
    });

    test('a legacy plaintext mirror still restores and is re-sealed', () async {
      // The pre-encryption file must keep working: "an unreadable backup is the
      // failure this whole area exists to prevent" applies to old files too.
      await (await slot('tx_a_b_com.json'))
          .writeAsString(jsonEncode([tx('old', note: 'Legacy')]));

      final read =
          await LocalBackupService.readUserTransactionsBackup('a@b.com');
      expect(read, hasLength(1));
      expect(read.single['note'], 'Legacy');

      LocalBackupService.fetchOverride = (_) async => [tx('old'), tx('new')];
      await LocalBackupService.backupUserTransactions(
        'a@b.com',
        reportErrors: false,
        force: true,
      );

      final raw = await (await slot('tx_a_b_com.json')).readAsString();
      expect(BackupCipher.isSealed(raw), isTrue);
    });
  });
}
