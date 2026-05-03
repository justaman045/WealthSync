import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReferralService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Generates a deterministic 6-char referral code from name + uid.
  static String generateReferralCode(String name, String uid) {
    final namePart = name.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    final nameChars = namePart.length >= 4 ? namePart.substring(0, 4) : namePart.padRight(4, 'X');
    final uidChars = uid.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final uidPart = uidChars.length >= 2 ? uidChars.substring(0, 2) : uidChars.padRight(2, '0');
    return '$nameChars$uidPart';
  }

  /// Ensures the current user has a referralCode field in Firestore.
  static Future<void> ensureReferralCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;
    try {
      final doc = await _db.collection('users').doc(user.email).get();
      if (doc.exists && (doc.data()?['referralCode'] != null)) return;
      final code = generateReferralCode(
        user.displayName ?? user.email!,
        user.uid,
      );
      await _db.collection('users').doc(user.email).set(
        {'referralCode': code, 'referralCount': 0},
        SetOptions(merge: true),
      );
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

      final referrerDoc = query.docs.first;
      final referrerEmail = referrerDoc.id;

      // Don't allow self-referral
      if (referrerEmail == currentUser.email) return false;

      // Mark current user as referred and grant 30-day trial
      final trialEnd = DateTime.now().add(const Duration(days: 30));
      await _db.collection('users').doc(currentUser.email).set(
        {
          'referredBy': upperCode,
          'trialEndDate': Timestamp.fromDate(trialEnd),
        },
        SetOptions(merge: true),
      );

      // Increment referrer count and extend their subscription by 30 days
      final referrerData = referrerDoc.data();
      final currentExpiry = referrerData['expiryDate'] as Timestamp?;
      final newExpiry = currentExpiry != null
          ? currentExpiry.toDate().add(const Duration(days: 30))
          : DateTime.now().add(const Duration(days: 30));

      await _db.collection('users').doc(referrerEmail).set(
        {
          'referralCount': FieldValue.increment(1),
          'subscriptionStatus': 'pro',
          'expiryDate': Timestamp.fromDate(newExpiry),
        },
        SetOptions(merge: true),
      );

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
    } catch (_) {
      return {'code': '', 'count': 0};
    }
  }
}
