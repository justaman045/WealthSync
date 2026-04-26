// lib/Services/offline_queue.dart

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OfflineQueueService {
  // --------------------------------------------------------
  //  FILE PATH
  // --------------------------------------------------------
  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File("${dir.path}/offline_queue.json");
  }

  // --------------------------------------------------------
  //  TIMESTAMP CLEANER → Convert to JSON-safe values
  // --------------------------------------------------------
  static Map<String, dynamic> _sanitize(Map<String, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);

    // createdAt (Timestamp → String)
    if (map["createdAt"] != null) {
      final ts = map["createdAt"];
      if (ts is Timestamp) {
        map["createdAt"] = ts.toDate().toIso8601String();
      }
    }

    // date (DateTime → String)
    if (map["date"] != null) {
      final dt = map["date"];
      if (dt is DateTime) {
        map["date"] = dt.toIso8601String();
      } else if (dt is Timestamp) {
        map["date"] = dt.toDate().toIso8601String();
      }
    }

    return map;
  }

  // --------------------------------------------------------
  //  SAVE ONE PENDING TRANSACTION
  // --------------------------------------------------------
  static Future<void> savePending(Map<String, dynamic> tx) async {
    final file = await _getFile();

    List list = [];
    if (await file.exists()) {
      final content = await file.readAsString();
      list = jsonDecode(content);
    }

    list.add(_sanitize(tx)); // FIX APPLIED

    await file.writeAsString(jsonEncode(list));
  }

  // --------------------------------------------------------
  //  LOAD ALL PENDING ITEMS
  // --------------------------------------------------------
  static Future<List<Map<String, dynamic>>> loadPending() async {
    final file = await _getFile();
    if (!await file.exists()) return [];

    final list = jsonDecode(await file.readAsString());
    return List<Map<String, dynamic>>.from(list);
  }

  // --------------------------------------------------------
  //  REMOVE FIRST PENDING ITEM (AFTER SUCCESSFUL SYNC)
  // --------------------------------------------------------
  static Future<void> removeFirst() async {
    final file = await _getFile();
    if (!await file.exists()) return;

    final list = jsonDecode(await file.readAsString());
    if (list.isNotEmpty) list.removeAt(0);

    await file.writeAsString(jsonEncode(list));
  }

  // --------------------------------------------------------
  //  CLEAR ALL PENDING ITEMS
  // --------------------------------------------------------
  static Future<void> clearPending() async {
    final file = await _getFile();
    if (await file.exists()) {
      await file.writeAsString(jsonEncode([]));
    }
  }
}
