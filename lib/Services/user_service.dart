import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // All subcollections that must be deleted before the user document.
  static const _subcollections = [
    'transactions',
    'recurring_payments',
    'wealth',
    'categories',
    'budgets',
    'notifications',
    'goals',
    'loans',
    'challenges',
    'lent_money',
    'sms_rules',
  ];

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("No user logged in");

    final email = user.email;
    if (email == null) throw Exception("User has no email");

    // 1. Delete all subcollections first. If any fail, throw before touching auth.
    for (final sub in _subcollections) {
      await _deleteCollection('users/$email/$sub');
    }

    // 2. Delete the user document.
    await _db.collection('users').doc(email).delete();

    // 3. Delete auth account only after all Firestore data is gone.
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception(
          "Security Check: Please log out and log in again to delete your account.",
        );
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
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    }
  }
}
