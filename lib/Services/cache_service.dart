import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCacheService {
  static const _prefix = 'cache_';
  static const _versionKey = '${_prefix}schema_version';
  static late SharedPreferences _prefs;

  static const txs30 = Duration(seconds: 30);
  static const wealth60 = Duration(seconds: 60);
  static const asset60 = Duration(seconds: 60);
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
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final expiresAt = map['expiresAt'] as int;
      if (DateTime.now().millisecondsSinceEpoch >= expiresAt) {
        _prefs.remove(_k(key));
        return null;
      }
      return map['data'];
    } catch (_) {
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

  static Future<void> invalidateByPrefix(String prefix) async {
    final keys = _prefs.getKeys()
        .where((k) => k.startsWith(_k(prefix)))
        .toList();
    for (final k in keys) {
      await _prefs.remove(k);
    }
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

  /// Convert Timestamp values to ISO date strings for JSON-safe storage.
  static Map<String, dynamic> hiveSafe(Map<String, dynamic> map) {
    return map.map((key, value) => MapEntry(
      key,
      value is Timestamp ? value.toDate().toIso8601String() : value,
    ));
  }

  /// Restore ISO date strings back to Timestamp for fromMap.
  static Map<String, dynamic> hiveRestore(Map<String, dynamic> map) {
    return map.map((key, value) => MapEntry(
      key,
      value is String && _isIsoDate(value)
          ? Timestamp.fromDate(DateTime.parse(value))
          : value,
    ));
  }

  static bool _isIsoDate(String s) {
    return s.length >= 20 && s[4] == '-' && s[7] == '-' && s[10] == 'T';
  }
}
