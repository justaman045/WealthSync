import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:money_control/Models/cateogary.dart';

class CategoryService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user categories stream
  Stream<List<CategoryModel>> getCategoriesStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.email)
        .collection('categories')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => CategoryModel.fromMap(doc.id, doc.data()))
              .toList();
        });
  }

  // Add category
  Future<void> addCategory(CategoryModel category) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.email)
        .collection('categories')
        .add(category.toMap());
  }

  // Update category
  Future<void> updateCategory(CategoryModel category) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.email)
        .collection('categories')
        .doc(category.id)
        .update(category.toMap());
  }

  // Delete category
  Future<void> deleteCategory(String categoryId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.email)
        .collection('categories')
        .doc(categoryId)
        .delete();
  }
}
