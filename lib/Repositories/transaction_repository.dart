import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Models/cateogary.dart';

class TransactionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userEmail => _auth.currentUser?.email;

  // Collection References
  CollectionReference get _userTransactionsRef {
    if (_userEmail == null) throw Exception("User not logged in");
    return _firestore
        .collection('users')
        .doc(_userEmail)
        .collection('transactions');
  }

  CollectionReference get _userCategoriesRef {
    if (_userEmail == null) throw Exception("User not logged in");
    return _firestore
        .collection('users')
        .doc(_userEmail)
        .collection('categories');
  }

  // ——————————————————————————————————————
  // Transactions
  // ——————————————————————————————————————

  Future<DocumentReference> addTransaction(TransactionModel transaction) async {
    return await _userTransactionsRef.add(transaction.toMap());
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    if (transaction.id.isEmpty) throw Exception("Transaction ID is empty");
    await _userTransactionsRef.doc(transaction.id).update(transaction.toMap());
  }

  Future<void> deleteTransaction(String id) async {
    await _userTransactionsRef.doc(id).delete();
  }

  Stream<List<TransactionModel>> getTransactionsStream() {
    return _userTransactionsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return TransactionModel.fromMap(
              doc.id,
              doc.data() as Map<String, dynamic>,
            );
          }).toList();
        });
  }

  // ——————————————————————————————————————
  // Categories
  // ——————————————————————————————————————

  Future<List<CategoryModel>> fetchCategories() async {
    final snapshot = await _userCategoriesRef.get();
    return snapshot.docs.map((doc) {
      return CategoryModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
    }).toList();
  }

  Future<DocumentReference> addCategory(String name) async {
    return await _userCategoriesRef.add({"name": name});
  }

  Stream<List<CategoryModel>> getCategoriesStream() {
    return _userCategoriesRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return CategoryModel.fromMap(
          doc.id,
          doc.data() as Map<String, dynamic>,
        );
      }).toList();
    });
  }

  Future<void> deleteCategory(String id) async {
    await _userCategoriesRef.doc(id).delete();
  }
}
