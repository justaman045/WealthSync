import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // All subcollections that must be deleted before the user document.
  //
  // Public so the GDPR "export all data" screen can iterate the exact same set:
  // a hand-copied duplicate had no enforcement and would silently desync
  // export from deletion whenever an asset type was added.
  static const subcollections = [
    // Core
    'transactions',
    'recurring_payments',
    'categories',
    'budgets',
    'notifications',
    'goals',
    'loans',
    'challenges',
    'lent_money',
    'sms_rules',
    'category_rules',
    'learning_data',
    // Liquid & Fixed Income
    'fd_accounts',
    'ppf_accounts',
    'post_office_schemes',
    'bonds',
    'chit_funds',
    // Equity & Growth
    'stock_holdings',
    'sip_holdings',
    'etf_holdings',
    'foreign_stocks',
    'startup_investments',
    // Retirement
    'pf_accounts',
    'vpf_accounts',
    'nps_accounts',
    // Alternative Assets
    'gold_holdings',
    'sgb_holdings',
    'jewelry_items',
    'crypto_holdings',
    'reit_holdings',
    'p2p_loans',
    // Physical Assets
    'agri_land',
    'properties',
    'vehicles',
    // Protection & Business
    'insurance_policies',
    'business_assets',
    // Liabilities
    'bnpl_entries',
    'credit_cards',
    // Auxiliary collections created by the app; must be cleared on normal
    // deletion and are also covered by GDPR erase.
    'backups',
    'insights',
    'preferences',
    'logs',
    'receipts',
    'audit_log',
  ];

  /// Where a partially-completed deletion is recorded, relative to `users/`.
  ///
  /// It cannot live on the profile document: step 4 deletes that, and the
  /// marker has to outlive it to be resumable. Firestore does not cascade a
  /// document delete into its subcollections, so this survives as a tiny
  /// tombstone — `resumeInterruptedDeletion` ignores/clears a marker whose uid
  /// is not the signed-in account's.
  static String deletionMarkerPath(String email) => 'users/$email/meta/deletion';

  /// How recently the user must have signed in for `user.delete()` to be
  /// accepted. Kept comfortably inside Firebase Auth's own
  /// `requires-recent-login` window so the pre-flight below trips *before* any
  /// data is destroyed, rather than the delete failing halfway through.
  static const Duration _recentLoginWindow = Duration(minutes: 5);

  static const String _reauthRequiredMessage =
      "Security Check: Please log out and log in again to delete your account.";

  /// True when [marker] was written by [uid], i.e. *this* account's deletion
  /// can be finished. A marker from a previous account that used the same
  /// email carries a different uid and must be treated as stale.
  static bool isDeletionMarkerFor(Map<String, dynamic>? marker, String uid) {
    final owner = marker?['uid'];
    return owner is String && owner.isNotEmpty && owner == uid;
  }

  /// Reads the deletion marker, treating "rules do not know this path yet"
  /// (a production deploy older than this build) as "no marker".
  Future<Map<String, dynamic>?> readDeletionMarker(String email) async {
    try {
      final doc = await _db.doc(deletionMarkerPath(email)).get();
      return doc.data();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      return null;
    }
  }

  Future<void> clearDeletionMarker(String email) async {
    try {
      await _db.doc(deletionMarkerPath(email)).delete();
    } catch (e) {
      debugPrint('Failed to clear the deletion marker: $e');
    }
  }

  Future<void> _writeDeletionMarker(String email, String uid) async {
    await _db.doc(deletionMarkerPath(email)).set({
      'uid': uid,
      'startedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("No user logged in");

    final email = user.email;
    if (email == null) throw Exception("User has no email");

    // 0. Pre-flight the auth freshness BEFORE deleting anything.
    final lastSignIn = user.metadata.lastSignInTime;
    final staleSession = lastSignIn == null ||
        DateTime.now().difference(lastSignIn) > _recentLoginWindow;
    if (staleSession) {
      throw Exception(_reauthRequiredMessage);
    }

    // Write deletion marker early so partial deletion can be resumed.
    try {
      await _writeDeletionMarker(email, user.uid);
    } catch (e) {
      debugPrint('Failed to write deletion marker early: $e');
      throw Exception('Failed to prepare account deletion for recovery');
    }

    // 1. Delete wealth portfolio document
    await _db.doc('users/$email/wealth/portfolio').delete();

    // 2. Delete all subcollections. If any fail, throw before touching auth.
    for (final sub in subcollections) {
      await _deleteCollection('users/$email/$sub');
    }
    // Clean up auxiliary collections
    for (final sub in ['backups', 'insights', 'preferences', 'logs', 'receipts', 'audit_log']) {
      try {
        await _deleteCollection('users/$email/$sub');
      } catch (e) {
        throw Exception('Failed to delete auxiliary collection $sub: $e');
      }
    }

    // 2b. Record that the data is gone, BEFORE the profile and the auth user are
    // removed.
    await _writeDeletionMarker(email, user.uid);

    // 3. Release the referral code.
    try {
      await _releaseReferralCode(email);
    } catch (e) {
      debugPrint('Failed to release referral code during deletion: $e');
      throw Exception('Failed to release referral code during deletion');
    }

    // 4. Delete the user document.
    await _db.collection('users').doc(email).delete();

    // 5. Delete auth account only after all Firestore data is gone.
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception(_reauthRequiredMessage);
      }
      throw Exception("Failed to delete auth account: $e");
    } catch (e) {
      throw Exception("Failed to delete auth account: $e");
    }
  }

  /// Finishes a deletion whose data was already gone but whose profile and auth
  /// user were not removed (app killed, network dropped at the wrong moment).
  ///
  /// Returns true when *this* account's marker was found and the account has
  /// been deleted — the caller's session is then dead and must not be used. A
  /// marker left by a different uid (account deleted, then signed up again with
  /// the same email) is stale: it is removed and false is returned, so a
  /// previous owner's marker can never erase a new account.
  ///
  /// The auth-freshness pre-flight deliberately does not apply: this runs right
  /// after a sign-in, and the account is already empty — refusing would strand
  /// exactly the state the marker exists to fix.
  Future<bool> resumeInterruptedDeletion() async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) return false;

    final marker = await readDeletionMarker(email);
    if (marker == null) return false;
    if (!isDeletionMarkerFor(marker, user.uid)) {
      // A stale tombstone from a previous account with this email.
      await clearDeletionMarker(email);
      debugPrint('Cleared a stale deletion marker for $email');
      return false;
    }

    try {
      await _db.doc('users/$email/wealth/portfolio').delete();
    } catch (e) {
      debugPrint('resumeInterruptedDeletion: failed to delete portfolio $e');
      throw Exception('Failed to complete deletion');
    }
    for (final sub in subcollections) {
      try {
        await _deleteCollection('users/$email/$sub');
      } catch (e) {
        debugPrint('resumeInterruptedDeletion: failed to delete $sub $e');
        throw Exception('Failed to complete deletion');
      }
    }
    for (final sub in ['backups', 'insights', 'preferences', 'logs', 'receipts', 'audit_log']) {
      try {
        await _deleteCollection('users/$email/$sub');
      } catch (e) {
        debugPrint('resumeInterruptedDeletion: failed to delete $sub $e');
        throw Exception('Failed to complete deletion');
      }
    }

    try {
      await _releaseReferralCode(email);
    } catch (e) {
      debugPrint('resumeInterruptedDeletion: failed to release referral $e');
      throw Exception('Failed to complete deletion');
    }
    try {
      await _db.collection('users').doc(email).delete();
    } catch (e) {
      debugPrint('resumeInterruptedDeletion: failed to delete profile $e');
      throw Exception('Failed to complete deletion');
    }
    // Throws (and keeps the marker) when the session went stale mid-resume: the
    // next sign-in retries.
    await user.delete();
    return true;
  }

  Future<void> _releaseReferralCode(String email) async {
    try {
      final profile = await _db.collection('users').doc(email).get();
      final code = profile.data()?['referralCode'];
      if (code is String && code.isNotEmpty) {
        await _db.collection('referralCodes').doc(code).delete();
      }
    } catch (e) {
      debugPrint('Failed to release referral code: $e');
      rethrow;
    }
  }

  // Paginated deletion to handle collections with >10 000 documents.
  Future<void> _deleteCollection(String path) async {
    final collection = _db.collection(path);
    while (true) {
      final snap = await collection.limit(500).get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
