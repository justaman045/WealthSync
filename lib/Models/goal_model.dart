import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:money_control/Utils/num_parse.dart';

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

  /// Days until [targetDate], or null when the goal has no deadline.
  ///
  /// [now] is injectable so the null-deadline and negative-day branches are
  /// testable — a hardcoded `DateTime.now()` makes this un-pinnable.
  int? daysLeftAt(DateTime now) {
    if (targetDate == null) return null;
    return targetDate!.difference(now).inDays;
  }

  int? get daysLeft => daysLeftAt(DateTime.now());

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

  /// Returns a copy with edited detail fields, preserving identity, saved
  /// progress and creation time. Nullable args are applied directly (not via
  /// `??`) so a null description/targetDate clears the field. Completion is
  /// recomputed against the new target.
  GoalModel edited({
    required String name,
    required double targetAmount,
    String? description,
    DateTime? targetDate,
    String emoji = '🎯',
  }) {
    return GoalModel(
      id: id,
      name: name,
      targetAmount: targetAmount,
      currentAmount: currentAmount,
      description: description,
      targetDate: targetDate,
      isCompleted: currentAmount >= targetAmount,
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

  static double _parseNum(dynamic value) => safeToDouble(value);

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

/// Aggregate view of a user's goals, computed over **active** (not completed)
/// goals only. Pure and side-effect free so it can be unit-tested without
/// Firebase.
class GoalSummary {
  final double totalTarget;
  final double totalSaved;
  final int activeCount;
  final int completedCount;
  final double progress;

  const GoalSummary({
    required this.totalTarget,
    required this.totalSaved,
    required this.activeCount,
    required this.completedCount,
    required this.progress,
  });
}

GoalSummary summarizeGoals(List<GoalModel> goals) {
  final active = goals.where((g) => !g.isCompleted);
  var totalTarget = 0.0;
  var totalSaved = 0.0;
  for (final g in active) {
    totalTarget += g.targetAmount;
    totalSaved += g.currentAmount;
  }
  final progress = totalTarget > 0 ? (totalSaved / totalTarget).clamp(0.0, 1.0) : 0.0;
  return GoalSummary(
    totalTarget: totalTarget,
    totalSaved: totalSaved,
    activeCount: active.length,
    completedCount: goals.length - active.length,
    progress: progress,
  );
}
