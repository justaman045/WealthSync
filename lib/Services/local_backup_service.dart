// lib/Services/local_backup_service.dart

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:money_control/Services/error_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart';

class LocalBackupService {
  LocalBackupService._();

  static const String _prefsPrefix = 'backup_';

  // ============================
  // PUBLIC API
  // ============================

  static Future<void> restoreUserTransactions(String email) async {
    final transactions = await readUserTransactionsBackup(email);
    if (transactions.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .collection('transactions');

    for (var data in transactions) {
      if (data.containsKey('id')) {
        final docRef = col.doc(data['id']);
        final Map<String, dynamic> writeData = Map.from(data)..remove('id');
        _restoreDates(writeData);
        batch.set(docRef, writeData, SetOptions(merge: true));
      }
    }
    await batch.commit();
  }

  static Future<void> backupUserTransactions(String userEmail) async {
    if (userEmail.isEmpty) return;

    const maxRetries = 3;
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final col = FirebaseFirestore.instance
            .collection('users')
            .doc(userEmail)
            .collection('transactions');

        final snap = await col.get(const GetOptions(source: Source.server));

        final List<Map<String, dynamic>> list = snap.docs.map((d) {
          final data = _convertFirestoreTypes(d.data());
          return {'id': d.id, ...data};
        }).toList();

        await _writeData(_prefsKey(userEmail), jsonEncode(list));

        debugPrint(
          '[LocalBackupService] Backup success: ${list.length} items for $userEmail',
        );
        return;
      } catch (e) {
        debugPrint('[LocalBackupService] Backup attempt ${attempt + 1} failed: $e');
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
        }
      }
    }
    debugPrint('[LocalBackupService] All backup attempts failed for $userEmail');
    ErrorHandler.showError('Backup failed. Data is safe in the cloud.', title: 'Backup');
  }

  static Future<List<Map<String, dynamic>>> readUserTransactionsBackup(
    String email,
  ) async {
    try {
      final raw = await _readData(_prefsKey(email));
      if (raw == null) return [];
      final data = jsonDecode(raw);
      if (data is! List) return [];
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint("[LocalBackupService] read error: $e");
      ErrorHandler.showError('Could not read local backup. Please try again.', title: 'Restore');
      return [];
    }
  }

  static Future<void> clearUserBackup(String userEmail) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey(userEmail));
      return;
    }
    final file = await _transactionsFile(userEmail);
    if (await file.exists()) await file.delete();
  }

  // ============================
  // HELPERS
  // ============================

  static String _prefsKey(String email) => '$_prefsPrefix${_sanitizeEmail(email)}';

  static Future<String?> _readData(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
    final file = await _transactionsFile(_extractEmail(key));
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  static Future<void> _writeData(String key, String data) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, data);
      return;
    }
    final file = await _transactionsFile(_extractEmail(key));
    await file.writeAsString(data);
  }

  static String _extractEmail(String key) => key.replaceFirst(_prefsPrefix, '').replaceAll('_', '.');

  /// Converts all Firestore-specific types into JSON-safe values
  static Map<String, dynamic> _convertFirestoreTypes(
    Map<String, dynamic> data,
  ) {
    final result = <String, dynamic>{};

    data.forEach((key, value) {
      if (value is Timestamp) {
        result[key] = value.toDate().toIso8601String();
      } else if (value is DateTime) {
        result[key] = value.toIso8601String();
      } else if (value is Map) {
        result[key] = _convertFirestoreTypes(
          Map<String, dynamic>.from(value),
        );
      } else if (value is List) {
        result[key] = value.map((item) {
          if (item is Map) return _convertFirestoreTypes(Map<String, dynamic>.from(item));
          if (item is Timestamp) return item.toDate().toIso8601String();
          if (item is DateTime) return item.toIso8601String();
          return item;
        }).toList();
      } else {
        result[key] = value;
      }
    });

    return result;
  }

  /// Converts ISO8601 strings back to Timestamp values, recursing into nested maps.
  static void _restoreDates(Map<String, dynamic> data) {
    data.forEach((key, value) {
      if (value is String && _looksLikeIsoDate(value)) {
        data[key] = Timestamp.fromDate(DateTime.parse(value));
      } else if (value is Map<String, dynamic>) {
        _restoreDates(value);
      }
    });
  }

  static bool _looksLikeIsoDate(String s) {
    return RegExp(r'\d{4}-\d{2}-\d{2}T').hasMatch(s);
  }

  /// Mobile-only — kept for exportBackupFile which returns a File
  static Future<Directory> _backupDir() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${baseDir.path}/money_control_backups');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File> exportBackupFile(String email) async {
    if (kIsWeb) {
      // Return in-memory file via universal_io (works on web)
      return File('/tmp/backup_${_sanitizeEmail(email)}.json');
    }
    final file = await _transactionsFile(email);
    if (!await file.exists()) {
      await file.writeAsString("[]");
    }
    return file;
  }

  static String _sanitizeEmail(String email) {
    return email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
  }

  static Future<File> _transactionsFile(String email) async {
    final dir = await _backupDir();
    final safe = _sanitizeEmail(email);
    return File('${dir.path}/tx_$safe.json');
  }
}
