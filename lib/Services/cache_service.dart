import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCacheService {
  static const _prefix = 'cache_';
  static const _versionKey = '${_prefix}schema_version';
  static late SharedPreferences _prefs;

  static const txs30 = Duration(seconds: 30);
  static const wealth60 = Duration(seconds: 60);
  static const slow5m = Duration(minutes: 5);

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    final info = await PackageInfo.fromPlatform();
    final currentVersion = '${info.version}+${info.buildNumber}';
    final storedVersion = _prefs.getString(_versionKey);

    if (storedVersion != currentVersion) {
      await _clearAllCache();
      await _prefs.setString(_versionKey, currentVersion);
    }
  }

  static String _k(String key) => '$_prefix$key';

  static dynamic get(String key) {
    final raw = _prefs.getString(_k(key));
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _prefs.remove(_k(key));
        return null;
      }
      final map = decoded;
      final rawExpiry = map['expiresAt'];
      final expiresAt = rawExpiry is int ? rawExpiry : (rawExpiry is double ? rawExpiry.toInt() : 0);
      if (DateTime.now().millisecondsSinceEpoch >= expiresAt) {
        _prefs.remove(_k(key));
        return null;
      }
      return map['data'];
    } catch (e) {
      debugPrint('Cache read error: $e');
      _prefs.remove(_k(key));
      return null;
    }
  }

  static Future<void> put(
    String key,
    dynamic value, {
    Duration ttl = const Duration(minutes: 5),
  }) async {
    final expiresAt = DateTime.now().millisecondsSinceEpoch + ttl.inMilliseconds;
    await _prefs.setString(
      _k(key),
      jsonEncode({'data': value, 'expiresAt': expiresAt}),
    );
  }

  static Future<void> invalidate(String key) async {
    await _prefs.remove(_k(key));
  }

  static Future<void> clearAll() async {
    await _clearAllCache();
    final info = await PackageInfo.fromPlatform();
    await _prefs.setString(_versionKey, '${info.version}+${info.buildNumber}');
  }

  static Future<void> _clearAllCache() async {
    final keys = _prefs.getKeys()
        .where((k) => k.startsWith(_prefix))
        .toList();
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }

  /// Recursively turn a value into something [jsonEncode] can store.
  ///
  /// Models can nest values (e.g. a loan's `repayments` list of maps), so the
  /// conversion has to walk maps and lists too — a top-level-only pass left the
  /// nested `Timestamp` intact and made `put()` throw. Firestore sentinels with
  /// no JSON representation (e.g. `FieldValue.serverTimestamp()`) become null.
  static dynamic _jsonSafe(dynamic value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    if (value is Map) {
      return value.map((key, v) => MapEntry(key.toString(), _jsonSafe(v)));
    }
    if (value is List) return value.map(_jsonSafe).toList();
    if (value is FieldValue ||
        value is GeoPoint ||
        value is Blob ||
        value is DocumentReference) {
      return null;
    }
    return value;
  }

  /// Convert Timestamp values to ISO date strings for JSON-safe storage.
  static Map<String, dynamic> hiveSafe(Map<String, dynamic> map) {
    return _jsonSafe(map) as Map<String, dynamic>;
  }

  /// Restore ISO date strings back to Timestamp for fromMap.
  static Map<String, dynamic> hiveRestore(Map<String, dynamic> map) {
    return map.map((key, value) => MapEntry(key, _restoreDate(value)));
  }

  static dynamic _restoreDate(dynamic value) {
    if (value is String && _isoDateRe.hasMatch(value)) {
      // Belt-and-braces: a free-text field can share an ISO-ish prefix (e.g.
      // "2026-01-15T was the party"). The regex is strict, but never let a
      // malformed-match throw out of a cache read (it runs synchronously in
      // controller init and would crash it).
      try {
        return Timestamp.fromDate(DateTime.parse(value));
      } catch (_) {
        return value;
      }
    }
    return value;
  }

  /// A full ISO-8601 instant, e.g. `2026-08-03T10:30:00.000` (what
  /// `DateTime.toIso8601String()` emits), optionally with seconds/fraction/
  /// timezone. Free text that merely *starts* with a date-like prefix no longer
  /// matches (the old positional check accepted anything ≥20 chars with `-`s).
  static final RegExp _isoDateRe = RegExp(
    r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:?\d{2})?$',
  );
}
