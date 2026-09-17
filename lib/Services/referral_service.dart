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

  /// Ensures the current user has a referralCode field in Firestore.
  static Future<void> ensureReferralCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;
    try {
      final doc = await _db.collection('users').doc(user.email).get();
      if (doc.exists && (doc.data()?['referralCode'] != null)) return;
      String code = generateReferralCode(
        user.displayName ?? user.email!,
        user.uid,
      );
      // Collision check: if code already exists for another user, append uid suffix
      final existing = await _db
          .collection('users')
          .where('referralCode', isEqualTo: code)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty && existing.docs.first.id != user.email) {
        final tail = user.uid.length >= 2
            ? user.uid.substring(user.uid.length - 2)
            : user.uid;
        code = '$code${tail.toUpperCase()}';
      }
      await _db.collection('users').doc(user.email).set({
        'referralCode': code,
        'referralCount': 0,
      }, SetOptions(merge: true));
    } catch (e) {
      log("Error ensuring referral code: $e");
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
      // Find the referrer by their referralCode field
      final query = await _db
          .collection('users')
          .where('referralCode', isEqualTo: upperCode)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return false;

      final referrerEmail = query.docs.first.id;

      // Don't allow self-referral
      if (referrerEmail == currentUser.email) return false;

      final referrerRef = _db.collection('users').doc(referrerEmail);
      final currentUserRef = _db.collection('users').doc(currentUser.email);

      await _db.runTransaction((txn) async {
        final referrerSnap = await txn.get(referrerRef);
        final currentUserSnap = await txn.get(currentUserRef);

        // Prevent double-application
        final alreadyReferred =
            currentUserSnap.exists &&
            (currentUserSnap.data()?['referredBy'] != null);
        if (alreadyReferred) return;

        final trialEnd = DateTime.now().add(const Duration(days: 30));
        txn.set(currentUserRef, {
          'referredBy': upperCode,
          'trialEndDate': Timestamp.fromDate(trialEnd),
        }, SetOptions(merge: true));

        final currentExpiry = referrerSnap.exists
            ? (referrerSnap.data()?['trialEndDate'] as Timestamp?)?.toDate()
            : null;
        final base = DateTime.now().add(const Duration(days: 30));
        // Extending an already-active grant can push past the rules' 45-day
        // validTrialCap (which counts from request time), so clamp to it.
        final cap = DateTime.now().add(const Duration(days: 45));
        final newExpiry = currentExpiry != null && currentExpiry.isAfter(DateTime.now())
            ? (currentExpiry.add(const Duration(days: 30)).isAfter(cap)
                ? cap
                : currentExpiry.add(const Duration(days: 30)))
            : base;

        txn.set(referrerRef, {
          'referralCount': FieldValue.increment(1),
          'subscriptionStatus': 'pro',
          'trialEndDate': Timestamp.fromDate(newExpiry),
        }, SetOptions(merge: true));
      });

      return true;
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
