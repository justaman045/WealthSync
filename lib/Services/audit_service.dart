import 'package:csv/csv.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Models/recurring_payment_model.dart';
import 'package:money_control/Models/audit_models.dart';

class AuditService {
  /// Detect duplicate transactions by merchant + date + amount.
  static List<DuplicateGroup> detectDuplicates(
    List<TransactionModel> transactions,
  ) {
    final groups = <String, List<TransactionModel>>{};
    for (final tx in transactions) {
      final key =
          '${tx.recipientName.toLowerCase()}_${tx.date.day}_${tx.date.month}_${tx.date.year}_${tx.amount.abs()}';
      groups.putIfAbsent(key, () => []).add(tx);
    }
    return groups.entries
        .where((e) => e.value.length > 1)
        .map((e) => DuplicateGroup(
              merchant: e.value.first.recipientName,
              amount: e.value.first.amount.abs(),
              date: e.value.first.date,
              transactions: e.value,
            ))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Detect transactions with wrong sign convention.
  static List<SignError> detectSignErrors(
    List<TransactionModel> transactions,
    String uid,
  ) {
    final errors = <SignError>[];
    for (final tx in transactions) {
      if (tx.senderId == uid && tx.amount > 0) {
        errors.add(SignError(
          transaction: tx,
          expected: 'negative (expense)',
          actual: 'positive (income)',
        ));
      } else if (tx.recipientId == uid && tx.amount < 0) {
        errors.add(SignError(
          transaction: tx,
          expected: 'positive (income)',
          actual: 'negative (expense)',
        ));
      } else if (tx.amount == 0) {
        errors.add(SignError(
          transaction: tx,
          expected: 'non-zero amount',
          actual: 'zero',
        ));
      }
    }
    return errors;
  }

  /// Detect orphaned recurring payments (active but no transaction created).
  static List<OrphanedRecurring> detectOrphanedRecurring(
    List<RecurringPayment> payments,
    List<TransactionModel> transactions,
  ) {
    final now = DateTime.now();
    final orphans = <OrphanedRecurring>[];
    for (final payment in payments) {
      if (!payment.isActive) continue;
      if (payment.nextDueDate.isAfter(now)) continue;
      final hasTx = transactions.any((tx) =>
          tx.recurringPaymentId == payment.id &&
          tx.date.isAfter(payment.nextDueDate.subtract(const Duration(days: 1))));
      if (!hasTx) {
        orphans.add(OrphanedRecurring(
          payment: payment,
          reason: 'No transaction found for due date ${payment.nextDueDate}',
        ));
      }
    }
    return orphans;
  }

  /// Compare bank statement CSV rows against app transactions.
  static Map<String, List<BankComparisonRow>> compareBankStatement(
    List<List<dynamic>> csvRows,
    List<TransactionModel> transactions,
    Map<String, int> columnMap,
    String uid,
  ) {
    final matched = <BankComparisonRow>[];
    final bankOnly = <BankComparisonRow>[];
    final usedTxIds = <String>{};

    for (final row in csvRows) {
      final amount = _parseBankAmount(row, columnMap['amount'] ?? 0);
      final date = _parseBankDate(row, columnMap['date'] ?? 0);
      final merchant = _parseBankString(row, columnMap['merchant'] ?? 0);

      if (amount == null || date == null) {
        bankOnly.add(BankComparisonRow(bankRow: row, status: 'bank-only'));
        continue;
      }

      TransactionModel? bestMatch;
      var bestScore = 0;
      for (final tx in transactions) {
        if (usedTxIds.contains(tx.id)) continue;
        if ((tx.amount.abs() - amount.abs()).abs() > 0.01) continue;
        final dateDiff = tx.date.difference(date).inDays.abs();
        if (dateDiff > 1) continue;
        var score = 100 - dateDiff * 10;
        if (merchant != null &&
            tx.recipientName.toLowerCase().contains(merchant.toLowerCase())) {
          score += 20;
        }
        if (score > bestScore) {
          bestScore = score;
          bestMatch = tx;
        }
      }

      if (bestMatch != null && bestScore >= 80) {
        usedTxIds.add(bestMatch.id);
        matched.add(BankComparisonRow(
          bankRow: row,
          matchedAppTx: bestMatch,
          status: 'matched',
        ));
      } else {
        bankOnly.add(BankComparisonRow(bankRow: row, status: 'bank-only'));
      }
    }

    return {'matched': matched, 'bank-only': bankOnly};
  }

  /// Build a running balance ledger from transactions.
  static List<LedgerEntry> buildLedger(
    List<TransactionModel> transactions,
    double openingBalance,
    String uid,
  ) {
    final sorted = List<TransactionModel>.from(transactions)
      ..sort((a, b) => a.date.compareTo(b.date));
    final entries = <LedgerEntry>[];
    var balance = openingBalance;
    for (final tx in sorted) {
      double? debit;
      double? credit;
      if (tx.senderId == uid) {
        debit = tx.amount.abs() + tx.tax;
        balance -= debit;
      } else if (tx.recipientId == uid) {
        credit = tx.amount.abs();
        balance += credit;
      }
      entries.add(LedgerEntry(
        date: tx.date,
        description: tx.recipientName.isNotEmpty ? tx.recipientName : (tx.note ?? 'Transaction'),
        category: tx.category ?? 'Uncategorized',
        debit: debit,
        credit: credit,
        runningBalance: balance,
        transactionId: tx.id,
      ));
    }
    return entries;
  }

  /// Export ledger to CSV string.
  static String exportLedgerCsv(List<LedgerEntry> entries) {
    final rows = <List<dynamic>>[
      ['Date', 'Description', 'Category', 'Debit', 'Credit', 'Running Balance'],
      ...entries.map((e) => [
            e.date.toIso8601String().substring(0, 10),
            e.description,
            e.category,
            e.debit?.toStringAsFixed(2) ?? '',
            e.credit?.toStringAsFixed(2) ?? '',
            e.runningBalance.toStringAsFixed(2),
          ]),
    ];
    return const ListToCsvConverter().convert(rows);
  }

  static double? _parseBankAmount(List<dynamic> row, int idx) {
    if (idx >= row.length) return null;
    final raw = row[idx].toString().replaceAll(RegExp(r'[^0-9.-]'), '');
    return double.tryParse(raw);
  }

  static DateTime? _parseBankDate(List<dynamic> row, int idx) {
    if (idx >= row.length) return null;
    final raw = row[idx].toString().trim();
    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso;
    final parts = raw.split(RegExp(r'[/\-]'));
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        final y = year < 100 ? 2000 + year : year;
        return DateTime(y, month, day);
      }
    }
    return null;
  }

  static String? _parseBankString(List<dynamic> row, int idx) {
    if (idx >= row.length) return null;
    final raw = row[idx].toString().trim();
    return raw.isEmpty ? null : raw;
  }
}
