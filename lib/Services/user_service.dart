import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // All subcollections that must be deleted before the user document.
  static const _subcollections = [
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
  ];

  /// How recently the user must have signed in for `user.delete()` to be
  /// accepted. Kept comfortably inside Firebase Auth's own
  /// `requires-recent-login` window so the pre-flight below trips *before* any
  /// data is destroyed, rather than the delete failing halfway through.
  static const Duration _recentLoginWindow = Duration(minutes: 5);

  static const String _reauthRequiredMessage =
      "Security Check: Please log out and log in again to delete your account.";

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("No user logged in");

    final email = user.email;
    if (email == null) throw Exception("User has no email");

    // 0. Pre-flight the auth freshness BEFORE deleting anything.
    //
    // `user.delete()` throws `requires-recent-login` for a stale session, and
    // the old order (Firestore first, auth last) had already destroyed every
    // transaction, goal and asset by then — the user was told to log in again
    // to finish deleting an account whose data was already gone. Checking the
    // sign-in time first turns a silent data-loss bug into a clean, actionable
    // refusal with nothing deleted.
    final lastSignIn = user.metadata.lastSignInTime;
    final staleSession = lastSignIn == null ||
        DateTime.now().difference(lastSignIn) > _recentLoginWindow;
    if (staleSession) {
      throw Exception(_reauthRequiredMessage);
    }

    // 1. Delete wealth portfolio document
    await _db.doc('users/$email/wealth/portfolio').delete();

    // 2. Delete all subcollections. If any fail, throw before touching auth.
    for (final sub in _subcollections) {
      await _deleteCollection('users/$email/$sub');
    }

    // 3. Delete the user document.
    await _db.collection('users').doc(email).delete();

    // 4. Delete auth account only after all Firestore data is gone.
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception(_reauthRequiredMessage);
      }
      throw Exception("Failed to delete auth account: $e");
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
