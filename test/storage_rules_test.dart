import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contract test for Firebase Storage security rules.
///
/// The app uploads profile pictures to Firebase Storage, but the rules lived
/// only in the Firebase Console — nothing in the repo described them, nothing
/// could review them, and a fresh project would have had no protection at all.
///
/// `tool/rules_tests/run.sh` proves the behaviour against the Storage emulator.
/// This test is the fast, always-on guard that the file exists, stays wired into
/// `firebase.json` (a rules file that is not deployed is not a rule), and keeps
/// the ownership + upload constraints that make it safe.
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
