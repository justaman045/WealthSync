import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Services/user_service.dart';

/// `deleteAccount` deletes 34 collections, then the profile, then the auth
/// user. Before this marker existed, an interruption anywhere after the first
/// collection left a signed-in account with no data and no way to finish the
/// deletion the user asked for. These pin the three parts that make the resume
/// safe: who the marker belongs to, that it is written at the right point, and
/// that a sign-in actually looks for it.
void main() {
  group('isDeletionMarkerFor', () {
    test('matches the uid that wrote it', () {
      expect(UserService.isDeletionMarkerFor({'uid': 'u1'}, 'u1'), isTrue);
    });

    test('a marker from a previous account with the same email is stale', () {
      // Delete, then sign up again with the same address: the tombstone survives
      // (Firestore does not cascade) and must never erase the new account.
      expect(UserService.isDeletionMarkerFor({'uid': 'u0'}, 'u1'), isFalse);
    });

    test('a malformed marker is never trusted', () {
      expect(UserService.isDeletionMarkerFor(null, 'u1'), isFalse);
      expect(UserService.isDeletionMarkerFor(const {}, 'u1'), isFalse);
      expect(UserService.isDeletionMarkerFor({'uid': ''}, 'u1'), isFalse);
      expect(UserService.isDeletionMarkerFor({'uid': 7}, 'u1'), isFalse);
    });
  });

  group('deleteAccount ordering', () {
    final src = File('lib/Services/user_service.dart').readAsStringSync();

    test('the marker is written after the wipe and before the profile delete', () {
      final marker = src.indexOf('_writeDeletionMarker(email, user.uid)');
      final subCollectionLoop = src.indexOf('for (final sub in subcollections)');
      final profileDelete = src.indexOf(
        "collection('users').doc(email).delete()",
      );
      expect(subCollectionLoop, greaterThan(-1));
      expect(marker, greaterThan(subCollectionLoop));
      // A marker written first would let a resume delete an account whose data
      // was still intact — i.e. lose everything on the next sign-in.
      expect(marker, lessThan(profileDelete));
    });

    test('the resume never deletes without a matching uid', () {
      expect(src.contains('isDeletionMarkerFor(marker, user.uid)'), isTrue);
      expect(src.contains('resumeInterruptedDeletion'), isTrue);
    });
  });

  group('firestore.rules deletion marker', () {
    final rules = File('firestore.rules').readAsStringSync();
    String markerBlock() => rules.substring(
      rules.indexOf('match /meta/deletion'),
      rules.indexOf('match /transactions/{txId}'),
    );

    test('only the literal meta/deletion path is opened', () {
      expect(rules.contains('match /meta/{'), isFalse);
    });

    test('the marker is owner-only, uid-bound and write-once', () {
      final block = markerBlock();
      expect(block.contains('isOwner(userEmail)'), isTrue);
      expect(block.contains('hasOnly(['), isTrue);
      expect(block.contains("'uid'"), isTrue);
      expect(block.contains("'startedAt'"), isTrue);
      expect(block.contains('request.resource.data.uid == request.auth.uid'),
          isTrue);
      expect(block.contains('startedAt is timestamp'), isTrue);
      // An update branch would let a client keep a tombstone alive or rewrite
      // the uid it points at.
      expect(block.contains('allow update'), isFalse);
    });
  });

  group('sign-in hook', () {
    final main = File('lib/main.dart').readAsStringSync();

    test('a native sign-in looks for a pending deletion before phase 2', () {
      final hook = main.indexOf('resumeInterruptedDeletion');
      final transactionController = main.indexOf(
        'Get.put(TransactionController(), permanent: true)',
      );
      expect(hook, greaterThan(-1));
      expect(hook, lessThan(transactionController));
      // Web is excluded on purpose: the JS listener ordering there is fragile.
      expect(main.contains('if (!kIsWeb) {'), isTrue);
    });

    test('the auth controller purges the device copies after resuming', () {
      final auth = File('lib/Controllers/auth_controller.dart').readAsStringSync();
      final resume = auth.substring(auth.indexOf('Future<bool> resumeInterruptedDeletion'));
      expect(resume.contains('LocalBackupService.clearUserBackup(email)'), isTrue);
      expect(resume.contains('FullBackupService.clearLocalSnapshot(email)'), isTrue);
    });
  });
}
