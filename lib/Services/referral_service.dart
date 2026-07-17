import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
        code = '$code${user.uid.substring(0, 2).toUpperCase()}';
      }
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

      final referrerEmail = query.docs.first.id;

      // Don't allow self-referral
      if (referrerEmail == currentUser.email) return false;

      final referrerRef = _db.collection('users').doc(referrerEmail);
      final currentUserRef = _db.collection('users').doc(currentUser.email);

      await _db.runTransaction((txn) async {
        final referrerSnap = await txn.get(referrerRef);
        final currentUserSnap = await txn.get(currentUserRef);

        // Prevent double-application
        final alreadyReferred = currentUserSnap.exists &&
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
        final newExpiry = currentExpiry != null && currentExpiry.isAfter(DateTime.now())
            ? currentExpiry.add(const Duration(days: 30))
            : DateTime.now().add(const Duration(days: 30));

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
