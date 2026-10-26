import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Services/referral_service.dart';

void main() {
  group('generateReferralCode()', () {
    test('is 8 characters from the unambiguous alphabet', () {
      final code = ReferralService.generateReferralCode();
      expect(code.length, 8);
      expect(RegExp(r'^[A-HJ-NP-Z2-9]+$').hasMatch(code), isTrue);
      // I/O/0/1 are excluded: a code gets read off a screenshot and typed by
      // hand, so lookalike glyphs are left out of the alphabet.
      expect(code.contains('I'), isFalse);
      expect(code.contains('O'), isFalse);
      expect(code.contains('0'), isFalse);
      expect(code.contains('1'), isFalse);
    });

    test('is not derived from the display name or uid', () {
      // It used to be `name.substring(0, 4) + uid.substring(0, 2)`, so a code
      // was guessable from public profile data.
      final codes = List.generate(200, (_) => ReferralService.generateReferralCode());
      expect(codes.toSet().length, codes.length);
    });
  });

  group('firestore.rules referral access', () {
    final rules = File('firestore.rules').readAsStringSync();

    String helperBlock() => rules.substring(
      rules.indexOf('function isTrialStart'),
      rules.indexOf('match /users/{userEmail}'),
    );
    String codesBlock() => rules.substring(rules.indexOf('match /referralCodes'));

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

    test('a free trial is 7 days and can be granted only once', () {
      final helpers = helperBlock();
      expect(
        helpers.contains("!resource.data.keys().hasAny(['trialEndDate'])"),
        isTrue,
        reason: 'the grant is once-only: no trialEndDate may already exist',
      );
      expect(
        helpers.contains('(7 * 24 * 60 * 60 * 1000)'),
        isTrue,
        reason: 'a longer "first trial" is a free Pro grant',
      );
      // After the grant, trialEndDate may only move earlier (cancel/expire).
      expect(helpers.contains('function isTrialShrink'), isTrue);
    });

    test('each grant branch checks ownership and its own field set', () {
      // `allow update` ORs its branches, so a branch that forgets the owner
      // check can write *any* account's profile. The trial branch had exactly
      // that shape (any signed-in user could rewrite a victim's profile), and
      // without hasOnly it was also a general-purpose write that could carry a
      // purchased-looking Pro claim alongside the trial date.
      expect(rules.contains('function isTrialStart(userEmail)'), isTrue);
      expect(rules.contains('|| isTrialStart(userEmail)'), isTrue);
      final trial = rules.substring(
        rules.indexOf('function isTrialStart'),
        rules.indexOf('function isTrialShrink'),
      );
      expect(trial.contains('request.auth.token.email == userEmail'), isTrue);
      expect(trial.contains("hasOnly(['trialEndDate'])"), isTrue);
    });

    test('the erase reset can drop gated fields but never set one back', () {
      // The erase branch may touch any field, so it is the one place a gated
      // value must be re-checked: otherwise "erase my data" also minted
      // `isAdmin: true` or a free trial.
      final erase = rules.substring(
        rules.indexOf('function isProfileErase'),
        rules.indexOf('function isTrialStart'),
      );
      expect(erase.contains("hasAny(['trialEndDate'])"), isTrue);
      expect(erase.contains("hasAny(['referralCredited'])"), isTrue);
      expect(
        erase.contains("!d.get('isAdmin', false)"),
        isTrue,
        reason: 'an erase that could write isAdmin is a self-promotion path',
      );
    });

    test('a referral month is 30 days, once, and needs a real code', () {
      final helpers = helperBlock();
      final application = helpers.substring(
        helpers.indexOf('function isReferralApplication'),
        helpers.indexOf('function isClaimPayout'),
      );
      expect(application.contains("!resource.data.keys().hasAny(['referredBy'])"), isTrue);
      expect(application.contains('(30 * 24 * 60 * 60 * 1000)'), isTrue);
      expect(
        application.contains('referralCodes'),
        isTrue,
        reason: 'referredBy without an existing code document granted 30 days',
      );
      expect(application.contains("!= request.auth.uid"), isTrue);
    });

    test('a referral payout is claim-backed and each claim pays once', () {
      final helpers = helperBlock();
      final payout = helpers.substring(helpers.indexOf('function isClaimPayout'));
      expect(
        payout.contains('referralCredited'),
        isTrue,
        reason: 'the credit ledger is what makes a claim payable once',
      );
      expect(
        payout.contains("affected.hasOnly(['referralCount', 'trialEndDate', 'referralCredited'])"),
        isTrue,
      );
      expect(
        payout.contains('claims.diff(before)'),
        isTrue,
        reason: 'a credited uid that is not a claim must not fund a payout',
      );
      expect(
        payout.contains('removedKeys().size() == 0'),
        isTrue,
        reason: 'dropping a credit made it payable again',
      );
    });

    test('the old cross-user Pro grant is gone', () {
      expect(
        rules.contains('isReferralReward'),
        isFalse,
        reason: 'that rule let any signed-in user grant subscriptionStatus '
            '"pro" to any account with a referralCode, with no purchase token',
      );
    });

    test('referralCodes grants get but never list', () {
      final block = codesBlock();
      expect(block.contains('allow get:'), isTrue);
      expect(
        block.contains('allow list'),
        isFalse,
        reason: 'list would let any signed-in user enumerate code owners',
      );
    });

    test('a code document is owned by uid, not by email', () {
      final block = codesBlock();
      expect(block.contains('request.resource.data.ownerUid == request.auth.uid'), isTrue);
      // Anyone who knows a code can read the document, so a new code must not
      // record the owner's address; an old document's `owner` must agree.
      expect(
        block.contains("!request.resource.data.keys().hasAny(['owner'])"),
        isTrue,
      );
      expect(
        block.contains('request.resource.data.owner == request.auth.token.email'),
        isTrue,
      );
      expect(
        block.contains("resource.data.get('ownerUid', '') == request.auth.uid"),
        isTrue,
        reason: 'the owner (and only the owner) may delete their code',
      );
    });

    test('a claim update may only append to claims, never to your own code', () {
      final block = codesBlock();
      expect(block.contains("hasOnly(['claims'])"), isTrue);
      expect(block.contains('size() == resource.data.claims.size() + 1'), isTrue);
      expect(
        block.contains('resource.data.ownerUid != request.auth.uid'),
        isTrue,
        reason: 'self-referral must be refused by the rules, not just the UI',
      );
    });

    test('an appended claim must be the caller own entry', () {
      final block = codesBlock();
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
      final block = codesBlock();
      // The owner converts claims into trial days on their next login, so a
      // seeded claim is a self-granted referral reward.
      expect(
        block.contains("request.resource.data.keys().hasAny(['claims'])"),
        isTrue,
      );
      expect(
        block.contains("request.resource.data.keys().hasAny(['credited'])"),
        isTrue,
      );
      expect(block.contains('size() == 0'), isTrue);
    });

    test('the credited list may grow but never shrink', () {
      final block = codesBlock();
      expect(
        block.contains("hasOnly(['credited'])"),
        isTrue,
        reason: 'the owner may not edit claims or re-point the code',
      );
      expect(
        block.contains('.removedKeys().size() == 0'),
        isTrue,
        reason: 'clearing a credit made the same claim payable again',
      );
    });

    test('rules use only type identifiers the Firestore compiler accepts', () {
      final block = codesBlock();
      // `is Map` / `is Timestamp` fail to compile; the compiler only accepts
      // the lowercase names. `firebase deploy --dry-run` is what catches this.
      expect(RegExp(r'is\s+Map\b').hasMatch(block), isFalse);
      expect(RegExp(r'is\s+Timestamp\b').hasMatch(block), isFalse);
      expect(block.contains('is map'), isTrue);
    });
  });
}
