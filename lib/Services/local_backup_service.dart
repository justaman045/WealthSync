// lib/Services/local_backup_service.dart

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:money_control/Services/error_handler.dart';


class LocalBackupService {
  LocalBackupService._();

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

    // In a real app, we might delete existing or merge.
    // For simplicity, we'll upsert based on ID.
    for (var data in transactions) {
      if (data.containsKey('id')) {
        final docRef = col.doc(data['id']);
        final Map<String, dynamic> writeData = Map.from(data)..remove('id');
        // We need to restore specific types if they were stringified (DateTime)
        // But _convertFirestoreTypes stringified them. Firestore needs standard types?
        // Actually, if we just write strings, it stores strings.
        // Transaction Model expects strings for date usually? No, it expects DateTime.
        // We might need to parse invalid types if Models depend on Firestore Timestamp.
        // For now, let's assume the app handles string dates since backup saves them as ISO.
        // Better: Attempt to parse known date fields if possible.
        _restoreDates(writeData); // Helper exists at bottom
        batch.set(docRef, writeData, SetOptions(merge: true));
      }
    }
    await batch.commit();
  }

  static Future<void> backupUserTransactions(String userEmail) async {
    try {
      if (userEmail.isEmpty) return;

      final col = FirebaseFirestore.instance
          .collection('users')
          .doc(userEmail)
          .collection('transactions');

      final snap = await col.get(const GetOptions(source: Source.server));

      final List<Map<String, dynamic>> list = snap.docs.map((d) {
        final data = _convertFirestoreTypes(d.data());

        return {'id': d.id, ...data};
      }).toList();

      final file = await _transactionsFile(userEmail);
      await file.writeAsString(jsonEncode(list));

      debugPrint(
        '[LocalBackupService] Backup success: ${list.length} items for $userEmail',
      );
    } catch (e, st) {
      debugPrint('[LocalBackupService] backupUserTransactions ERROR: $e');
      debugPrint('$st');
      ErrorHandler.showError('Backup failed. Data is safe in the cloud.', title: 'Backup');
    }
  }

  static Future<List<Map<String, dynamic>>> readUserTransactionsBackup(
    String email,
  ) async {
    try {
      final file = await _transactionsFile(email);

      if (!await file.exists()) {
        await file.create(recursive: true);
        await file.writeAsString("[]");
        return [];
      }

      final raw = await file.readAsString();
      final data = jsonDecode(raw);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint("[LocalBackupService] read error: $e");
      ErrorHandler.showError('Could not read local backup. Please try again.', title: 'Restore');
      return [];
    }
  }

  static Future<void> clearUserBackup(String userEmail) async {
    final file = await _transactionsFile(userEmail);
    if (await file.exists()) await file.delete();
  }

  // ============================
  // HELPERS
  // ============================

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

  static Future<Directory> _backupDir() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${baseDir.path}/money_control_backups');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File> exportBackupFile(String email) async {
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
