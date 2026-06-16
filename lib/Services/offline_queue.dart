// lib/Services/offline_queue.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OfflineQueueService {
  // Serialize concurrent saves so reads/writes don't interleave.
  static bool _writing = false;
  static final List<Future<void> Function()> _pending = [];

  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File("${dir.path}/offline_queue.json");
  }

  // Recursively convert Timestamp / DateTime to ISO-8601 strings.
  // Strips FieldValue sentinels (serverTimestamp, delete, etc.) that break jsonEncode.
  static dynamic _sanitizeValue(dynamic value) {
    if (value is FieldValue) return Timestamp.now().toDate().toIso8601String();
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    if (value is Map<String, dynamic>) return _sanitize(value);
    if (value is List) return value.map(_sanitizeValue).toList();
    return value;
  }

  static Map<String, dynamic> _sanitize(Map<String, dynamic> raw) {
    return raw.map((k, v) => MapEntry(k, _sanitizeValue(v)));
  }

  // Atomic write: write to a temp file then rename to avoid partial-write corruption.
  static Future<void> _atomicWrite(File file, List list) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(list));
    await tmp.rename(file.path);
  }

  // Serialize all saves through a simple async queue.
  static Future<void> _enqueue(Future<void> Function() op) async {
    if (_writing) {
      _pending.add(op);
      return;
    }
    _writing = true;
    try {
      await op();
    } finally {
      _writing = false;
      if (_pending.isNotEmpty) {
        final next = _pending.removeAt(0);
        await _enqueue(next);
      }
    }
  }

  static Future<void> savePending(Map<String, dynamic> tx) {
    return _enqueue(() async {
      final file = await _getFile();
      List list = [];
      if (await file.exists()) {
        try {
          list = jsonDecode(await file.readAsString()) as List;
        } catch (e) {
          debugPrint("Offline queue decode error: $e");
        }
      }
      list.add(_sanitize(tx));
      await _atomicWrite(file, list);
    });
  }

  static Future<List<Map<String, dynamic>>> loadPending() async {
    final file = await _getFile();
    if (!await file.exists()) return [];

    List<dynamic> list;
    try {
      list = jsonDecode(await file.readAsString()) as List<dynamic>;
    } catch (_) {
      await _atomicWrite(file, []);
      return [];
    }

    return list.map((e) {
      if (e is! Map) return <String, dynamic>{};
      final m = Map<String, dynamic>.from(e);
      try {
        if (m['date'] is String) {
          m['date'] = Timestamp.fromDate(DateTime.parse(m['date'] as String));
        }
      } catch (_) {
        m['date'] = Timestamp.now();
      }
      try {
        if (m['createdAt'] is String) {
          m['createdAt'] =
              Timestamp.fromDate(DateTime.parse(m['createdAt'] as String));
        }
      } catch (_) {
        m['createdAt'] = Timestamp.now();
      }
      return m;
    }).toList();
  }

  static Future<void> removeFirst() {
    return _enqueue(() async {
      final file = await _getFile();
      if (!await file.exists()) return;
      final rawList = jsonDecode(await file.readAsString());
      final list = rawList is List ? rawList : <dynamic>[];
      if (list.isNotEmpty) list.removeAt(0);
      await _atomicWrite(file, list);
    });
  }

  static Future<void> clearPending() {
    return _enqueue(() async {
      final file = await _getFile();
      await _atomicWrite(file, []);
    });
  }
}
