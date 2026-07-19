import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class CategoryRulesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _cacheKey = 'sms_category_rules_cache';

  // ── User-specific auto rules (learning_data subcollection) ──

  /// Fetch user auto-rules from `users/{email}/learning_data/rules`.
  Future<Map<String, List<String>>> fetchUserAutoRules(String email) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(email)
          .collection('learning_data')
          .doc('rules')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final raw = data['autoRules'] as Map<String, dynamic>?;
        if (raw != null) {
          return raw.map((k, v) => MapEntry(k, List<String>.from(v as List)));
        }
      }
    } catch (e) {
      debugPrint("Error fetching user auto-rules: $e");
    }
    return {};
  }

  /// Save a keyword rule to the user's auto-rules in Firestore.
  Future<void> saveUserAutoRule(
    String email,
    String category,
    String keyword,
  ) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(email)
          .collection('learning_data')
          .doc('rules');

      await _firestore.runTransaction((tx) async {
        final doc = await tx.get(docRef);
        final existing = (doc.data()?['autoRules'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, List<String>.from(v as List))) ??
            <String, List<String>>{};
        existing[category] = [...(existing[category] ?? []), keyword];
        tx.set(docRef, {'autoRules': existing}, SetOptions(merge: true));
      });
    } catch (e) {
      debugPrint("Error saving user auto-rule: $e");
    }
  }

  Future<Map<String, List<String>>> fetchRules() async {
    try {
      // 1. Try to fetch from Firestore
      final doc = await _firestore
          .collection('app_config')
          .doc('sms_rules')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final Map<String, List<String>> rules = {};

        data.forEach((key, value) {
          if (value is List) {
            rules[key] = List<String>.from(value);
          }
        });

        // 2. Cache it
        await _saveToCache(rules);
        return rules;
      }
    } catch (e) {
      debugPrint("Error fetching rules from Firestore: $e");
    }

    // 3. Fallback to cache
    return await _loadFromCache();
  }

  Future<void> _saveToCache(Map<String, List<String>> rules) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(rules));
  }

  Future<Map<String, List<String>>> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_cacheKey);

    if (jsonString != null) {
      try {
        final decoded = jsonDecode(jsonString);
        if (decoded is! Map<String, dynamic>) return {};
        final Map<String, List<String>> rules = {};
        decoded.forEach((key, value) {
          if (value is List) {
            rules[key] = List<String>.from(value);
          }
        });
        return rules;
      } catch (e) {
        debugPrint("Error decoding cache: $e");
      }
    }
    return {}; // Return empty if no cache
  }
}
