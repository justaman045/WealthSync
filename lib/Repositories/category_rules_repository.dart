import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../Utils/num_parse.dart';

class CategoryRulesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _cacheKey = 'sms_category_rules_cache';

  /// Coerce a Firestore field to a map, or null for any other type. A raw
  /// `as Map<String, dynamic>?` throws when the field is a `Map<dynamic,
  /// dynamic>`, a String, etc.
  static Map<String, dynamic>? _asMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  /// Coerce a Firestore field to a list of strings, tolerating any other type
  /// (and non-string element types).
  static List<String> _asStringList(dynamic value) => value is List
      ? value.map((e) => e.toString()).toList()
      : <String>[];

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
        final raw = _asMap(data['autoRules']);
        if (raw != null) {
          return raw.map((k, v) => MapEntry(k, _asStringList(v)));
        }
      }
    } catch (e) {
      debugPrint("Error fetching user auto-rules: $e");
    }
    return {};
  }

  /// Fetch merchant→category corrections synced to
  /// `users/{email}/learning_data/corrections`.
  Future<Map<String, dynamic>> fetchUserCorrections(String email) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(email)
          .collection('learning_data')
          .doc('corrections')
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final raw = _asMap(data['corrections']);
        if (raw != null) return raw;
      }
    } catch (e) {
      debugPrint("Error fetching user corrections: $e");
    }
    return {};
  }

  /// Increment the count for [merchant]→[category] in the user's synced
  /// corrections. Returns the new cloud count for the merchant (used to decide
  /// auto-promotion across devices).
  Future<int?> saveUserCorrection(
    String email,
    String merchant,
    String category,
  ) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(email)
          .collection('learning_data')
          .doc('corrections');
      final key = merchant.trim().toLowerCase();
      if (key.isEmpty) return null;

      return await _firestore.runTransaction((tx) async {
        final doc = await tx.get(docRef);
        final existing = Map<String, dynamic>.from(
          (doc.data()?['corrections'] as Map?) ?? {},
        );
        final entry = _asMap(existing[key]);
        int newCount = 1;
        if (entry != null && entry['category'] == category) {
          newCount = safeToInt(entry['count']) + 1;
          existing[key] = {'category': category, 'count': newCount};
        } else {
          existing[key] = {'category': category, 'count': newCount};
        }
        tx.set(docRef, {'corrections': existing}, SetOptions(merge: true));
        return newCount;
      });
    } catch (e) {
      debugPrint("Error saving user correction: $e");
      return null;
    }
  }

  /// Remove a merchant from the user's synced corrections.
  Future<void> removeUserCorrection(String email, String merchant) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(email)
          .collection('learning_data')
          .doc('corrections');
      final key = merchant.trim().toLowerCase();
      if (key.isEmpty) return;
      await _firestore.runTransaction((tx) async {
        final doc = await tx.get(docRef);
        final existing = Map<String, dynamic>.from(
          (doc.data()?['corrections'] as Map?) ?? {},
        );
        existing.remove(key);
        tx.set(docRef, {'corrections': existing}, SetOptions(merge: true));
      });
    } catch (e) {
      debugPrint("Error removing user correction: $e");
    }
  }

  /// Fetch manual keyword rules synced to
  /// `users/{email}/learning_data/customRules`.
  Future<Map<String, List<String>>> fetchUserCustomRules(String email) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(email)
          .collection('learning_data')
          .doc('customRules')
          .get();
      if (doc.exists && doc.data() != null) {
        final raw = _asMap(doc.data()!['customRules']);
        if (raw != null) {
          return raw.map((k, v) => MapEntry(k, _asStringList(v)));
        }
      }
    } catch (e) {
      debugPrint("Error fetching user custom rules: $e");
    }
    return {};
  }

  /// Save the user's full manual keyword rules map to Firestore.
  Future<void> saveUserCustomRules(
    String email,
    Map<String, List<String>> rules,
  ) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(email)
          .collection('learning_data')
          .doc('customRules');
      final serialized = rules.map((k, v) => MapEntry(k, List<String>.from(v)));
      await docRef.set({'customRules': serialized}, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error saving user custom rules: $e");
    }
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
        final existingRaw = _asMap(doc.data()?['autoRules']);
        final existing = existingRaw?.map(
              (k, v) => MapEntry(k, _asStringList(v)),
            ) ??
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
