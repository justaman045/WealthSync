import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Models/recurring_payment_model.dart';

class DuplicateGroup {
  final String id;
  final String merchant;
  final double amount;
  final DateTime date;
  final List<TransactionModel> transactions;

  DuplicateGroup({
    required this.id,
    required this.merchant,
    required this.amount,
    required this.date,
    required this.transactions,
  });
}

class SignError {
  final String id;
  final TransactionModel transaction;
  final String expected;
  final String actual;

  SignError({
    required this.id,
    required this.transaction,
    required this.expected,
    required this.actual,
  });
}

class OrphanedRecurring {
  final String id;
  final RecurringPayment payment;
  final String reason;

  OrphanedRecurring({required this.id, required this.payment, required this.reason});
}

class BankComparisonRow {
  final List<dynamic> bankRow;
  final TransactionModel? matchedAppTx;
  final String status; // 'matched', 'bank-only', 'app-only'

  BankComparisonRow({
    required this.bankRow,
    this.matchedAppTx,
    required this.status,
  });
}

class LedgerEntry {
  final DateTime date;
  final String description;
  final String category;
  final double? debit;
  final double? credit;
  final double runningBalance;
  final String? transactionId;

  LedgerEntry({
    required this.date,
    required this.description,
    required this.category,
    this.debit,
    this.credit,
    required this.runningBalance,
    this.transactionId,
  });
}
