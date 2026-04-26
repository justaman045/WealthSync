import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String senderId;
  final String recipientId;
  final String recipientName;
  final double amount;
  final String currency;
  final double tax;
  final String? note;
  final String? category;
  final DateTime date;
  final String? attachmentUrl; // Could be avatar url or similar
  final String? status;
  final Timestamp? createdAt;
  final String? recurringPaymentId;

  TransactionModel({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.recipientName,
    required this.amount,
    required this.currency,
    required this.tax,
    this.note,
    this.category,
    required this.date,
    this.attachmentUrl,
    this.status,
    this.createdAt,
    this.recurringPaymentId,
  });

  double get total => amount + tax;

  String? get recipientAvatar => attachmentUrl;

  factory TransactionModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime parsedDate;

    final rawDate = map['date'];

    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return TransactionModel(
      id: id,
      senderId: map['senderId'] ?? '',
      recipientId: map['recipientId'] ?? '',
      recipientName: map['recipientName'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'INR',
      tax: (map['tax'] ?? 0).toDouble(),
      note: map['note'],
      category: map['category'],
      date: parsedDate,
      attachmentUrl: map['attachmentUrl'],
      status: map['status'],
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp)
          : Timestamp.now(),
      recurringPaymentId: map['recurringPaymentId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'recipientId': recipientId,
      'recipientName': recipientName,
      'amount': amount,
      'currency': currency,
      'tax': tax,
      'note': note,
      'category': category,
      'date': Timestamp.fromDate(date),
      'attachmentUrl': attachmentUrl,
      'status': status ?? 'success',
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'recurringPaymentId': recurringPaymentId,
    };
  }
}
