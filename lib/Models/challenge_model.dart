import 'package:cloud_firestore/cloud_firestore.dart';

class SavingsChallengeModel {
  final String id;
  final String name;
  final String description;
  final double targetAmount;
  final DateTime startDate;
  final DateTime endDate;
  final String type; // 'preset' | 'custom'
  final String? presetId;
  final bool isCompleted;
  final bool isActive;
  final String trackingType; // 'savings' | 'no_spend_category'
  final String? trackedCategory;
  final DateTime? createdAt;

  const SavingsChallengeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.targetAmount,
    required this.startDate,
    required this.endDate,
    this.type = 'custom',
    this.presetId,
    this.isCompleted = false,
    this.isActive = true,
    this.trackingType = 'savings',
    this.trackedCategory,
    this.createdAt,
  });

  factory SavingsChallengeModel.fromMap(String id, Map<String, dynamic> map) {
    return SavingsChallengeModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      targetAmount: _parseNum(map['targetAmount']),
      startDate: ((map['startDate'] as dynamic)?.toDate()) ?? DateTime.now(),
      endDate: ((map['endDate'] as dynamic)?.toDate()) ?? DateTime.now(),
      type: map['type'] ?? 'custom',
      presetId: map['presetId'] as String?,
      isCompleted: map['isCompleted'] ?? false,
      isActive: map['isActive'] ?? true,
      trackingType: map['trackingType'] ?? 'savings',
      trackedCategory: map['trackedCategory'] as String?,
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
      'name': name,
      'description': description,
      'targetAmount': targetAmount,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'type': type,
      'presetId': presetId,
      'isCompleted': isCompleted,
      'isActive': isActive,
      'trackingType': trackingType,
      'trackedCategory': trackedCategory,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  SavingsChallengeModel copyWith({bool? isCompleted, bool? isActive}) {
    return SavingsChallengeModel(
      id: id,
      name: name,
      description: description,
      targetAmount: targetAmount,
      startDate: startDate,
      endDate: endDate,
      type: type,
      presetId: presetId,
      isCompleted: isCompleted ?? this.isCompleted,
      isActive: isActive ?? this.isActive,
      trackingType: trackingType,
      trackedCategory: trackedCategory,
      createdAt: createdAt,
    );
  }

  int get daysLeft {
    final diff = endDate.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  bool get isExpired => DateTime.now().isAfter(endDate) && !isCompleted;
}
