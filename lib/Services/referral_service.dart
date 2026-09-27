import 'dart:convert';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class ReferralService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Web build URL for the invite message (GitHub Pages deploy).
  static const String inviteWebUrl =
      'https://justaman045.github.io/WealthSync/';

  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=app.vercel.justaman045.money_control';

  static const MethodChannel _upiChannel = MethodChannel('money_control/upi');

  /// Returns the download link to embed in an invite message, detecting the
  /// distribution channel the app was installed from: Play Store → store
  /// listing, otherwise → direct GitHub APK of the latest release. On web the
  /// hosted URL is used.
  static Future<String> getInviteDownloadUrl() async {
    if (kIsWeb) return inviteWebUrl;
    try {
      final installer = await _upiChannel.invokeMethod<String?>(
        'getInstallerPackageName',
      );
      if (installer == 'com.android.vending') return _playStoreUrl;
      return await _githubApkUrl();
    } catch (e) {
      debugPrint('Installer check error: $e');
      return await _githubApkUrl();
    }
  }

  /// Builds the share text for an invite message (markdown bold works on
  /// WhatsApp; the code is uppercased for consistency with how it is applied).
  static Future<String> buildInviteShareText(String code) async {
    final downloadUrl = await getInviteDownloadUrl();
    return "Use my code **${code.toUpperCase()}** to get 1 month free on "
        "WealthSync! 💰\n\n"
        "Track your expenses, budgets, loans & wealth — all in one app.\n\n"
        "📲 Download here: $downloadUrl";
  }

  /// Returns a direct APK download link by reading the latest version tag
  /// from app_version.json (same source UpdateChecker uses).
  static Future<String> _githubApkUrl() async {
    try {
      final resp = await http.get(
        Uri.parse(
          'https://raw.githubusercontent.com/justaman045/WealthSync/master/app_version.json',
        ),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is! Map) {
          return 'https://github.com/justaman045/WealthSync/releases/latest';
        }
        final version = data['latest_version'] as String?;
        if (version != null && version.isNotEmpty) {
          return 'https://github.com/justaman045/WealthSync/releases/download/v$version/app-release.apk';
        }
      }
    } catch (e) {
      debugPrint("Latest release fetch error: $e");
    }
    // Fallback: link to the releases page if the version fetch fails
    return 'https://github.com/justaman045/WealthSync/releases/latest';
  }

  /// Generates a deterministic 6-char referral code from name + uid.
  static String generateReferralCode(String name, String uid) {
    final namePart = name.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    final nameChars = namePart.length >= 4
        ? namePart.substring(0, 4)
        : namePart.padRight(4, 'X');
    final uidChars = uid.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final uidPart = uidChars.length >= 2
        ? uidChars.substring(0, 2)
        : uidChars.padRight(2, '0');
    return '$nameChars$uidPart';
  }

  static CollectionReference<Map<String, dynamic>> get _codes =>
      _db.collection('referralCodes');

  /// Reserves [code] for this user, extending it on collision.
  ///
  /// The write is a plain create, so a collision is detected by the failure
  /// itself — no uniqueness query is needed, and no query is possible: the
  /// rules grant per-document reads only, so a `where('referralCode', …)`
  /// collection query can never be proven and always fails.
  static Future<String> _reserveCode(
    String code,
    String email,
    String uid,
  ) async {
    final tail = uid.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final extra = tail.length >= 4 ? tail : tail.padRight(4, '0');
    for (var attempt = 0; attempt < 3; attempt++) {
      final candidate = attempt == 0
          ? code
          : '$code${extra.substring(attempt - 1, attempt + 1)}';
      try {
        await _codes.doc(candidate).set({
          'owner': email,
          'ownerUid': uid,
          'createdAt': FieldValue.serverTimestamp(),
          'claims': <String, dynamic>{},
          'credited': <String, dynamic>{},
        });
        return candidate;
      } catch (e) {
        log("Referral code $candidate unavailable: $e");
      }
    }
    return '';
  }

  /// Ensures this user has a referral code, a matching `referralCodes` doc
  /// (lazily created for pre-migration accounts), and credits any referral
  /// claims that are waiting for them.
  ///
  /// Runs on every login, so the claim queue drains without a batch script and
  /// without ever reading another user's document.
  static Future<void> ensureReferralCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;
    final email = user.email!;
    try {
      final userRef = _db.collection('users').doc(email);
      final doc = await userRef.get();
      final existing = doc.data()?['referralCode'] as String?;
      String code = existing ?? '';

      if (code.isEmpty) {
        code = await _reserveCode(
          generateReferralCode(user.displayName ?? email, user.uid),
          email,
          user.uid,
        );
        if (code.isEmpty) return;
        await userRef.set({
          'referralCode': code,
          'referralCount': (doc.data()?['referralCount'] as int?) ?? 0,
        }, SetOptions(merge: true));
      } else {
        await _ensureCodeDoc(code, email, user.uid);
      }

      await _drainClaims(code, email);
    } catch (e) {
      log("Error ensuring referral code: $e");
    }
  }

  /// Creates the `referralCodes` doc for an account that predates the
  /// collection, without ever overwriting a code owned by someone else.
  static Future<void> _ensureCodeDoc(
    String code,
    String email,
    String uid,
  ) async {
    final ref = _codes.doc(code);
    final snap = await ref.get();
    if (snap.exists) {
      if (snap.data()?['owner'] != email) {
        log("Referral code $code is owned by another account");
      }
      return;
    }
    try {
      await ref.set({
        'owner': email,
        'ownerUid': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'claims': <String, dynamic>{},
        'credited': <String, dynamic>{},
      });
    } catch (e) {
      log("Error creating referral code doc: $e");
    }
  }

  /// Trial days granted per credited referral, and the hard ceiling.
  static const int _trialDaysPerReferral = 30;
  static const int _trialDaysCap = 45;

  /// Pure trial-expiry math for a referral payout, extracted so the reward the
  /// user is actually granted can be unit tested.
  ///
  /// [currentExpiry] is the user's existing `trialEndDate`, if any. A future
  /// expiry is extended from its current end (rewards stack); a missing or
  /// elapsed one restarts from [now]. Either way the result is clamped to
  /// [now] + cap, so an unbounded reward cannot be farmed.
  @visibleForTesting
  static DateTime debugComputeTrialEnd({
    required DateTime now,
    required int pendingClaims,
    DateTime? currentExpiry,
  }) {
    final cap = now.add(const Duration(days: _trialDaysCap));
    final reward = Duration(days: _trialDaysPerReferral * pendingClaims);
    final extended = currentExpiry != null && currentExpiry.isAfter(now)
        ? currentExpiry.add(reward)
        : now.add(reward);
    return extended.isAfter(cap) ? cap : extended;
  }

  /// Applies referral rewards this user has earned but not yet collected.
  ///
  /// A referee can only append its own uid to `claims`, so crediting — which
  /// touches the referrer's own trial and count — happens here, in the
  /// referrer's own document, on their next login.
  ///
  /// The user document and the `credited` marker are written in ONE
  /// transaction. Two separate writes left a window where the reward landed
  /// but the marker did not, and the next login paid the same referral again
  /// (double `referralCount`, double trial extension).
  static Future<void> _drainClaims(String code, String email) async {
    try {
      final codeRef = _codes.doc(code);
      final userRef = _db.collection('users').doc(email);
      final now = DateTime.now();

      await _db.runTransaction<void>((txn) async {
        // Read both before writing either: Firestore transactions require it.
        final codeSnap = await txn.get(codeRef);
        if (!codeSnap.exists) return;
        final data = codeSnap.data() ?? {};
        final claims = data['claims'];
        final credited = data['credited'];
        if (claims is! Map || claims.isEmpty) return;

        final creditedMap = credited is Map
            ? Map<String, dynamic>.from(credited)
            : <String, dynamic>{};

        final pending = <String, dynamic>{};
        claims.forEach((uid, at) {
          if (!creditedMap.containsKey(uid)) pending[uid.toString()] = at;
        });
        if (pending.isEmpty) return;

        final userSnap = await txn.get(userRef);
        final userData = userSnap.data() ?? {};
        final newExpiry = debugComputeTrialEnd(
          now: now,
          pendingClaims: pending.length,
          currentExpiry: (userData['trialEndDate'] as Timestamp?)?.toDate(),
        );

        creditedMap.addAll(pending);
        txn.set(userRef, {
          'referralCount':
              ((userData['referralCount'] as int?) ?? 0) + pending.length,
          'subscriptionStatus': 'pro',
          'trialEndDate': Timestamp.fromDate(newExpiry),
        }, SetOptions(merge: true));
        txn.set(codeRef, {'credited': creditedMap}, SetOptions(merge: true));
      });
    } catch (e) {
      log("Error draining referral claims: $e");
    }
  }

  /// Applies a referral code during onboarding.
  /// Returns true if the code was valid and applied.
  static Future<bool> applyReferralCode(String code) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.email == null) return false;
    final upperCode = code.trim().toUpperCase();
    if (upperCode.isEmpty) return false;

    try {
      final codeRef = _codes.doc(upperCode);
      final currentUserRef =
          _db.collection('users').doc(currentUser.email);
      final trialEnd = DateTime.now().add(const Duration(days: 30));

      // The code document MUST be read inside the transaction. Reading it
      // outside would leave it out of the transaction's read set, so two
      // referees entering the same code at once would not conflict: the
      // second write would overwrite the first one's claims map and a
      // referral reward would vanish. The rules enforce add-only-one-claim;
      // this is what makes the client's write agree with them.
      final applied = await _db.runTransaction<bool>((txn) async {
        final codeSnap = await txn.get(codeRef);
        if (!codeSnap.exists) return false;

        final codeData = codeSnap.data() ?? {};
        final ownerEmail = codeData['owner'] as String?;
        if (ownerEmail == null || ownerEmail == currentUser.email) {
          return false; // no owner, or self-referral
        }

        final currentUserSnap = await txn.get(currentUserRef);
        if (currentUserSnap.exists &&
            (currentUserSnap.data()?['referredBy'] != null)) {
          // Returning false (not an early bare `return`) is what stops the
          // caller reporting success for a code that was not applied.
          return false;
        }

        final existingClaims = codeData['claims'];
        final nextClaims = existingClaims is Map
            ? Map<String, dynamic>.from(existingClaims)
            : <String, dynamic>{};
        nextClaims[currentUser.uid] = FieldValue.serverTimestamp();

        txn.set(
          codeRef,
          {'claims': nextClaims},
          SetOptions(merge: true),
        );
        txn.set(currentUserRef, {
          'referredBy': upperCode,
          'trialEndDate': Timestamp.fromDate(trialEnd),
        }, SetOptions(merge: true));

        return true;
      });

      return applied;
    } catch (e) {
      log("Error applying referral code: $e");
      return false;
    }
  }

  /// Fetches the current user's referral code and count.
  static Future<Map<String, dynamic>> getReferralStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      return {'code': '', 'count': 0};
    }
    try {
      final doc = await _db.collection('users').doc(user.email).get();
      final data = doc.data() ?? {};
      return {
        'code': data['referralCode'] as String? ?? '',
        'count': (data['referralCount'] as int?) ?? 0,
      };
    } catch (e) {
      debugPrint('Referral code fetch error: $e');
      return {'code': '', 'count': 0};
    }
  }
}
