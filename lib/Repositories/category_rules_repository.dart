import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class CategoryRulesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache key
  static const String _cacheKey = 'sms_category_rules_cache';

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
        final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
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
