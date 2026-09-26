import 'dart:convert';
import 'dart:developer';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Services/local_backup_service.dart';
import 'package:money_control/Services/budget_service.dart';
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
  /// Returns the parsed transactions plus the number of rows skipped because
  /// they were unreadable (missing mapping, empty cell, parse error).
  static Future<({List<TransactionModel> transactions, int skipped})>
      processCSVData(
    List<List<dynamic>> rawData,
    Map<String, int> headerMap,
    String currentUserId, {
    String currency = 'INR',
  }) async {
    List<TransactionModel> transactions = [];
    var skipped = 0;

    // Prime the SMS categorization caches once so the per-row
    // suggestCategory() calls below are pure in-memory lookups.
    await SmsService.loadCorrectionCache();
    await SmsService.buildHistoryCache();

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

        final typeIndex = headerMap['type']; // Optional direction column
        if (dateIndex == null ||
            amountIndex == null ||
            dateIndex >= row.length ||
            amountIndex >= row.length) {
          skipped++; // Skip invalid mapping
          continue;
        }

        // 1. Parse Date
        DateTime? parsedDate;
        final rawDate = row[dateIndex];
        if (rawDate is String && rawDate.trim().isNotEmpty) {
          parsedDate =
              DateTime.tryParse(rawDate) ?? _tryParseCustomDate(rawDate);
          if (parsedDate == null) {
            skipped++; // Unrecognized date format — never silently stamp "today"
            continue;
          }
        } else if (rawDate is num) {
          skipped++; // Numeric/Excel-serial dates aren't supported
          continue;
        }
        // Empty date cells default to today so the row can still import.
        final date = parsedDate ?? DateTime.now();

        // 2. Parse Amount
        double amount = 0.0;
        final rawAmount = row[amountIndex];
        if (rawAmount is num) {
          amount = rawAmount.toDouble();
        } else if (rawAmount is String) {
          final trimmed = rawAmount.trim();
          final isAccounting = trimmed.contains('(') && trimmed.contains(')');
          final lower = trimmed.toLowerCase();
          // Bank exports often carry a DR/CR (or Debit/Credit) suffix that
          // decides the direction — honor it when present.
          final isDebitSuffix =
              RegExp(r'\b(dr|debit|withdrawn|sent|deducted)$').hasMatch(lower);
          final isCreditSuffix = RegExp(
            r'\b(cr|credit|deposit|received|credited)$',
          ).hasMatch(lower);
          final cleaned = trimmed.replaceAll(RegExp(r'[^0-9.-]'), '');
          final parsed = double.tryParse(cleaned);
          if (parsed == null) {
            skipped++; // Unreadable amount
            continue;
          }
          amount = isAccounting ? -parsed.abs() : parsed;
          if (isDebitSuffix) amount = -amount.abs();
          if (isCreditSuffix) amount = amount.abs();
        }
        if (amount == 0.0) {
          skipped++; // Blank/zero-amount rows aren't meaningful transactions
          continue;
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

        // Direction: an explicit Type/Dr-Cr column wins over the sign, because
        // most bank and card exports keep expenses positive and record the
        // direction in their own column. Without that column the sign is the
        // only signal available, so it is what decides.
        var isExpense = amount < 0;
        if (typeIndex != null && typeIndex < row.length) {
          isExpense =
              _isDebitType(row[typeIndex].toString(), amount, fallback: isExpense);
        }
        if (isExpense) {
          amount = -amount.abs();
        } else {
          amount = amount.abs();
        }
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
          createdAt: DateTime.now(),
        );

        transactions.add(tx);
      } catch (e) {
        log("Error parsing row $i: $e");
        skipped++; // Skip unreadable row
        continue;
      }
    }
    return (transactions: transactions, skipped: skipped);
  }

  /// Decides a row's direction from its Type/Dr-Cr cell, falling back to the
  /// amount's sign when the cell is absent or merely descriptive (an "ATM
  /// Withdrawal" narration carries no direction token to match on).
  static bool _isDebitType(String rawType, double amount, {bool? fallback}) {
    final signFallback = fallback ?? amount < 0;
    final type = rawType.trim().toLowerCase();
    if (type.isEmpty) return signFallback;
    final isDebit = RegExp(
      r'^(dr|debit|expense|payment|paid|out|withdrawal|spent)\b',
    ).hasMatch(type);
    final isCredit = RegExp(
      r'^(cr|credit|income|refund|received|deposit|in)\b',
    ).hasMatch(type);
    if (isDebit || isCredit) return isDebit;
    return signFallback;
  }

  /// Test seam for [processCSVData]'s direction decision.
  @visibleForTesting
  static bool debugDirection(String type, double amount) =>
      _isDebitType(type, amount);

  /// Test seam for the date disambiguation in [_tryParseCustomDate].
  @visibleForTesting
  static DateTime? debugTryParseDate(String raw) => _tryParseCustomDate(raw);

  static DateTime? _tryParseCustomDate(String dateStr) {
    final trimmed = dateStr.trim();
    final dayFirst = _dayComesFirst(trimmed);
    final parts = trimmed.split(RegExp(r'[/.\-\s]'));
    // intl's yyyy token happily reads a 2-digit year, so "28-01-26" would
    // otherwise land on year 26. The year leads in ISO order and trails in
    // day/month-first order, so both ends have to be checked.
    final fourDigitYear =
        parts.isNotEmpty && (parts.first.length >= 4 || parts.last.length >= 4);
    final isoLeading = RegExp(r'^\d{4}[-/.]').hasMatch(trimmed);

    List<DateFormat> numeric(bool day) {
      final long = day
          ? [DateFormat("dd/MM/yyyy"), DateFormat("dd-MM-yyyy")]
          : [DateFormat("MM/dd/yyyy"), DateFormat("MM-dd-yyyy")];
      final short = day
          ? [DateFormat("dd/MM/yy"), DateFormat("dd-MM-yy")]
          : [DateFormat("MM/dd/yy"), DateFormat("MM-dd-yy")];
      return fourDigitYear ? [...long, ...short] : short;
    }

    final named = fourDigitYear
        ? [DateFormat("dd-MMM-yyyy"), DateFormat("dd-MMM-yy")]
        : [DateFormat("dd-MMM-yy")];

    final formats = <DateFormat>[
      if (isoLeading && fourDigitYear) ...[
        DateFormat("yyyy-MM-dd"),
        DateFormat("yyyy/MM/dd"),
      ],
      ...numeric(dayFirst),
      ...numeric(!dayFirst),
      ...named,
      DateFormat("dd/MMM/yyyy"),
      DateFormat("dd MMM yyyy"),
      DateFormat("MMM dd, yyyy"),
    ];

    for (var format in formats) {
      try {
        return format.parse(trimmed);
      } catch (e) { debugPrint('Date format parse attempt failed: $e'); }
    }
    return null;
  }

  /// Decides whether a numeric `d/m/y` date reads day-first or month-first.
  ///
  /// A leading component above 12 can only be a day, a second component above
  /// 12 can only be a month, so "13/02/2026" and "02/13/2026" are each
  /// unambiguous even though a fixed format order would misread one of them.
  /// When both fit either reading the date is genuinely ambiguous, and dd/MM
  /// wins because the app's exports are Indian.
  static bool _dayComesFirst(String dateStr) {
    final parts = dateStr.split(RegExp(r'[/.\-\s]'));
    if (parts.length < 2) return true;
    final first = int.tryParse(parts[0]);
    final second = int.tryParse(parts[1]);
    if (first == null || second == null) return true;
    if (first > 12) return true;
    if (second > 12) return false;
    return true;
  }

  /// Batch save transactions to Firestore (chunked to respect 500-op limit).
  /// [userEmail] is the Firestore doc id (`users/{userEmail}/transactions`).
  /// Rows that already exist (same date + merchant + amount) are skipped so
  /// re-importing the same file does not create duplicates.
  /// Returns the number of transactions actually written.
  static Future<int> saveTransactionsToFirestore(
    List<TransactionModel> transactions,
    String userEmail,
  ) async {
    if (transactions.isEmpty) return 0;
    const chunkSize = 499;
    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(userEmail)
        .collection('transactions');

    final existing = <String>{};
    try {
      final snap = await collection.get();
      for (final doc in snap.docs) {
        final d = doc.data();
        existing.add(
          _fingerprint(d['date'], d['recipientName'], d['amount']),
        );
      }
    } catch (e) {
      log("Import dedupe fetch failed, continuing without dedupe: $e");
    }

    final toSave = transactions
        .where((tx) =>
            !existing.contains(_fingerprint(tx.date, tx.recipientName, tx.amount)))
        .toList();
    if (toSave.isEmpty) return 0;

    for (int i = 0; i < toSave.length; i += chunkSize) {
      final chunk = toSave.sublist(
        i,
        (i + chunkSize).clamp(0, toSave.length),
      );
      final batch = FirebaseFirestore.instance.batch();
      for (var tx in chunk) {
        final docRef = collection.doc();
        batch.set(docRef, tx.toMap());
      }
      await batch.commit();
    }
    if (toSave.isNotEmpty) {
      // A bulk CSV import is the one write path most likely to lose a lot of
      // data at once, so the on-device mirror must cover it. The coalescing
      // service makes the extra call free inside the throttle window.
      LocalBackupService.backupUserTransactions(
        userEmail,
        reportErrors: false,
      );
      // Bulk imports bypass the add/edit screens that normally raise the
      // alert, so a file that blows a budget stayed silent. Only expense
      // categories are checked, matching the `isSend` gate in the controller.
      for (final category in toSave
          .where((t) => t.amount < 0)
          .map((t) => t.category)
          .whereType<String>()
          .where((c) => c.isNotEmpty)
          .toSet()) {
        await BudgetService.checkBudgetExceeded(
          userId: userEmail,
          category: category,
        );
      }
    }
    return toSave.length;
  }

  static String _fingerprint(dynamic date, dynamic merchant, dynamic amount) {
    DateTime dt;
    if (date is DateTime) {
      dt = date;
    } else if (date is Timestamp) {
      dt = date.toDate();
    } else {
      dt = DateTime.now();
    }
    final day =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    final amt = amount is num ? amount.toDouble().toStringAsFixed(2) : '0.00';
    final name = merchant?.toString().trim().toLowerCase() ?? '';
    return '$day|$name|$amt';
  }
}
