import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:money_control/Models/cateogary.dart';
import 'package:money_control/Repositories/category_rules_repository.dart';
import 'package:money_control/Services/sms_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CategoryService {
  static const correctionsKey = 'category_corrections';

  /// Threshold for auto-promoting a correction to a keyword rule.
  /// After this many corrections for the same merchant→category, it
  /// becomes a permanent keyword rule (no manual approval needed).
  static const int autoPromoteThreshold = 3;

  // Records a merchant→category correction. After [autoPromoteThreshold]+
  // corrections for the same merchant the rule is promoted automatically.
  static Future<void> recordCorrection(
    String merchant,
    String category,
  ) async {
    final key = merchant.trim().toLowerCase();
    if (key.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(correctionsKey);
    final decoded = raw != null ? jsonDecode(raw) : null;
    final Map<String, dynamic> map = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : {};
    final existing = map[key] as Map<String, dynamic>?;
    int newCount = 1;
    if (existing != null && existing['category'] == category) {
      newCount = (existing['count'] as int? ?? 0) + 1;
      map[key] = {'category': category, 'count': newCount};
    } else {
      map[key] = {'category': category, 'count': 1};
    }
    await prefs.setString(correctionsKey, jsonEncode(map));
    // Live-update the SMS parser's in-memory cache so corrections take effect immediately.
    SmsService.addCorrection(merchant, category);

    // Auto-promote to keyword rule when threshold is reached
    if (newCount >= autoPromoteThreshold) {
      await _autoPromoteToRule(merchant, category);
    }
  }

  /// Promotes a merchant→category correction to a permanent keyword rule
  /// by saving to SharedPreferences and Firestore.
  static Future<void> _autoPromoteToRule(
    String merchant,
    String category,
  ) async {
    // Add to in-memory and SharedPreferences rules
    await SmsService.addKeywordRule(category, merchant);
    // Persist to Firestore for cross-device sync
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email != null) {
      final repo = CategoryRulesRepository();
      await repo.saveUserAutoRule(user!.email!, category, merchant);
    }
    // Remove the correction entry now that it's a rule
    await removeSuggestion(merchant);
  }

  // Returns the user-corrected category for a merchant, if any.
  static Future<String?> getSuggestion(String merchant) async {
    final key = merchant.trim().toLowerCase();
    if (key.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(correctionsKey);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    final map = decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    final entry = map[key] as Map<String, dynamic>?;
    if (entry == null) return null;
    return entry['category'] as String?;
  }

  // Returns merchants corrected 2+ times (candidates to become rules).
  static Future<List<Map<String, dynamic>>> getPendingSuggestions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(correctionsKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    final map = decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    final result = <Map<String, dynamic>>[];
    map.forEach((merchant, value) {
      if (value is! Map) return;
      final entry = value as Map<String, dynamic>;
      if ((entry['count'] as int? ?? 0) >= 2) {
        result.add({
          'merchant': merchant,
          'category': (entry['category'] as String? ?? ''),
          'count': (entry['count'] as int? ?? 0),
        });
      }
    });
    result.sort((a, b) => (b['count'] as int? ?? 0).compareTo(a['count'] as int? ?? 0));
    return result;
  }

  // Removes a pending suggestion (after it becomes a rule or is dismissed).
  static Future<void> removeSuggestion(String merchant) async {
    final key = merchant.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(correctionsKey);
    if (raw == null) return;
    final decoded = jsonDecode(raw);
    final map = decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    map.remove(key);
    await prefs.setString(correctionsKey, jsonEncode(map));
  }
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get _userEmail => _auth.currentUser?.email;

  // Get user categories stream
  Stream<List<CategoryModel>> getCategoriesStream() {
    final email = _userEmail;
    if (email == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(email)
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
    final email = _userEmail;
    if (email == null) return;

    await _firestore
        .collection('users')
        .doc(email)
        .collection('categories')
        .add(category.toMap());
  }

  // Update category
  Future<void> updateCategory(CategoryModel category) async {
    final email = _userEmail;
    if (email == null) return;

    await _firestore
        .collection('users')
        .doc(email)
        .collection('categories')
        .doc(category.id)
        .update(category.toMap());
  }

  // Delete category
  Future<void> deleteCategory(String categoryId) async {
    final email = _userEmail;
    if (email == null) return;

    await _firestore
        .collection('users')
        .doc(email)
        .collection('categories')
        .doc(categoryId)
        .delete();
  }
}
