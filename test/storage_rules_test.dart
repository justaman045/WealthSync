import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contract test for Firebase Storage security rules.
///
/// Storage is **dormant**: Cloud Storage needs the Blaze plan, this project stays
/// on Spark, and the profile-picture upload was removed with the dependency. The
/// rules file is kept as a reviewed starting point so a future upgrade does not
/// start from a console-only secret, and this test keeps it wired into
/// `firebase.json` with its ownership + upload bounds intact.
///
/// `tool/rules_tests/run.sh` proves the behaviour against the Storage emulator.
/// This test is the fast, always-on guard that the file exists, stays wired into
/// `firebase.json` (a rules file that is not deployed is not a rule), and keeps
/// the constraints that make it safe.
void main() {
  final rulesFile = File('storage.rules');
  final firebaseConfig = File('firebase.json');

  late String rules;
  late Map<String, dynamic> config;

  setUpAll(() {
    expect(
      rulesFile.existsSync(),
      isTrue,
      reason: 'storage.rules must be committed — Storage behaviour may not live '
          'only in the Firebase Console.',
    );
    rules = rulesFile.readAsStringSync();
    config = jsonDecode(firebaseConfig.readAsStringSync()) as Map<String, dynamic>;
  });

  group('storage.rules', () {
    test('uses the v2 rules language and targets Storage', () {
      expect(rules, contains("rules_version = '2';"));
      expect(rules, contains('service firebase.storage'));
      expect(rules, contains('match /b/{bucket}/o'));
    });

    test('derives ownership from the auth UID, never from email', () {
      expect(rules, contains('request.auth.uid == uid'));
      expect(
        rules,
        isNot(contains('request.auth.token.email')),
        reason: 'Storage paths are UID-based; email is mutable identity data.',
      );
    });

    test('profile pictures are owner-only for read and write', () {
      expect(rules, contains('match /users/{uid}/{fileName}'));
      expect(rules, contains('allow read: if isOwner(uid);'));
      expect(rules, contains('allow create, update: if isOwner(uid)'));
    });

    test('uploads are bounded by size and content type', () {
      expect(rules, contains('request.resource.size <'));
      expect(rules, contains("contentType.matches('image/.*')"));
      expect(
        rules,
        contains("fileName == 'profile.jpg'"),
        reason: 'Only the path the app actually writes may be writable.',
      );
    });

    test('deletes stay allowed for the owner (account deletion)', () {
      // `request.resource` is null on delete, so the metadata checks must be on
      // a separate branch or account deletion can never remove the picture.
      final deleteLine = rules
          .split('\n')
          .firstWhere((l) => l.trim().startsWith('allow delete:'));
      expect(deleteLine, contains('isOwner(uid)'));
      expect(deleteLine, isNot(contains('request.resource')));
    });

    test('everything else is denied', () {
      expect(rules, contains('match /{allPaths=**}'));
      expect(rules, contains('allow read, write: if false;'));
    });

    test('never allows an unauthenticated wildcard', () {
      expect(rules, isNot(contains('allow read, write: if true')));
      expect(rules, isNot(contains('allow write: if true')));
    });
  });

  group('Spark plan constraint', () {
    // Cloud Storage requires the Blaze plan and this project stays on Spark, so
    // no bucket can exist. An upload path that ships anyway is a dead button
    // whose only failure mode is a snackbar — the profile upload was removed on
    // purpose. Re-adding it must be a deliberate change (and a plan upgrade).
    test('the app carries no Cloud Storage writer', () {
      final controller =
          File('lib/Controllers/profile_controller.dart').readAsStringSync();
      expect(controller, isNot(contains('firebase_storage')));
      expect(controller, isNot(contains('pickAndUploadImage')));
      expect(
        File('pubspec.yaml').readAsStringSync(),
        isNot(contains('firebase_storage:')),
        reason: 'The dependency was removed with the upload affordance.',
      );
      expect(
        File('lib/Screens/edit_profile.dart').readAsStringSync(),
        isNot(contains('camera_alt_rounded')),
        reason: 'The camera badge was the only way into the upload.',
      );
    });
  });

  group('firebase.json wiring', () {
    test('storage rules are part of the deploy config', () {
      final storage = config['storage'];
      expect(
        storage,
        isA<Map<String, dynamic>>(),
        reason: 'firebase.json must have a "storage" entry or '
            '`firebase deploy --only storage` has nothing to deploy.',
      );
      expect((storage as Map<String, dynamic>)['rules'], 'storage.rules');
    });

    test('firestore rules and indexes stay wired', () {
      final firestore = config['firestore'] as Map<String, dynamic>;
      expect(firestore['rules'], 'firestore.rules');
      expect(firestore['indexes'], 'firestore.indexes.json');
    });

    test('emulators are configured for the rules job', () {
      final emulators = config['emulators'];
      expect(emulators, isA<Map<String, dynamic>>());
      expect(
        (emulators as Map<String, dynamic>).containsKey('firestore'),
        isTrue,
      );
      expect(emulators.containsKey('storage'), isTrue);
    });
  });
}
