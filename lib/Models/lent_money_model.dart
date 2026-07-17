import 'package:cloud_firestore/cloud_firestore.dart';

class LentMoneyModel {
  final String id;
  final String friendName;
  final double amount;
  final String note;
  final DateTime dateLent;
  final bool isSettled;
  final String type; // 'lent' or 'borrowed'
  final DateTime? createdAt;

  LentMoneyModel({
    required this.id,
    required this.friendName,
    required this.amount,
    this.note = '',
    required this.dateLent,
    this.isSettled = false,
    this.type = 'lent',
    this.createdAt,
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

    return LentMoneyModel(
      id: id,
      friendName: map['friendName'] ?? '',
      amount: _parseNum(map['amount']),
      note: map['note'] ?? '',
      dateLent: parsedDate,
      isSettled: map['isSettled'] ?? false,
      type: map['type']?.toString() ?? 'lent',
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  static double _parseNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'friendName': friendName,
      'amount': amount,
      'note': note,
      'dateLent': Timestamp.fromDate(dateLent),
      'isSettled': isSettled,
      'type': type,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
