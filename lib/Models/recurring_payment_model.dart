import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:money_control/Utils/num_parse.dart';

enum RecurringFrequency { monthly, weekly, yearly }

/// What a recurring payment actually is. Bills are ordinary committed
/// expenses; a credit card payment and a loan EMI are also *liabilities* — they
/// carry an outstanding balance the user is still paying down, which the bills
/// screen and AI Insights surface separately.
///
/// Stored as the enum `name`; a doc without the field (every subscription
/// created before this existed) reads back as [bill].
enum RecurringKind { bill, creditCard, loanEmi }

extension RecurringKindX on RecurringKind {
  bool get isLiability => this != RecurringKind.bill;
}

class RecurringPayment {
  final String id;
  final String userId;
  final String title;
  final double amount;
  final String category;
  final RecurringFrequency frequency;
  final DateTime startDate;
  final DateTime nextDueDate;
  final bool isActive;
  final bool autoPay;

  /// Bill, credit card payment or loan EMI. Defaults to [RecurringKind.bill].
  final RecurringKind kind;

  /// Remaining balance owed on a credit card / loan. Only meaningful when
  /// [kind] is a liability; `null` (or 0) means "not tracked".
  final double? outstanding;

  RecurringPayment({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    required this.category,
    required this.frequency,
    required this.startDate,
    required this.nextDueDate,
    required this.isActive,
    this.autoPay = false,
    this.kind = RecurringKind.bill,
    this.outstanding,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'amount': amount,
      'category': category,
      'frequency': frequency.name,
      'startDate': Timestamp.fromDate(startDate),
      'nextDueDate': Timestamp.fromDate(nextDueDate),
      'isActive': isActive,
      'autoPay': autoPay,
      'kind': kind.name,
      'outstanding': outstanding,
    };
  }

  factory RecurringPayment.fromMap(String id, Map<String, dynamic> map) {
    return RecurringPayment(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? 'Unknown',
      amount: _parseNum(map['amount']),
      category: map['category'] ?? 'Other',
      frequency: RecurringFrequency.values.firstWhere(
        (e) => e.name == map['frequency'],
        orElse: () => RecurringFrequency.monthly,
      ),
      startDate: ((map['startDate'] as dynamic)?.toDate()) ?? DateTime.now(),
      nextDueDate: ((map['nextDueDate'] as dynamic)?.toDate()) ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
      // Opt-in: only explicit `autoPay: true` enables auto-deduction. Docs
      // missing the field (legacy subscriptions created before the auto-pay
      // feature) must NOT silently auto-pay.
      autoPay: map['autoPay'] ?? false,
      // Unknown/absent kind is a plain bill, never a liability: a legacy doc
      // must not start inflating the outstanding-balance total.
      kind: RecurringKind.values.firstWhere(
        (e) => e.name == map['kind'],
        orElse: () => RecurringKind.bill,
      ),
      outstanding: map['outstanding'] is num
          ? _parseNum(map['outstanding'])
          : null,
    );
  }

  /// Monthly cost of this payment, normalised across frequencies so a weekly
  /// or yearly commitment can be compared with monthly ones.
  double get monthlyEquivalent {
    switch (frequency) {
      case RecurringFrequency.monthly:
        return amount;
      case RecurringFrequency.weekly:
        return amount * 52 / 12;
      case RecurringFrequency.yearly:
        return amount / 12;
    }
  }

  static double _parseNum(dynamic value) => roundAmount(safeToDouble(value));

  // Normalize money to paisa precision (2 decimals). Guards against legacy
  // float garbage like 10242.621637042335 leaking into new transactions.
  static double roundAmount(double value) =>
      double.parse(value.toStringAsFixed(2));
}
