import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
  // The correction is also synced to Firestore so it applies on every device.
  /// Decodes the corrections cache, tolerating corrupted or non-map data.
  static Map<String, dynamic> _safeDecodeMap(String? raw) {
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } catch (e) {
      debugPrint('CategoryService corrections decode error: $e');
      return {};
    }
  }

  /// Coerces a stored entry to a map, or null when it is any other type
  /// (a hand-edited/corrupt prefs value used to throw on `as Map<...>`).
  static Map<String, dynamic>? _asMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  static Future<void> recordCorrection(
    String merchant,
    String category,
  ) async {
    final key = merchant.trim().toLowerCase();
    if (key.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(correctionsKey);
    final map = _safeDecodeMap(raw);
    final existing = _asMap(map[key]);
    int newCount = 1;
    if (existing != null && existing['category'] == category) {
      newCount = ((existing['count'] as num?)?.toInt() ?? 0) + 1;
      map[key] = {'category': category, 'count': newCount};
    } else {
      map[key] = {'category': category, 'count': 1};
    }
    await prefs.setString(correctionsKey, jsonEncode(map));
    // Live-update the SMS parser's in-memory cache so corrections take effect immediately.
    SmsService.addCorrection(merchant, category);

    // Sync to Firestore (source of truth for cross-device learning).
    int? cloudCount;
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email != null) {
      cloudCount = await CategoryRulesRepository()
          .saveUserCorrection(user!.email!, key, category);
    }

    // Auto-promote to keyword rule when the effective (max of local + cloud)
    // count reaches the threshold — even if the other devices did some of the
    // corrections.
    final effectiveCount = cloudCount != null
        ? (newCount > cloudCount ? newCount : cloudCount)
        : newCount;
    if (effectiveCount >= autoPromoteThreshold) {
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
    final map = _safeDecodeMap(raw);
    final entry = _asMap(map[key]);
    if (entry == null) return null;
    return entry['category']?.toString();
  }

  // Returns merchants corrected 2+ times (candidates to become rules).
  static Future<List<Map<String, dynamic>>> getPendingSuggestions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(correctionsKey);
    if (raw == null) return [];
    final map = _safeDecodeMap(raw);
    final result = <Map<String, dynamic>>[];
    map.forEach((merchant, value) {
      final entry = _asMap(value);
      if (entry == null) return;
      final count = (entry['count'] as num?)?.toInt() ?? 0;
      if (count >= 2) {
        result.add({
          'merchant': merchant,
          'category': (entry['category']?.toString() ?? ''),
          'count': count,
        });
      }
    });
    result.sort((a, b) => (b['count'] as int? ?? 0).compareTo(a['count'] as int? ?? 0));
    return result;
  }

  // Removes a pending suggestion (after it becomes a rule or is dismissed).
  // Also removes it from the synced Firestore corrections.
  static Future<void> removeSuggestion(String merchant) async {
    final key = merchant.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(correctionsKey);
    if (raw != null) {
      final map = _safeDecodeMap(raw);
      map.remove(key);
      await prefs.setString(correctionsKey, jsonEncode(map));
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email != null) {
      await CategoryRulesRepository().removeUserCorrection(user!.email!, key);
    }
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
