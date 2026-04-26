import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("No user logged in");

    try {
      // 1. Delete Sub-Collections (Firestore doesn't auto-delete subcollections)
      // We need to fetch and batch delete.
      await _deleteCollection(
        'users/${user.email}/transactions',
      ); // Main Transactions
      await _deleteCollection(
        'users/${user.email}/recurring_payments',
      ); // Recurring Payments
      await _deleteCollection('users/${user.email}/wealth'); // Wealth items

      // 2. Delete User Document
      await _db.collection('users').doc(user.email).delete();

      // (Optional) Clean up backups if any
      // LocalBackupService.deleteBackups(user.email!);

      // 3. Delete Auth Account
      await user.delete();
    } catch (e) {
      if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
        throw Exception(
          "Security Check: Please log out and log in again to delete your account.",
        );
      }
      throw Exception("Failed to delete account: $e");
    }
  }

  Future<void> _deleteCollection(String path) async {
    final collection = _db.collection(path);
    final snapshots = await collection.get();
    for (var doc in snapshots.docs) {
      await doc.reference.delete();
    }
  }
}
