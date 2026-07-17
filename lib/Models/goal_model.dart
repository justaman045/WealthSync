import 'package:cloud_firestore/cloud_firestore.dart';

class GoalModel {
  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final String? description;
  final DateTime? targetDate;
  final bool isCompleted;
  final String emoji;
  final DateTime? createdAt;

  const GoalModel({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    this.description,
    this.targetDate,
    this.isCompleted = false,
    this.emoji = '🎯',
    this.createdAt,
  });

  double get progress =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0;

  int? get daysLeft {
    if (targetDate == null) return null;
    return targetDate!.difference(DateTime.now()).inDays;
  }

  GoalModel copyWith({
    double? currentAmount,
    bool? isCompleted,
  }) {
    return GoalModel(
      id: id,
      name: name,
      targetAmount: targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      description: description,
      targetDate: targetDate,
      isCompleted: isCompleted ?? this.isCompleted,
      emoji: emoji,
      createdAt: createdAt,
    );
  }

  factory GoalModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime? parsedTargetDate;
    final rawTarget = map['targetDate'];
    if (rawTarget is DateTime) {
      parsedTargetDate = rawTarget;
    } else if (rawTarget is Timestamp) {
      parsedTargetDate = rawTarget.toDate();
    } else if (rawTarget is String) {
      parsedTargetDate = DateTime.tryParse(rawTarget);
    }

    return GoalModel(
      id: id,
      name: map['name'] ?? '',
      targetAmount: _parseNum(map['targetAmount']),
      currentAmount: _parseNum(map['currentAmount']),
      description: map['description'] as String?,
      targetDate: parsedTargetDate,
      isCompleted: map['isCompleted'] ?? false,
      emoji: map['emoji'] ?? '🎯',
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
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'description': description,
      'targetDate': targetDate != null ? Timestamp.fromDate(targetDate!) : null,
      'isCompleted': isCompleted,
      'emoji': emoji,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
