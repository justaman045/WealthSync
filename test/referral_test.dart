import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Services/referral_service.dart';

void main() {
  group('generateReferralCode()', () {
    test('is deterministic for the same name and uid', () {
      final a = ReferralService.generateReferralCode('Aditi Sharma', 'abc123DEF456');
      final b = ReferralService.generateReferralCode('Aditi Sharma', 'abc123DEF456');
      expect(a, b);
      expect(a.length, 6);
    });

    test('takes 4 name characters and 2 uid characters, uppercased', () {
      expect(
        ReferralService.generateReferralCode('Aditi Sharma', 'xy789'),
        'ADITXY',
      );
    });

    test('strips non-alphanumerics from the name', () {
      expect(
        ReferralService.generateReferralCode('a-d_i.t!', 'zz99'),
        'ADITZZ',
      );
    });

    test('pads a short name with X', () {
      expect(ReferralService.generateReferralCode('Jo', 'zz99'), 'JOXXZZ');
    });

    test('pads a uid with no alphanumerics with zeros', () {
      expect(ReferralService.generateReferralCode('Aditi', '----'), 'ADIT00');
    });
  });

  group('firestore.rules referral access', () {
    final rules = File('firestore.rules').readAsStringSync();

    test('the users collection never grants a list/read-all operation', () {
      final usersBlock = rules.substring(
        rules.indexOf('match /users/{userEmail}'),
        rules.indexOf('match /app_config'),
      );
      expect(
        usersBlock.contains('allow list'),
        isFalse,
        reason: 'A list grant on users would expose every user document',
      );
      expect(
        RegExp(r'allow\s+read\s*:\s*if\s+true').hasMatch(usersBlock),
        isFalse,
      );
    });

    test('referralCodes grants get but never list', () {
      final block = rules.substring(rules.indexOf('match /referralCodes'));
      expect(block.contains('allow get:'), isTrue);
      expect(
        block.contains('allow list'),
        isFalse,
        reason: 'list would let any signed-in user enumerate code owners',
      );
    });

    test('referralCodes cannot be written by creating a code you do not own', () {
      final block = rules.substring(rules.indexOf('match /referralCodes'));
      expect(
        block.contains("request.resource.data.owner == request.auth.token.email"),
        isTrue,
      );
      expect(
        block.contains("resource.data.owner == request.auth.token.email"),
        isTrue,
      );
    });

    test('a claim update may only append to claims', () {
      final block = rules.substring(rules.indexOf('match /referralCodes'));
      expect(block.contains("hasOnly(['claims'])"), isTrue);
      expect(block.contains('size() == resource.data.claims.size() + 1'), isTrue);
    });

    test('an appended claim must be the caller own entry', () {
      final block = rules.substring(rules.indexOf('match /referralCodes'));
      // Otherwise a client could append claims for other users, or overwrite
      // an existing referee's entry, while still growing the map by one.
      expect(
        block.contains('request.auth.uid in request.resource.data.claims'),
        isTrue,
      );
      expect(
        block.contains('.affectedKeys()\n                   .hasOnly([request.auth.uid])'),
        isTrue,
        reason: 'only the caller own key may differ from the previous claims',
      );
      expect(
        block.contains(
          'request.resource.data.claims[request.auth.uid] is timestamp',
        ),
        isTrue,
      );
    });

    test('a code document must be created with empty claims and credits', () {
      final block = rules.substring(rules.indexOf('match /referralCodes'));
      // The owner converts claims into trial days on their next login, so a
      // seeded claim is a self-granted referral reward.
      expect(
        block.contains(
          'request.resource.data.claims == null\n                        || request.resource.data.claims.size() == 0',
        ),
        isTrue,
      );
      expect(
        block.contains(
          'request.resource.data.credited == null\n                        || request.resource.data.credited.size() == 0',
        ),
        isTrue,
      );
    });

    test('rules use only type identifiers the Firestore compiler accepts', () {
      final block = rules.substring(rules.indexOf('match /referralCodes'));
      // `is Map` / `is Timestamp` fail to compile; the compiler only accepts
      // the lowercase names. `firebase deploy --dry-run` is what catches this.
      expect(RegExp(r'is\s+Map\b').hasMatch(block), isFalse);
      expect(RegExp(r'is\s+Timestamp\b').hasMatch(block), isFalse);
      expect(block.contains('is map'), isTrue);
    });
  });
}
