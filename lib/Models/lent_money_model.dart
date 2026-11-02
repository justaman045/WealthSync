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
    return LentRepayment(
      amount: _parseNum(map['amount']),
      date: _parseDate(map['date']),
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

/// Extra money handed over after the original loan (a top-up).
///
/// Kept as a list rather than by editing [LentMoneyModel.amount]: the original
/// principal and the date it was lent are the record of what happened, and
/// rewriting them made a top-up look like the loan had always been bigger.
class LentAdvance {
  final double amount;
  final DateTime date;
  final String note;

  LentAdvance({
    required this.amount,
    required this.date,
    this.note = '',
  });

  factory LentAdvance.fromMap(Map<String, dynamic> map) {
    return LentAdvance(
      amount: _parseNum(map['amount']),
      date: _parseDate(map['date']),
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

DateTime _parseDate(dynamic rawDate) {
  if (rawDate is DateTime) return rawDate;
  if (rawDate is Timestamp) return rawDate.toDate();
  if (rawDate is String) return DateTime.tryParse(rawDate) ?? DateTime.now();
  return DateTime.now();
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

  /// Money lent on top of [amount] after the original entry.
  final List<LentAdvance> advances;

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
    this.advances = const [],
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

    // Documents written before top-ups existed have no `advances` key; an empty
    // list keeps their principal and remaining amount exactly as before.
    final advances = <LentAdvance>[];
    final rawAdvances = map['advances'];
    if (rawAdvances is List) {
      for (final item in rawAdvances) {
        if (item is Map) {
          advances.add(LentAdvance.fromMap(Map<String, dynamic>.from(item)));
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
      // `toMap()` writes a server-timestamp sentinel when `createdAt` is null,
      // so a doc that was just serialized in memory is not a readable one:
      // `.toDate()` on the sentinel throws.
      createdAt: _parseDate(map['createdAt']),
      repayments: repayments,
      advances: advances,
    );
  }

  static double _parseNum(dynamic value) => safeToDouble(value);

  double get repaidAmount =>
      repayments.fold(0.0, (acc, r) => acc + r.amount);

  /// Sum of every top-up recorded after the original loan.
  double get advanceAmount =>
      advances.fold(0.0, (acc, a) => acc + a.amount);

  /// Everything the friend owes on paper: the original loan plus top-ups.
  double get totalPrincipal => amount + advanceAmount;

  /// Outstanding balance. Top-ups raise it, repayments lower it.
  double get remainingAmount =>
      (totalPrincipal - repaidAmount).clamp(0.0, totalPrincipal);

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
      'advances': advances.map((a) => a.toMap()).toList(),
    };
  }
}
