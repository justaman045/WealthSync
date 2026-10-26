import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Models/backup_archive.dart';
import 'package:money_control/Services/backup_cipher.dart';
import 'package:money_control/Services/full_backup_service.dart';
import 'package:money_control/Services/user_service.dart';

/// The backup archive is the only thing standing between a user and permanent
/// data loss — on 2026-10-21 the integration harness deleted 791 transactions
/// from a live account and nothing was recoverable. These tests pin the two
/// properties that make the archive trustworthy:
///
///   1. it refuses anything that is not one of our backups (rather than
///      "restoring" 0 documents and reporting success), and
///   2. a capture -> serialize -> parse round trip preserves every document,
///      including the Firestore types (Timestamp/GeoPoint/reference) that a
///      naive `toString()` would destroy.
void main() {
  group('BackupArchive format guard', () {
    test('rejects a non-JSON file with an actionable message', () {
      expect(
        () => BackupArchive.fromJson('this is not json'),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.message,
            'message',
            contains('not valid JSON'),
          ),
        ),
      );
    });

    test('rejects valid JSON that is not a WealthSync backup', () {
      // A plausible wrong pick: the GDPR export, which has no fileType.
      final gdpr = jsonEncode({
        'exported_at': '2026-10-21T00:00:00Z',
        'user_email': 'a@b.com',
        'transactions': [],
      });
      expect(
        () => BackupArchive.fromJson(gdpr),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.message,
            'message',
            contains('not a WealthSync backup'),
          ),
        ),
      );
    });

    test('rejects a JSON array (no container)', () {
      expect(
        () => BackupArchive.fromJson('[1,2,3]'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('refuses an archive from a newer format version', () {
      final future = jsonEncode({
        'fileType': BackupArchive.fileType,
        'formatVersion': BackupArchive.currentFormatVersion + 1,
        'createdAt': '2026-10-21T00:00:00Z',
        'email': 'a@b.com',
        'collections': <String, dynamic>{},
      });
      expect(
        () => BackupArchive.fromJson(future),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.message,
            'message',
            contains('newer version'),
          ),
        ),
      );
    });

    test('accepts a current-version archive', () {
      final ok = jsonEncode({
        'fileType': BackupArchive.fileType,
        'formatVersion': BackupArchive.currentFormatVersion,
        'createdAt': '2026-10-21T06:00:00Z',
        'email': 'a@b.com',
        'collections': {
          'transactions': [
            {BackupArchive.idField: 't1', 'amount': -100},
          ],
        },
      });
      final archive = BackupArchive.fromJson(ok);
      expect(archive.email, 'a@b.com');
      expect(archive.documentCount, 1);
      expect(archive.collections['transactions']!.first['amount'], -100);
    });

    test('tolerates a missing profile / portfolio without throwing', () {
      final ok = jsonEncode({
        'fileType': BackupArchive.fileType,
        'formatVersion': BackupArchive.currentFormatVersion,
        'createdAt': '2026-10-21T06:00:00Z',
        'email': 'a@b.com',
        'profile': null,
        'wealthPortfolio': null,
        'collections': <String, dynamic>{},
      });
      final archive = BackupArchive.fromJson(ok);
      expect(archive.profile, isNull);
      expect(archive.wealthPortfolio, isNull);
      expect(archive.documentCount, 0);
    });
  });

  group('BackupArchive serialization', () {
    test('round-trips every collection and document', () {
      final archive = BackupArchive(
        formatVersion: BackupArchive.currentFormatVersion,
        createdAt: DateTime.utc(2026, 10, 21, 6, 30),
        email: 'aman@example.com',
        profile: {'firstName': 'Aman', 'subscriptionStatus': 'pro'},
        wealthPortfolio: {'balance': 12.5},
        collections: {
          'transactions': [
            {BackupArchive.idField: 'tx1', 'amount': -250.0, 'category': 'Food'},
            {BackupArchive.idField: 'tx2', 'amount': 9000.0, 'category': 'Salary'},
          ],
          'goals': [
            {BackupArchive.idField: 'g1', 'targetAmount': 50000},
          ],
          'categories': const [],
        },
      );

      final restored = BackupArchive.fromJson(archive.toJson());

      expect(restored.email, archive.email);
      expect(restored.createdAt, archive.createdAt);
      expect(restored.documentCount, 3);
      expect(restored.populatedCollections, {'transactions': 2, 'goals': 1});
      expect(restored.profile, {'firstName': 'Aman', 'subscriptionStatus': 'pro'});
      expect(restored.collections['transactions']![1]['amount'], 9000.0);
    });

    test('documentCount ignores empty collections but keeps them', () {
      final archive = BackupArchive(
        formatVersion: BackupArchive.currentFormatVersion,
        createdAt: DateTime.utc(2026),
        email: 'a@b.com',
        profile: null,
        wealthPortfolio: null,
        collections: {
          'transactions': const [],
          'goals': [
            {BackupArchive.idField: 'g', 'targetAmount': 1},
          ],
        },
      );
      expect(archive.documentCount, 1);
      expect(archive.collections.containsKey('transactions'), isTrue);
    });

    test('suggested filename is timestamped and unique per second', () {
      final a = FullBackupService.suggestedFileName(DateTime.utc(2026, 1, 2, 3, 4, 5));
      final b = FullBackupService.suggestedFileName(DateTime.utc(2026, 1, 2, 3, 4, 6));
      expect(a, 'WealthSync_backup_20260102_030405.json');
      expect(a, isNot(b));
    });
  });

  group('Firestore type preservation', () {
    test('__ts__ envelope survives JSON and revives to a Timestamp', () {
      final safe = FullBackupService.debugJsonSafe({
        'createdAt': DateTime.utc(2026, 10, 21, 6, 0),
      });
      // Must become a JSON-safe value, not an object Dart cannot encode.
      expect(jsonEncode(safe), isA<String>());

      final revived = FullBackupService.debugRevive(
        jsonDecode(jsonEncode(safe)) as Map<String, dynamic>,
      );
      // A real Timestamp, not a string — Firestore would reject a String in a
      // field the app reads with `as Timestamp`.
      expect(revived['createdAt'], isA<Timestamp>());
      expect(
        (revived['createdAt'] as Timestamp).toDate().toUtc(),
        DateTime.utc(2026, 10, 21, 6, 0),
      );
    });

    test('__geo__ envelope survives JSON', () {
      final safe = FullBackupService.debugJsonSafe({
        'location': {'__geo__': {'lat': 19.07, 'lng': 72.87}},
      });
      final revived = FullBackupService.debugRevive(
        jsonDecode(jsonEncode(safe)) as Map<String, dynamic>,
      );
      final geo = revived['location'];
      expect(geo, isA<GeoPoint>());
      expect((geo as GeoPoint).latitude, closeTo(19.07, 1e-9));
      expect(geo.longitude, closeTo(72.87, 1e-9));
    });

    test('a bare ISO string in a date field is revived to a Timestamp', () {
      final revived = FullBackupService.debugRevive({
        'date': '2026-10-21T06:00:00.000Z',
      });
      expect(revived['date'], isA<Timestamp>());
      expect(
        (revived['date'] as Timestamp).toDate().toUtc(),
        DateTime.utc(2026, 10, 21, 6, 0),
      );
    });

    test('free text that LOOKS like a date is NOT converted', () {
      // This exact class of bug shipped once: a note reading
      // "2026-01-15T10:00 was the party" became a corrupted Timestamp.
      final revived = FullBackupService.debugRevive({
        'note': '2026-01-15T10:00 was the party',
        'description': '2026-01-15T10:00',
        'address': '2026-01-15T10:00 Lane',
      });
      expect(revived['note'], '2026-01-15T10:00 was the party');
      expect(revived['description'], '2026-01-15T10:00');
      expect(revived['address'], '2026-01-15T10:00 Lane');
    });

    test('date-field detection agrees with the free-text denylist', () {
      expect(FullBackupService.debugIsDateField('createdAt'), isTrue);
      expect(FullBackupService.debugIsDateField('nextDueDate'), isTrue);
      expect(FullBackupService.debugIsDateField('timestamp'), isTrue);
      expect(FullBackupService.debugIsDateField('note'), isFalse);
      expect(FullBackupService.debugIsDateField('name'), isFalse);
      expect(FullBackupService.debugIsDateField('recipientName'), isFalse);
    });

    test('nested lists and maps keep their dates', () {
      final safe = FullBackupService.debugJsonSafe({
        'payments': [
          {'paidOn': DateTime.utc(2026, 1, 1), 'note': '2026-01-01T00:00 x'},
        ],
      });
      final revived = FullBackupService.debugRevive(
        jsonDecode(jsonEncode(safe)) as Map<String, dynamic>,
      );
      final first = (revived['payments'] as List).first as Map;
      expect(first['paidOn'], isA<Timestamp>());
      expect(
        (first['paidOn'] as Timestamp).toDate().toUtc(),
        DateTime.utc(2026, 1, 1),
      );
      expect(first['note'], '2026-01-01T00:00 x');
    });
  });

  group('capture covers the whole account', () {
    setUp(FullBackupService.resetForTest);
    tearDown(FullBackupService.resetForTest);

    test('captures EVERY UserService collection, not just transactions', () async {
      FullBackupService.fetchCollectionOverride = (email, collection) async {
        return [
          {BackupArchive.idField: '$collection-1', 'v': 1},
        ];
      };
      FullBackupService.fetchProfileOverride = (_) async => {'firstName': 'A'};
      FullBackupService.fetchPortfolioOverride = (_) async => {'balance': 5};

      final archive = await FullBackupService.capture('a@b.com');

      // The regression that caused the incident: a backup that covers only
      // transactions is not a backup.
      for (final collection in UserService.subcollections) {
        expect(
          archive.collections.containsKey(collection),
          isTrue,
          reason: '$collection missing from the archive',
        );
      }
      expect(archive.collections.length, UserService.subcollections.length);
      expect(archive.documentCount, UserService.subcollections.length);
      expect(archive.profile, {'firstName': 'A'});
      expect(archive.wealthPortfolio, {'balance': 5});
    });

    test('one failing collection does not abort the whole backup', () async {
      final failures = <String>[];
      FullBackupService.fetchCollectionOverride = (email, collection) async {
        if (collection == 'goals') throw Exception('permission-denied');
        return [
          {BackupArchive.idField: 'x', 'v': 1},
        ];
      };
      FullBackupService.fetchProfileOverride = (_) async => null;
      FullBackupService.fetchPortfolioOverride = (_) async => null;

      final archive = await FullBackupService.capture(
        'a@b.com',
        onCollectionError: (c, _) => failures.add(c),
      );

      expect(failures, ['goals']);
      expect(archive.collections['goals'], isEmpty);
      // Everything else still captured — a partial backup beats none.
      expect(archive.collections['transactions'], isNotEmpty);
      expect(
        archive.documentCount,
        UserService.subcollections.length - 1,
      );
    });

    test('a failed profile read is surfaced, not silently nulled', () async {
      final failures = <String>[];
      FullBackupService.fetchCollectionOverride = (_, __) async => [];
      FullBackupService.fetchProfileOverride = (_) async =>
          throw Exception('offline');
      FullBackupService.fetchPortfolioOverride = (_) async => null;

      final archive = await FullBackupService.capture(
        'a@b.com',
        onCollectionError: (c, _) => failures.add(c),
      );

      expect(failures, contains('profile'));
      expect(archive.profile, isNull);
    });
  });

  group('restore writes every collection back', () {
    setUp(FullBackupService.resetForTest);
    tearDown(FullBackupService.resetForTest);

    test('writes profile, portfolio and each collection', () async {
      // Use only the write seam so no Firebase instance is needed.
      final writes = <String, Map<String, dynamic>>{};
      FullBackupService.writeOverride = (path, data) async {
        writes[path] = data;
      };
      final invalidated = <String>[];
      FullBackupService.cacheInvalidateOverride = (key) async {
        invalidated.add(key);
      };

      // Restore of subcollections uses the SDK batch directly, so this test
      // asserts the parts reachable through the seam plus the counting logic.
      final archive = BackupArchive(
        formatVersion: BackupArchive.currentFormatVersion,
        createdAt: DateTime.utc(2026),
        email: 'a@b.com',
        profile: {'firstName': 'Aman'},
        wealthPortfolio: {'balance': 1.0},
        collections: const {},
      );

      final result = await FullBackupService.restore(archive);

      expect(writes.keys, containsAll(['users/a@b.com', 'users/a@b.com/wealth/portfolio']));
      expect(result.written['profile'], 1);
      expect(result.written['wealth_portfolio'], 1);
      expect(result.hasFailures, isFalse);

      // Stale caches after a restore would show the pre-restore account on the
      // next screen load, so the invalidation keys must match what the
      // controllers actually cache under (`<name>_<email>`).
      expect(invalidated, contains('transactions_a@b.com'));
      expect(invalidated, contains('goals_a@b.com'));
      expect(
        invalidated.length,
        FullBackupService.debugCacheKeys('a@b.com').length,
      );
    });

    test('an unknown collection in the archive is skipped, not failed', () async {
      FullBackupService.writeOverride = (_, __) async {};
      FullBackupService.cacheInvalidateOverride = (_) async {};
      final archive = BackupArchive(
        formatVersion: BackupArchive.currentFormatVersion,
        createdAt: DateTime.utc(2026),
        email: 'a@b.com',
        profile: null,
        wealthPortfolio: null,
        collections: {
          'some_future_collection': [
            {BackupArchive.idField: 'x', 'v': 1},
          ],
        },
      );

      final result = await FullBackupService.restore(archive);

      expect(result.failed, isEmpty);
      expect(result.written.containsKey('some_future_collection'), isFalse);
    });
  });

  group('restore of subcollections', () {
    setUp(FullBackupService.resetForTest);
    tearDown(FullBackupService.resetForTest);

    BackupArchive archiveWith(List<Map<String, dynamic>> docs) =>
        BackupArchive(
          formatVersion: BackupArchive.currentFormatVersion,
          createdAt: DateTime.utc(2026),
          email: 'a@b.com',
          profile: null,
          wealthPortfolio: null,
          collections: {'transactions': docs},
        );

    test('every document is written with its original id', () async {
      final written = <String, Map<String, dynamic>>{};
      FullBackupService.batchWriteOverride = (email, collection, docs) async {
            for (final doc in docs) {
              written[doc['_docId'] as String] =
                  doc['_data'] as Map<String, dynamic>;
            }
          };
      FullBackupService.cacheInvalidateOverride = (_) async {};

      final result = await FullBackupService.restore(
        archiveWith([
          {BackupArchive.idField: 'tx-1', 'amount': -10, 'note': 'a'},
          {BackupArchive.idField: 'tx-2', 'amount': -20, 'note': 'b'},
        ]),
      );

      expect(result.written['transactions'], 2);
      expect(result.failed, isEmpty);
      // The id is the document's identity in the user's account — a restore
      // that invents a new one leaves the original behind as an orphan.
      expect(written.keys, containsAll(['tx-1', 'tx-2']));
      expect(written['tx-1']!['note'], 'a');
      // The bookkeeping id must not be written as a field.
      expect(written['tx-1']!.containsKey(BackupArchive.idField), isFalse);
    });

    test('a rejected batch falls back to one document at a time', () async {
      // The Firestore rules reject a transaction that is missing `amount`,
      // `date`, `senderId` or `recipientId`. A batch is atomic, so one such
      // document must not take 399 good ones down with it.
      FullBackupService.batchWriteOverride = (email, collection, docs) async {
            throw Exception('PERMISSION_DENIED: some documents were invalid');
          };
      final individuallyWritten = <String>[];
      FullBackupService.docWriteOverride =
          (email, collection, docId, data) async {
            // Exactly one document is the bad one.
            if (docId == 'tx-bad') {
              throw Exception('PERMISSION_DENIED: missing required fields');
            }
            individuallyWritten.add(docId);
          };
      FullBackupService.cacheInvalidateOverride = (_) async {};

      final result = await FullBackupService.restore(
        archiveWith([
          {BackupArchive.idField: 'tx-1', 'amount': -10},
          {BackupArchive.idField: 'tx-bad', 'amount': -20},
          {BackupArchive.idField: 'tx-3', 'amount': -30},
        ]),
      );

      // The good ones came back.
      expect(individuallyWritten, containsAll(['tx-1', 'tx-3']));
      expect(result.written['transactions'], 2);

      // And the loss is reported rather than swallowed.
      expect(result.hasFailures, isTrue);
      expect(result.failed.containsKey('transactions'), isTrue);
    });

    test('a failed batch is never reported as restored', () async {
      // The bug this pins: the document count was incremented as documents
      // were added to the batch, so a batch the server rejected was reported
      // as "N restored" when nothing was written at all.
      FullBackupService.batchWriteOverride = (email, collection, docs) async {
            throw Exception('PERMISSION_DENIED');
          };
      FullBackupService.docWriteOverride =
          (email, collection, docId, data) async {
            throw Exception('PERMISSION_DENIED');
          };
      FullBackupService.cacheInvalidateOverride = (_) async {};

      final result = await FullBackupService.restore(
        archiveWith([
          {BackupArchive.idField: 'tx-1', 'amount': -10},
          {BackupArchive.idField: 'tx-2', 'amount': -20},
        ]),
      );

      expect(result.written['transactions'], 0);
      expect(result.totalWritten, 0);
      expect(result.hasFailures, isTrue);
    });

    test('a document the server rejects is named in the failure', () async {
      FullBackupService.batchWriteOverride = (email, collection, docs) async {
            throw Exception('PERMISSION_DENIED');
          };
      final rejected = <String>[];
      FullBackupService.docWriteOverride =
          (email, collection, docId, data) async {
            if (docId == 'tx-bad') {
              rejected.add(docId);
              throw Exception('PERMISSION_DENIED');
            }
          };
      FullBackupService.cacheInvalidateOverride = (_) async {};

      final result = await FullBackupService.restore(
        archiveWith([
          {BackupArchive.idField: 'tx-bad', 'amount': -20},
          {BackupArchive.idField: 'tx-ok', 'amount': -30},
        ]),
      );

      expect(rejected, ['tx-bad']);
      expect(result.written['transactions'], 1);
      expect('${result.failed['transactions']}', contains('1 of 2'));
    });

    test('a transient failure is not retried 400 times over', () async {
      // The batch never reached the server (the network dropped). Retrying
      // it document by document would fail the same way 400 times, so the
      // chunk is reported as failed and the restore moves on.
      FullBackupService.batchWriteOverride = (email, collection, docs) async {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'unavailable',
              message: 'backend unavailable',
            );
          };
      var individualWrites = 0;
      FullBackupService.docWriteOverride =
          (email, collection, docId, data) async {
            individualWrites++;
          };
      FullBackupService.cacheInvalidateOverride = (_) async {};

      final result = await FullBackupService.restore(
        archiveWith([
          {BackupArchive.idField: 'tx-1', 'amount': -10},
          {BackupArchive.idField: 'tx-2', 'amount': -20},
        ]),
      );

      expect(individualWrites, 0);
      expect(result.written['transactions'], 0);
      expect(result.hasFailures, isTrue);
    });

    test('the restore writes into the account signed in NOW', () async {
      // The whole point of the feature: rebuild a deleted account. The user
      // signs up again (maybe with a different address) and restores their
      // old file. Writing to the *archived* address would be denied by
      // `firestore.rules` — an owner may only write their own document — so
      // the restore would silently write nothing.
      final writes = <String, Map<String, dynamic>>{};
      FullBackupService.writeOverride = (path, data) async {
        writes[path] = data;
      };
      FullBackupService.cacheInvalidateOverride = (_) async {};
      FullBackupService.signedInEmailOverride = 'new-account@example.com';

      final archive = BackupArchive(
        formatVersion: BackupArchive.currentFormatVersion,
        createdAt: DateTime.utc(2026),
        email: 'old-account@example.com',
        profile: {'firstName': 'Aman'},
        wealthPortfolio: null,
        collections: const {},
      );

      await FullBackupService.restore(archive);

      expect(writes.keys, contains('users/new-account@example.com'));
      expect(writes.keys, isNot(contains('users/old-account@example.com')));
    });
  });

  group('profile hygiene', () {
    setUp(FullBackupService.resetForTest);
    tearDown(FullBackupService.resetForTest);

    // A Pro user whose profile the archive captured verbatim.
    Map<String, dynamic> proProfile() => {
          'firstName': 'Aman',
          'lastName': 'Ojha',
          'phone': '8586047520',
          'address': 'Hindalco Colony',
          'dob': Timestamp.fromDate(DateTime.utc(1990, 1, 1)),
          'photoURL': 'https://example.com/a.png',
          'subscriptionStatus': 'pro',
          'isPro': true,
          'trialEndDate': Timestamp.fromDate(DateTime.utc(2026, 12, 1)),
          'trialUsed': true,
          'planType': 'yearly',
          'expiryDate': Timestamp.fromDate(DateTime.utc(2027, 1, 1)),
          'purchaseToken': 'secret-purchase-token',
          'isAdmin': true,
          'referredBy': 'AMANYB',
          'referralCount': 4,
          'referralCode': 'AMANXYZ',
        };

    test('capture redacts the purchase credential from the file', () async {
      FullBackupService.fetchCollectionOverride = (_, __) async => [];
      FullBackupService.fetchProfileOverride = (_) async => proProfile();
      FullBackupService.fetchPortfolioOverride = (_) async => null;

      final archive = await FullBackupService.capture('a@b.com');

      // The downloaded file is meant to be emailed around or dropped in a
      // cloud drive. A purchase token in it is a purchase token in someone's
      // inbox.
      expect(archive.profile!.containsKey('purchaseToken'), isFalse);

      // The rest of the document is an honest record of the account.
      expect(archive.profile!['firstName'], 'Aman');
      expect(archive.profile!['subscriptionStatus'], 'pro');
    });

    test('the written file never contains the purchase credential', () async {
      FullBackupService.fetchCollectionOverride = (_, __) async => [];
      FullBackupService.fetchProfileOverride = (_) async => proProfile();
      FullBackupService.fetchPortfolioOverride = (_) async => null;

      final archive = await FullBackupService.capture('a@b.com');
      final json = archive.toJson();

      expect(json.contains('secret-purchase-token'), isFalse);
      expect(json.contains('purchaseToken'), isFalse);
    });

    test('restore does not write entitlement or identity fields back',
        () async {
      final writes = <String, Map<String, dynamic>>{};
      FullBackupService.writeOverride = (path, data) async {
        writes[path] = data;
      };
      FullBackupService.cacheInvalidateOverride = (_) async {};

      final archive = BackupArchive(
        formatVersion: BackupArchive.currentFormatVersion,
        createdAt: DateTime.utc(2026),
        email: 'a@b.com',
        profile: proProfile(),
        wealthPortfolio: null,
        collections: const {},
      );

      final result = await FullBackupService.restore(archive);

      expect(result.hasFailures, isFalse);

      final written = writes['users/a@b.com']!;
      for (final field in BackupArchive.serverAuthoritativeProfileFields) {
        expect(
          written.containsKey(field),
          isFalse,
          reason: '$field must not be written back by a restore',
        );
      }
    });

    test('restore still writes the personal details', () async {
      final writes = <String, Map<String, dynamic>>{};
      FullBackupService.writeOverride = (path, data) async {
        writes[path] = data;
      };
      FullBackupService.cacheInvalidateOverride = (_) async {};

      final archive = BackupArchive(
        formatVersion: BackupArchive.currentFormatVersion,
        createdAt: DateTime.utc(2026),
        email: 'a@b.com',
        profile: proProfile(),
        wealthPortfolio: null,
        collections: const {},
      );

      await FullBackupService.restore(archive);

      // The whole point of the profile in the archive is that a rebuilt
      // account is usable. Stripping entitlement must not cost the user
      // their name and phone.
      final written = writes['users/a@b.com']!;
      expect(written['firstName'], 'Aman');
      expect(written['lastName'], 'Ojha');
      expect(written['phone'], '8586047520');
      expect(written['address'], 'Hindalco Colony');
      expect(written['dob'], isA<Timestamp>());
      expect(written['photoURL'], 'https://example.com/a.png');

      // The user's own referral code is their identity, not an entitlement,
      // so it is restored — that is what lets a rebuilt account still be
      // referred to.
      expect(written['referralCode'], 'AMANXYZ');
    });

    test('a stale backup cannot strip a paying user of their plan', () async {
      // The scenario the stripping exists for: a backup taken BEFORE the
      // purchase says 'free'. Restoring it must not write that back over a
      // live 'pro' — the live value survives because the restore is a merge
      // that does not mention the field.
      final writes = <String, Map<String, dynamic>>{};
      FullBackupService.writeOverride = (path, data) async {
        writes[path] = data;
      };
      FullBackupService.cacheInvalidateOverride = (_) async {};

      final staleBackup = BackupArchive(
        formatVersion: BackupArchive.currentFormatVersion,
        createdAt: DateTime.utc(2025),
        email: 'a@b.com',
        profile: {
          'firstName': 'Aman',
          'subscriptionStatus': 'free',
          'isPro': false,
        },
        wealthPortfolio: null,
        collections: const {},
      );

      await FullBackupService.restore(staleBackup);

      final written = writes['users/a@b.com']!;
      expect(written.containsKey('subscriptionStatus'), isFalse);
      expect(written.containsKey('isPro'), isFalse);
      expect(written['firstName'], 'Aman');
    });

    test('the redaction helpers are pure and do not mutate their input',
        () {
      final original = proProfile();
      final snapshot = Map<String, dynamic>.from(original);

      final redacted = BackupArchive.redactProfileForArchive(original);
      final stripped =
          BackupArchive.stripServerAuthoritativeFields(original);

      expect(original, snapshot, reason: 'the input map was mutated');
      expect(redacted.containsKey('purchaseToken'), isFalse);
      expect(redacted['firstName'], 'Aman');
      expect(
        stripped.containsKey('subscriptionStatus'),
        isFalse,
      );
      expect(stripped.containsKey('isAdmin'), isFalse);
      expect(stripped.containsKey('referredBy'), isFalse);
      expect(stripped.containsKey('referralCount'), isFalse);
    });
  });

  group('automatic device snapshot', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('wealthsync_backup_test');
      FullBackupService.snapshotDirOverride = () async => tempDir;
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    /// An archive holding [count] documents in the transactions collection.
    BackupArchive archiveWith(int count) => BackupArchive(
          formatVersion: BackupArchive.currentFormatVersion,
          createdAt: DateTime.utc(2026),
          email: 'a@b.com',
          profile: null,
          wealthPortfolio: null,
          collections: {
            'transactions': [
              for (var i = 0; i < count; i++) {BackupArchive.idField: 't$i'},
            ],
          },
        );

    test('a written snapshot reads back with its documents intact', () async {
      final written = await FullBackupService.writeLocalSnapshot(
        archiveWith(12),
      );
      expect(written, isTrue);

      final read = await FullBackupService.readLocalSnapshot('a@b.com');
      expect(read, isNotNull);
      expect(read!.documentCount, 12);
      expect(read.collections['transactions'], hasLength(12));
    });

    test('a smaller snapshot does not overwrite a larger stored one',
        () async {
      await FullBackupService.writeLocalSnapshot(archiveWith(791));

      // The account was wiped and the next snapshot sees an empty collection.
      // Overwriting here would destroy the only complete copy — the exact
      // trap the local transaction mirror fell into on 2026-10-21.
      final written = await FullBackupService.writeLocalSnapshot(archiveWith(0));
      expect(written, isFalse);

      final read = await FullBackupService.readLocalSnapshot('a@b.com');
      expect(read!.documentCount, 791);
    });

    test('a larger snapshot replaces a smaller stored one', () async {
      await FullBackupService.writeLocalSnapshot(archiveWith(3));

      final written = await FullBackupService.writeLocalSnapshot(archiveWith(20));
      expect(written, isTrue);

      final read = await FullBackupService.readLocalSnapshot('a@b.com');
      expect(read!.documentCount, 20);
    });

    test('an equal-size snapshot refreshes the stored one', () async {
      await FullBackupService.writeLocalSnapshot(archiveWith(5));

      // Equal counts are not a shrink. The account may have lost one
      // transaction and gained another, and the fresher snapshot is the
      // accurate one — so it replaces the stored copy rather than being
      // rejected.
      final written = await FullBackupService.writeLocalSnapshot(archiveWith(5));
      expect(written, isTrue);

      final read = await FullBackupService.readLocalSnapshot('a@b.com');
      expect(read!.documentCount, 5);
    });

    test('no snapshot means no snapshot', () async {
      expect(await FullBackupService.hasLocalSnapshot('a@b.com'), isFalse);
      expect(await FullBackupService.readLocalSnapshot('a@b.com'), isNull);
    });

    test('an empty snapshot does not count as a snapshot', () async {
      await FullBackupService.writeLocalSnapshot(archiveWith(0));

      // Nothing to restore from, so the UI must not offer it.
      expect(await FullBackupService.hasLocalSnapshot('a@b.com'), isFalse);
    });

    test('a corrupt snapshot file is reported as absent, not thrown', () async {
      await FullBackupService.writeLocalSnapshot(archiveWith(4));

      // Simulate a truncated write (a kill mid-write before the rename).
      final files = await tempDir.list().toList();
      for (final f in files) {
        if (f is File) {
          await f.writeAsString('{"fileType": "wealthsync_backup", "trunc');
        }
      }

      expect(await FullBackupService.readLocalSnapshot('a@b.com'), isNull);
      expect(await FullBackupService.hasLocalSnapshot('a@b.com'), isFalse);
    });

    test('snapshots of different accounts do not overwrite each other',
        () async {
      await FullBackupService.writeLocalSnapshot(archiveWith(7));

      final other = BackupArchive(
        formatVersion: BackupArchive.currentFormatVersion,
        createdAt: DateTime.utc(2026),
        email: 'other@b.com',
        profile: null,
        wealthPortfolio: null,
        collections: {
          'transactions': [
            {BackupArchive.idField: 'o1'},
          ],
        },
      );
      await FullBackupService.writeLocalSnapshot(other);

      expect(
        (await FullBackupService.readLocalSnapshot('a@b.com'))!.documentCount,
        7,
      );
      expect(
        (await FullBackupService.readLocalSnapshot('other@b.com'))!
            .documentCount,
        1,
      );
    });

    test('the snapshot is sealed at rest and still reads back', () async {
      // Whole-account copy on disk: it must not be a readable JSON dump in the
      // app sandbox (root, `adb backup`, a stolen unlocked phone).
      BackupCipher.useKeyForTest(List<int>.generate(32, (i) => i));
      addTearDown(BackupCipher.resetForTest);

      expect(await FullBackupService.writeLocalSnapshot(archiveWith(9)), isTrue);

      final files = await tempDir
          .list()
          .where((e) => e.path.endsWith('.json'))
          .toList();
      expect(files, hasLength(1));
      final raw = await File(files.single.path).readAsString();
      expect(raw.startsWith(BackupCipher.prefix), isTrue);
      expect(raw.contains('transactions'), isFalse);
      expect(raw.contains('a@b.com'), isFalse);

      final read = await FullBackupService.readLocalSnapshot('a@b.com');
      expect(read, isNotNull);
      expect(read!.documentCount, 9);
    });

    test('a sealed snapshot whose key is gone reads as "no snapshot"',
        () async {
      BackupCipher.useKeyForTest(List<int>.generate(32, (i) => i));
      await FullBackupService.writeLocalSnapshot(archiveWith(4));
      // Simulate a wiped keystore (device restore, factory reset of the
      // keystore entry): the file is there but unauthentic.
      BackupCipher.useKeyForTest(List<int>.generate(32, (i) => 255 - i));
      addTearDown(BackupCipher.resetForTest);

      expect(await FullBackupService.readLocalSnapshot('a@b.com'), isNull);
      expect(await FullBackupService.hasLocalSnapshot('a@b.com'), isFalse);
      // And a fresh snapshot replaces it rather than being refused as a shrink.
      expect(await FullBackupService.writeLocalSnapshot(archiveWith(6)), isTrue);
    });

    test('clearLocalSnapshot removes the live copy and its safety copy',
        () async {
      await FullBackupService.writeLocalSnapshot(archiveWith(3));
      await FullBackupService.writeLocalSnapshot(archiveWith(4));
      expect(await tempDir.list().toList(), isNotEmpty);

      await FullBackupService.clearLocalSnapshot('a@b.com');
      expect(await FullBackupService.readLocalSnapshot('a@b.com'), isNull);
      expect(await tempDir.list().toList(), isEmpty);
    });

    List<File> safetyCopies(List<FileSystemEntity> entries) => entries
        .whereType<File>()
        .where(
          (f) => RegExp(r'_\d{4}-\d{2}-\d{2}\.json$')
              .hasMatch(f.uri.pathSegments.last),
        )
        .toList();

    test('replacing the live snapshot keeps one dated safety copy', () async {
      await FullBackupService.writeLocalSnapshot(archiveWith(5));
      await FullBackupService.writeLocalSnapshot(archiveWith(20));

      final entries = await tempDir.list().toList();
      final copies = safetyCopies(entries);
      expect(copies, hasLength(1), reason: 'live + exactly one dated copy');
      expect(
        (await FullBackupService.readLocalSnapshot('a@b.com'))!.documentCount,
        20,
      );

      // The copy holds the snapshot that was replaced, not the new one.
      final payload =
          await BackupCipher.open(await copies.single.readAsString());
      final decoded = jsonDecode(payload!) as Map<String, dynamic>;
      final transactions = (decoded['collections'] as Map)['transactions'];
      expect(transactions, hasLength(5));

      // A second replace on the same day does not churn the copy.
      await FullBackupService.writeLocalSnapshot(archiveWith(30));
      expect(safetyCopies(await tempDir.list().toList()), hasLength(1));
    });

    test('a safety copy older than a week is pruned', () async {
      final stale = DateTime.now().subtract(const Duration(days: 8));
      final stamp = '${stale.year.toString().padLeft(4, '0')}-'
          '${stale.month.toString().padLeft(2, '0')}-'
          '${stale.day.toString().padLeft(2, '0')}';
      final old = File('${tempDir.path}/full_a_b_com_$stamp.json');
      await old.writeAsString('[]');

      await FullBackupService.writeLocalSnapshot(archiveWith(5));
      await FullBackupService.writeLocalSnapshot(archiveWith(7));

      expect(await old.exists(), isFalse, reason: 'older than safetyCopyTtl');
      expect(safetyCopies(await tempDir.list().toList()), hasLength(1));
    });

    test('an unreadable live file falls back to the safety copy', () async {
      await FullBackupService.writeLocalSnapshot(archiveWith(5));
      await FullBackupService.writeLocalSnapshot(archiveWith(9));

      // Truncated/corrupt live file (a kill mid-write, a bad restore).
      await File(
        '${tempDir.path}/full_a_b_com.json',
      ).writeAsString('{"not":"an archive"}');

      final read = await FullBackupService.readLocalSnapshot('a@b.com');
      expect(read, isNotNull);
      expect(
        read!.documentCount,
        5,
        reason: 'the copy taken before the 9-document write',
      );
    });
  });
}
