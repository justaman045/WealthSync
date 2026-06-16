import 'dart:convert';
import 'dart:developer';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Services/sms_service.dart';
import 'package:intl/intl.dart';
import 'package:universal_io/io.dart';

class ImportService {
  /// Pick a CSV file and return its content as a List of Lists
  static Future<List<List<dynamic>>?> pickAndParseCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        final file = result.files.single;
        final bytes = file.bytes ?? (kIsWeb ? null : await File(file.path!).readAsBytes());
        if (bytes == null) return null;
        final fields = await utf8.decodeStream(
          Stream.fromIterable([bytes]),
        ).then((text) => const CsvToListConverter().convert(text));
        return fields;
      }
    } catch (e) {
      log("Error picking CSV: $e");
    }
    return null;
  }

  /// Process the raw CSV data into TransactionModel objects based on column mapping
  /// [headerMap] maps internal keys ('amount', 'date', 'note', 'merchant', 'category') to CSV column indices.
  /// If no explicit category column is mapped, the merchant name is run through
  /// the SMS categorization engine for an automatic suggestion.
  static Future<List<TransactionModel>> processCSVData(
    List<List<dynamic>> rawData,
    Map<String, int> headerMap,
    String currentUserId, {
    String currency = 'INR',
  }) async {
    List<TransactionModel> transactions = [];

    // Skip header row (index 0)
    for (int i = 1; i < rawData.length; i++) {
      try {
        final row = rawData[i];

        // Extract values using the mapped indices
        final dateIndex = headerMap['date'];
        final amountIndex = headerMap['amount'];
        final noteIndex = headerMap['note']; // Optional
        final merchantIndex = headerMap['merchant']; // Optional
        final categoryIndex = headerMap['category']; // Optional

        if (dateIndex == null || amountIndex == null) {
          continue; // Skip invalid mapping
        }

        // 1. Parse Date
        DateTime date = DateTime.now();
        final rawDate = row[dateIndex];
        if (rawDate is String) {
          // Attempt standard formats
          date =
              DateTime.tryParse(rawDate) ??
              _tryParseCustomDate(rawDate) ??
              DateTime.now();
        }

        // 2. Parse Amount
        double amount = 0.0;
        final rawAmount = row[amountIndex];
        if (rawAmount is num) {
          amount = rawAmount.toDouble();
        } else if (rawAmount is String) {
          amount =
              double.tryParse(rawAmount.replaceAll(RegExp(r'[^0-9.-]'), '')) ??
              0.0;
        }

        // 3. Parse Note/Description
        String note = "Imported Transaction";
        if (noteIndex != null && noteIndex < row.length) {
          note = row[noteIndex].toString();
        }

        // 4. Parse Merchant name (fall back to note if not mapped)
        String merchant = note;
        if (merchantIndex != null && merchantIndex < row.length) {
          final raw = row[merchantIndex].toString().trim();
          if (raw.isNotEmpty) merchant = raw;
        }

        // 5. Parse Category (with auto-suggest from SMS engine)
        String category = "Uncategorized";
        final hasExplicitCategory =
            categoryIndex != null && categoryIndex < row.length;
        if (hasExplicitCategory) {
          category = row[categoryIndex].toString();
        } else {
          // Auto-suggest category via SMS categorization engine
          final suggested = await SmsService.suggestCategory(merchant);
          if (suggested != 'Uncategorized') category = suggested;
        }

        // Create Model — amount sign determines direction:
        // positive amount → income (recipientId = user), negative → expense (senderId = user)
        final isExpense = amount < 0;
        final tx = TransactionModel(
          id: '',
          senderId: isExpense ? currentUserId : 'csv_import',
          recipientId: isExpense ? 'csv_import' : currentUserId,
          recipientName: merchant,
          amount: amount,
          currency: currency,
          tax: 0,
          note: note,
          category: category,
          date: date,
          status: 'success',
          createdAt: Timestamp.now(),
        );

        transactions.add(tx);
      } catch (e) {
        log("Error parsing row $i: $e");
        continue;
      }
    }
    return transactions;
  }

  static DateTime? _tryParseCustomDate(String dateStr) {
    final formats = [
      DateFormat("dd/MM/yyyy"),
      DateFormat("MM/dd/yyyy"),
      DateFormat("yyyy-MM-dd"),
      DateFormat("dd-MM-yyyy"),
    ];

    for (var format in formats) {
      try {
        return format.parse(dateStr);
      } catch (_) {}
    }
    return null;
  }

  /// Batch save transactions to Firestore (chunked to respect 500-op limit)
  static Future<void> saveTransactionsToFirestore(
    List<TransactionModel> transactions,
    String userId,
  ) async {
    const chunkSize = 499;
    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('transactions');

    for (int i = 0; i < transactions.length; i += chunkSize) {
      final chunk = transactions.sublist(
        i,
        (i + chunkSize).clamp(0, transactions.length),
      );
      final batch = FirebaseFirestore.instance.batch();
      for (var tx in chunk) {
        final docRef = collection.doc();
        batch.set(docRef, tx.toMap());
      }
      await batch.commit();
    }
  }
}
