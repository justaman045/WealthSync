import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Models/backup_archive.dart';
import 'package:money_control/Services/full_backup_service.dart';

/// Restoring a backup into a *rebuilt* account means the uid changed: the file
/// was taken from `old-uid`, the account signed in now is `new-uid`. Every
/// owner identity field has to move with it, or the restored history is
/// invisible to the uid-filtered queries the app actually uses (sent/received,
/// analytics, split bills) — which is the whole point of the feature.
///
/// The dangerous half is the opposite: `senderId`/`recipientId` can name the
/// *other* person in a shared transaction, so a blind rewrite would credit the
/// restoring account with someone else's money. These pin both directions.
void main() {
  Map<String, dynamic> remap(
    Map<String, dynamic> data, {
    String currentUid = 'new-uid',
    String currentEmail = 'new@example.com',
    String archivedUid = 'old-uid',
    String archivedEmail = 'old@example.com',
  }) => FullBackupService.remapIdentityForRestore(
    data,
    currentEmail: currentEmail,
    currentUid: currentUid,
    archivedEmail: archivedEmail,
    archivedUid: archivedUid,
  );

  group('owner identity moves to the restoring account', () {
    test('a restored expense keeps its sign and gains the new senderId', () {
      final out = remap({
        'amount': -450.0,
        'senderId': 'old-uid',
        'recipientId': '',
        'note': 'coffee',
      });
      expect(out['amount'], -450.0);
      expect(out['senderId'], 'new-uid');
      expect(out['recipientId'], '');
      expect(out['note'], 'coffee');
    });

    test('a restored income gains the new recipientId', () {
      final out = remap({
        'amount': 2500,
        'senderId': '',
        'recipientId': 'old-uid',
      });
      expect(out['senderId'], '');
      expect(out['recipientId'], 'new-uid');
    });

    test('the profile uid and email follow the account', () {
      final out = remap({
        'uid': 'old-uid',
        'email': 'old@example.com',
        'firstName': 'Ada',
      });
      expect(out['uid'], 'new-uid');
      expect(out['email'], 'new@example.com');
      expect(out['firstName'], 'Ada');
    });

    test('a uid field is the owner by definition and always tracks the login',
      () {
      // Even a doc whose uid does not match the archive's (an admin-written
      // record, a migration artefact) belongs to the tree it lives in.
      final out = remap({'uid': 'someone-else'});
      expect(out['uid'], 'new-uid');
    });

    test('with no auth session the email stands in for the uid', () {
      final out = remap(
        {'senderId': 'old-uid'},
        currentUid: '',
        currentEmail: 'new@example.com',
      );
      expect(out['senderId'], 'new@example.com');
    });
  });

  group('the other party is never rewritten', () {
    test('a split bill keeps the friend on the other side', () {
      final out = remap({
        'amount': -300.0,
        'senderId': 'old-uid',
        'recipientId': 'friend-uid',
      });
      expect(out['senderId'], 'new-uid');
      expect(out['recipientId'], 'friend-uid');
    });

    test('a transaction received from a friend keeps their id', () {
      final out = remap({
        'amount': 120.0,
        'senderId': 'friend-uid',
        'recipientId': 'old-uid',
      });
      expect(out['senderId'], 'friend-uid');
      expect(out['recipientId'], 'new-uid');
    });

    test('an unrelated email field is left alone', () {
      final out = remap({'email': 'friend@example.com'});
      expect(out['email'], 'friend@example.com');
    });

    test('a legacy archive with no recorded uid never guesses', () {
      // Guessing which of two ids was the owner is how a restore corrupts data,
      // so with no archived uid the id fields stay exactly as captured.
      final out = remap(
        {'senderId': 'old-uid', 'recipientId': ''},
        archivedUid: '',
      );
      expect(out['senderId'], 'old-uid');
      expect(out['recipientId'], '');
    });
  });

  group('archive format', () {
    const archiveJson = {
      'fileType': 'wealthsync_backup',
      'formatVersion': 2,
      'createdAt': '2026-01-02T03:04:05.000Z',
      'uid': 'old-uid',
      'email': 'old@example.com',
      'profile': {'uid': 'old-uid', 'email': 'old@example.com'},
      'wealthPortfolio': null,
      'collections': {
        'transactions': [
          {'id': 'tx-1', 'amount': -10.0},
        ],
      },
    };

    test('the uid survives a download/restore round trip', () {
      final archive = BackupArchive.fromMap(jsonDecode(jsonEncode(archiveJson)));
      expect(archive.uid, 'old-uid');
      final again = BackupArchive.fromJson(archive.toJson());
      expect(again.uid, 'old-uid');
    });

    test('a format-1 file falls back to the archived profile uid', () {
      final legacy = Map<String, dynamic>.from(archiveJson)
        ..['formatVersion'] = 1
        ..remove('uid');
      expect(BackupArchive.fromMap(legacy).uid, 'old-uid');
    });

    test('a newer format is still refused rather than half-restored', () {
      final future = Map<String, dynamic>.from(archiveJson)
        ..['formatVersion'] = BackupArchive.currentFormatVersion + 1;
      expect(
        () => BackupArchive.fromMap(future),
        throwsA(isA<BackupFormatException>()),
      );
    });
  });
}
