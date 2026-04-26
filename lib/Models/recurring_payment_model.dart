import 'package:cloud_firestore/cloud_firestore.dart';

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
    };
  }

  factory RecurringPayment.fromMap(String id, Map<String, dynamic> map) {
    return RecurringPayment(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? 'Unknown',
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? 'Other',
      frequency: RecurringFrequency.values.firstWhere(
        (e) => e.name == map['frequency'],
        orElse: () => RecurringFrequency.monthly,
      ),
      startDate: (map['startDate'] as Timestamp).toDate(),
      nextDueDate: (map['nextDueDate'] as Timestamp).toDate(),
      isActive: map['isActive'] ?? true,
    );
  }
}
