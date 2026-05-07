import 'dart:io';
import 'dart:convert';
import 'dart:developer';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:intl/intl.dart';

class ImportService {
  /// Pick a CSV file and return its content as a List of Lists
  static Future<List<List<dynamic>>?> pickAndParseCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        final input = file.openRead();
        final fields = await input
            .transform(utf8.decoder)
            .transform(const CsvToListConverter())
            .toList();
        return fields;
      }
    } catch (e) {
      log("Error picking CSV: $e");
    }
    return null;
  }

  /// Process the raw CSV data into TransactionModel objects based on column mapping
  /// [headerMap] maps internal keys ('amount', 'date', 'note', 'category') to CSV column indices
  static List<TransactionModel> processCSVData(
    List<List<dynamic>> rawData,
    Map<String, int> headerMap,
    String currentUserId, {
    String currency = 'INR',
  }) {
    List<TransactionModel> transactions = [];

    // Skip header row (index 0)
    for (int i = 1; i < rawData.length; i++) {
      try {
        final row = rawData[i];

        // Extract values using the mapped indices
        final dateIndex = headerMap['date'];
        final amountIndex = headerMap['amount'];
        final noteIndex = headerMap['note']; // Optional
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

        // 4. Parse Category
        String category = "Uncategorized";
        if (categoryIndex != null && categoryIndex < row.length) {
          category = row[categoryIndex].toString();
        }

        // Create Model — amount sign determines direction:
        // positive amount → income (recipientId = user), negative → expense (senderId = user)
        final isExpense = amount < 0;
        final tx = TransactionModel(
          id: '',
          senderId: isExpense ? currentUserId : 'csv_import',
          recipientId: isExpense ? 'csv_import' : currentUserId,
          recipientName: note,
          amount: amount,
          currency: currency,
          tax: 0,
          note: "Imported from CSV",
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
