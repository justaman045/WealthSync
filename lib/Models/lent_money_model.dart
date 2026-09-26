import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:money_control/Utils/num_parse.dart';

class LentRepayment {
  final double amount;
  final DateTime date;
  final String note;

  LentRepayment({
    required this.amount,
    required this.date,
    this.note = '',
  });

  factory LentRepayment.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate;
    final rawDate = map['date'];
    if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return LentRepayment(
      amount: _parseNum(map['amount']),
      date: parsedDate,
      note: map['note'] ?? '',
    );
  }

  static double _parseNum(dynamic value) => safeToDouble(value);

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'note': note,
    };
  }
}

class LentMoneyModel {
  final String id;
  final String friendName;
  final double amount;
  final String note;
  final DateTime dateLent;
  final bool isSettled;
  final String type; // 'lent' or 'borrowed'
  final DateTime? createdAt;
  final List<LentRepayment> repayments;

  LentMoneyModel({
    required this.id,
    required this.friendName,
    required this.amount,
    this.note = '',
    required this.dateLent,
    this.isSettled = false,
    this.type = 'lent',
    this.createdAt,
    this.repayments = const [],
  });

  factory LentMoneyModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime parsedDate;
    final rawDate = map['dateLent'];
    if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    final repayments = <LentRepayment>[];
    final rawRepayments = map['repayments'];
    if (rawRepayments is List) {
      for (final item in rawRepayments) {
        if (item is Map) {
          repayments.add(LentRepayment.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    return LentMoneyModel(
      id: id,
      friendName: map['friendName'] ?? '',
      amount: _parseNum(map['amount']),
      note: map['note'] ?? '',
      dateLent: parsedDate,
      isSettled: map['isSettled'] ?? false,
      type: map['type']?.toString() ?? 'lent',
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      repayments: repayments,
    );
  }

  static double _parseNum(dynamic value) => safeToDouble(value);

  double get repaidAmount =>
      repayments.fold(0.0, (acc, r) => acc + r.amount);

  double get remainingAmount => (amount - repaidAmount).clamp(0.0, amount);

  Map<String, dynamic> toMap() {
    return {
      'friendName': friendName,
      'amount': amount,
      'note': note,
      'dateLent': Timestamp.fromDate(dateLent),
      'isSettled': isSettled,
      'type': type,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'repayments': repayments.map((r) => r.toMap()).toList(),
    };
  }
}
