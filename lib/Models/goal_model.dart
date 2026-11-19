import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
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
  final bool isEmergencyFund;

  /// Amount allotted to this goal **this month** (from the Add Progress sheet).
  /// Cumulative [currentAmount] cannot tell which month a deposit belongs to,
  /// so the month is stamped separately in [allocationMonth] and the amount is
  /// reset when a deposit lands in a later month.
  final double monthlyAllocation;

  /// Calendar month (`yyyy-MM`) [monthlyAllocation] belongs to, or null when
  /// the goal has never received a monthly allotment.
  final String? allocationMonth;

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
    this.isEmergencyFund = false,
    this.monthlyAllocation = 0,
    this.allocationMonth,
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

  /// How much more the goal needs to reach its target (never negative).
  double get remainingNeed => math.max(0.0, targetAmount - currentAmount);

  /// Calendar month key used to scope monthly allotments (`yyyy-MM`).
  /// Kept here (not inline at each call site) so the repository, controller and
  /// screen agree on what "this month" means.
  static String monthKey(DateTime now) =>
      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';

  /// Allotment belonging to [now]'s month; 0 when the stored allotment is from
  /// an earlier month. Allotments do not carry over — a new month starts with a
  /// fresh "Available to allot" allowance.
  double allotmentFor(DateTime now) =>
      allocationMonth == monthKey(now) ? monthlyAllocation : 0.0;

  /// Applies an Add Progress deposit of [addAmount] at [now].
  ///
  /// [currentAmount] grows but is capped at [targetAmount]; [monthlyAllocation]
  /// grows by the amount actually applied (so a deposit that overshoots the
  /// target cannot overstate the month's allotment). A deposit in a new month
  /// resets the previous month's allotment to zero first.
  ///
  /// Pure (no Firestore, no wall clock) so the repository transaction and the
  /// tests share one implementation.
  GoalModel withProgress(double addAmount, DateTime now) {
    final month = monthKey(now);
    final base = allotmentFor(now);
    final newAmount = (currentAmount + addAmount).clamp(0.0, targetAmount);
    final applied = math.max(0.0, newAmount - currentAmount);
    return copyWith(
      currentAmount: newAmount,
      isCompleted: newAmount >= targetAmount,
      monthlyAllocation: base + applied,
      allocationMonth: month,
    );
  }

  /// Reverses a withdrawal at [now], rolling back this month's allotment by the
  /// amount actually removed so "Available to allot" recovers. Withdrawing old
  /// savings in a new month leaves the (already stale) allotment untouched.
  GoalModel withWithdrawal(double subtractAmount, DateTime now) {
    final month = monthKey(now);
    final base = allotmentFor(now);
    final newAmount = math.max(0.0, currentAmount - subtractAmount);
    final removed = math.max(0.0, currentAmount - newAmount);
    return copyWith(
      currentAmount: newAmount,
      isCompleted: newAmount >= targetAmount,
      monthlyAllocation: math.max(0.0, base - removed),
      allocationMonth: month,
    );
  }

  GoalModel copyWith({
    double? currentAmount,
    bool? isCompleted,
    bool? isEmergencyFund,
    double? monthlyAllocation,
    String? allocationMonth,
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
      isEmergencyFund: isEmergencyFund ?? this.isEmergencyFund,
      monthlyAllocation: monthlyAllocation ?? this.monthlyAllocation,
      allocationMonth: allocationMonth ?? this.allocationMonth,
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
    bool? isEmergencyFund,
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
      isEmergencyFund: isEmergencyFund ?? this.isEmergencyFund,
      // Monthly allotment is earned through Add Progress, never the edit form.
      monthlyAllocation: monthlyAllocation,
      allocationMonth: allocationMonth,
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
      isEmergencyFund: map['isEmergencyFund'] ?? false,
      monthlyAllocation: _parseNum(map['monthlyAllocation']),
      allocationMonth: map['allocationMonth'] as String?,
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
      'isEmergencyFund': isEmergencyFund,
      'monthlyAllocation': monthlyAllocation,
      'allocationMonth': allocationMonth,
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
