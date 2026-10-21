import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:money_control/Config/app_strings.dart';
import 'package:money_control/Models/backup_archive.dart';
import 'package:money_control/Services/full_backup_service.dart';
import 'package:money_control/Services/user_service.dart';

import 'test_helpers.dart';

/// The full-backup feature is the answer to the 2026-10-21 data loss, so it
/// gets an end-to-end test against live Firestore: capture every collection,
/// serialize, parse back, and restore. The unit tests cover the format guard
/// and the type round-trip with fakes; only this can prove the *real* query
/// path reads every collection and that the restore really writes back.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a full backup captures every collection and restores back',
    (tester) async {
      await launchAndSignIn(tester, account: TestAccount.free);

      final email = FirebaseAuth.instance.currentUser?.email;
      expect(email, isNotNull, reason: 'must be signed in');
      final userEmail = email!;

      // ---- UI: the screen is reachable and renders -----------------------
      // The service layer is verified below; this proves the wiring — the
      // feature gate, the settings tile and the navigation — so a rename
      // cannot silently orphan the feature.
      await tapNavTab(tester, Icons.tune_rounded, 'Settings');
      await tapUntilMarker(
        tester,
        find.text(AppStrings.dataSupport),
        find.text(AppStrings.backupAndRestoreAllData),
      );
      await tapWhenVisible(tester, find.text(AppStrings.backupAndRestoreAllData));
      await waitFor(tester, find.text(AppStrings.backupKeepOwnCopy));
      expect(find.text(AppStrings.backupKeepOwnCopy), findsWidgets);
      expect(find.text(AppStrings.backupDownload), findsWidgets);
      expect(find.text(AppStrings.backupRestoreFromFile), findsWidgets);
      await popScreen(tester); // Backup & Restore → Data & Support
      await popScreen(tester); // Data & Support → Settings
      // Back to Home — the transaction helper drives the home balance card.
      await tapNavTab(tester, Icons.grid_view_rounded, AppStrings.totalBalance);
      await waitForHome(tester);

      // Seed one transaction so the archive has something to carry.
      await createTransaction(
        tester,
        receive: true,
        name: 'Backup E2E Salary',
        amount: '4200',
        category: 'Salary',
      );

      // ---- CAPTURE -------------------------------------------------------
      final collectionErrors = <String>[];
      final archive = await FullBackupService.capture(
        userEmail,
        appVersion: 'e2e',
        onCollectionError: (c, _) => collectionErrors.add(c),
      );

      // A collection that failed to read makes the archive incomplete, and an
      // incomplete backup that reports success is exactly the failure mode
      // this feature exists to prevent.
      expect(
        collectionErrors,
        isEmpty,
        reason: 'collections that failed to read: $collectionErrors',
      );

      // Every collection must be represented, even the empty ones — otherwise
      // a restore cannot tell "empty" from "not captured". The count is
      // asserted against the canonical list the account-deletion flow uses,
      // so backup and delete can never drift apart.
      expect(
        archive.collections.length,
        UserService.subcollections.length,
        reason: 'the backup did not cover exactly the canonical collection set',
      );
      for (final name in UserService.subcollections) {
        expect(
          archive.collections.containsKey(name),
          isTrue,
          reason: '$name is missing from the archive',
        );
      }

      // The seeded transaction must be in there. Every string field is
      // searched: the name lands in `recipientName` for both send and
      // receive, but `note` is an empty string (not null) on a transaction
      // created without one, so a `??` chain would stop there and miss it.
      final transactions = archive.collections['transactions'] ?? const [];
      expect(
        transactions.any((t) => _contains(t, 'Backup E2E')),
        isTrue,
        reason: 'the seeded transaction is missing from the archive',
      );

      // The document id must survive, or a restore cannot recreate the
      // document.
      expect(
        transactions.every((t) => t.containsKey(BackupArchive.idField)),
        isTrue,
        reason: 'a transaction is missing its document id',
      );

      // The profile must be captured (it carries the subscription state).
      expect(archive.profile, isNotNull);
      expect(archive.profile!['email'], userEmail);

      // ---- SERIALIZE / PARSE --------------------------------------------
      final json = archive.toJson();
      final reparsed = BackupArchive.fromJson(json);
      expect(reparsed.email, userEmail);
      expect(reparsed.documentCount, archive.documentCount);
      expect(
        reparsed.collections['transactions']!.length,
        transactions.length,
      );

      // ---- RESTORE -------------------------------------------------------
      // Delete the transaction first so the restore has something to put back.
      final txCol = FirebaseFirestore.instance
          .collection('users')
          .doc(userEmail)
          .collection('transactions');
      final before = await txCol.get();
      for (final doc in before.docs) {
        await doc.reference.delete();
      }
      expect((await txCol.get()).docs, isEmpty);

      final result = await FullBackupService.restore(reparsed);

      expect(
        result.failed,
        isEmpty,
        reason: 'restore reported failures: ${result.failed}',
      );
      expect(result.totalWritten, greaterThan(0));

      // The data must actually be back.
      final after = await txCol.get();
      expect(
        after.docs.length,
        before.docs.length,
        reason: 'the restore did not put the transactions back',
      );
      expect(
        after.docs.any((d) => _contains(d.data(), 'Backup E2E')),
        isTrue,
        reason: 'the seeded transaction did not come back',
      );

      // ---- AUTOMATIC DEVICE SNAPSHOT --------------------------------------
      // The background worker takes one of these once a day, so the account
      // is recoverable even for a user who never opens the backup screen.
      final written = await FullBackupService.writeLocalSnapshot(reparsed);
      expect(written, isTrue);

      expect(
        await FullBackupService.hasLocalSnapshot(userEmail),
        isTrue,
        reason: 'the automatic snapshot was not stored on the device',
      );

      final snapshot = await FullBackupService.readLocalSnapshot(userEmail);
      expect(snapshot, isNotNull);
      expect(snapshot!.email, userEmail);
      expect(snapshot.documentCount, reparsed.documentCount);

      // A snapshot that would hold fewer documents than the stored one must
      // not replace it — that is the wipe-protection property, and getting it
      // wrong is what destroyed the only local copy on 2026-10-21.
      final shrunk = BackupArchive(
        formatVersion: BackupArchive.currentFormatVersion,
        createdAt: DateTime.utc(2026),
        email: userEmail,
        profile: null,
        wealthPortfolio: null,
        collections: const {'transactions': []},
      );
      expect(await FullBackupService.writeLocalSnapshot(shrunk), isFalse);
      expect(
        (await FullBackupService.readLocalSnapshot(userEmail))!.documentCount,
        reparsed.documentCount,
        reason: 'a smaller snapshot overwrote the stored one',
      );

      // And it must be restorable: wipe the collection again and restore
      // from the device snapshot.
      for (final doc in (await txCol.get()).docs) {
        await doc.reference.delete();
      }
      expect((await txCol.get()).docs, isEmpty);

      final snapshotRestore = await FullBackupService.restore(snapshot);
      expect(
        snapshotRestore.failed,
        isEmpty,
        reason: 'restoring the device snapshot reported failures: '
            '${snapshotRestore.failed}',
      );
      expect((await txCol.get()).docs.length, before.docs.length);
    },
  );
}

/// Whether [needle] appears in any of [doc]'s top-level string values.
bool _contains(Map<String, dynamic> doc, String needle) {
  for (final value in doc.values) {
    if (value is String && value.contains(needle)) return true;
  }
  return false;
}
