import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:money_control/Utils/num_parse.dart';

enum RecurringFrequency { monthly, weekly, yearly }

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
    );
  }

  static double _parseNum(dynamic value) => roundAmount(safeToDouble(value));

  // Normalize money to paisa precision (2 decimals). Guards against legacy
  // float garbage like 10242.621637042335 leaking into new transactions.
  static double roundAmount(double value) =>
      double.parse(value.toStringAsFixed(2));
}
