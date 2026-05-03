import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:money_control/Models/cateogary.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CategoryService {
  static const _correctionsKey = 'category_corrections';

  // Records a merchant→category correction. After 2+ corrections for the same
  // merchant we surface a "create rule" suggestion.
  static Future<void> recordCorrection(
    String merchant,
    String category,
  ) async {
    final key = merchant.trim().toLowerCase();
    if (key.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_correctionsKey);
    final Map<String, dynamic> map =
        raw != null ? Map<String, dynamic>.from(jsonDecode(raw) as Map) : {};
    final existing = map[key] as Map<String, dynamic>?;
    if (existing != null && existing['category'] == category) {
      map[key] = {'category': category, 'count': (existing['count'] as int) + 1};
    } else {
      map[key] = {'category': category, 'count': 1};
    }
    await prefs.setString(_correctionsKey, jsonEncode(map));
  }

  // Returns the user-corrected category for a merchant, if any.
  static Future<String?> getSuggestion(String merchant) async {
    final key = merchant.trim().toLowerCase();
    if (key.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_correctionsKey);
    if (raw == null) return null;
    final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final entry = map[key] as Map<String, dynamic>?;
    if (entry == null) return null;
    return entry['category'] as String?;
  }

  // Returns merchants corrected 2+ times (candidates to become rules).
  static Future<List<Map<String, dynamic>>> getPendingSuggestions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_correctionsKey);
    if (raw == null) return [];
    final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final result = <Map<String, dynamic>>[];
    map.forEach((merchant, value) {
      final entry = value as Map<String, dynamic>;
      if ((entry['count'] as int) >= 2) {
        result.add({
          'merchant': merchant,
          'category': entry['category'] as String,
          'count': entry['count'] as int,
        });
      }
    });
    result.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return result;
  }

  // Removes a pending suggestion (after it becomes a rule or is dismissed).
  static Future<void> removeSuggestion(String merchant) async {
    final key = merchant.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_correctionsKey);
    if (raw == null) return;
    final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    map.remove(key);
    await prefs.setString(_correctionsKey, jsonEncode(map));
  }
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
