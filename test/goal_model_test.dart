import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Models/goal_model.dart';

void main() {
  GoalModel goal({
    String id = 'g1',
    String name = 'Goal',
    double target = 1000,
    double saved = 250,
    String? description,
    DateTime? targetDate,
    bool completed = false,
    String emoji = '🎯',
    DateTime? createdAt,
    double monthlyAllocation = 0,
    String? allocationMonth,
  }) =>
      GoalModel(
        id: id,
        name: name,
        targetAmount: target,
        currentAmount: saved,
        description: description,
        targetDate: targetDate,
        isCompleted: completed,
        emoji: emoji,
        createdAt: createdAt,
        monthlyAllocation: monthlyAllocation,
        allocationMonth: allocationMonth,
      );

  group('GoalModel.edited', () {
    test('updates detail fields while preserving identity and progress', () {
      final created = DateTime(2026, 1, 1);
      final edited = goal(
        id: 'g1',
        name: 'Old',
        target: 1000,
        saved: 250,
        emoji: '🏠',
        createdAt: created,
      ).edited(
        name: 'New',
        targetAmount: 2000,
        description: 'why',
        targetDate: DateTime(2026, 12, 31),
        emoji: '✈️',
      );

      expect(edited.id, 'g1');
      expect(edited.currentAmount, 250);
      expect(edited.createdAt, created);
      expect(edited.name, 'New');
      expect(edited.targetAmount, 2000);
      expect(edited.description, 'why');
      expect(edited.targetDate, DateTime(2026, 12, 31));
      expect(edited.emoji, '✈️');
      expect(edited.isCompleted, isFalse);
    });

    test('recomputes isCompleted when the target drops below saved', () {
      final edited = goal(target: 1000, saved: 800, completed: false).edited(
        name: 'G',
        targetAmount: 500,
      );
      expect(edited.isCompleted, isTrue);
    });

    test('recomputes isCompleted when the target rises above saved', () {
      final edited = goal(target: 500, saved: 500, completed: true).edited(
        name: 'G',
        targetAmount: 2000,
      );
      expect(edited.isCompleted, isFalse);
    });

    test('clears description and targetDate when null is passed', () {
      final edited = goal(
        description: 'old desc',
        targetDate: DateTime(2026, 6, 1),
      ).edited(name: 'G', targetAmount: 1000);
      expect(edited.description, isNull);
      expect(edited.targetDate, isNull);
    });
  });

  group('GoalModel.monthlyAllocation', () {
    test('defaults to zero and round-trips through toMap/fromMap', () {
      final withAllocation = GoalModel(
        id: 'g1',
        name: 'Trip',
        targetAmount: 50000,
        monthlyAllocation: 3500,
      );
      final map = withAllocation.toMap();
      expect(map['monthlyAllocation'], 3500);

      // fromMap needs an id and a createdAt; inject minimal fields.
      final restored = GoalModel.fromMap('g1', {
        ...map,
        'createdAt': null,
      });
      expect(restored.monthlyAllocation, 3500);
      expect(goal().monthlyAllocation, 0);
    });

    test('preserved by copyWith and edited', () {
      final g = GoalModel(
        id: 'g1',
        name: 'Trip',
        targetAmount: 50000,
        monthlyAllocation: 3500,
      );
      expect(g.copyWith(currentAmount: 100).monthlyAllocation, 3500);
      expect(
        g.edited(name: 'Trip 2', targetAmount: 60000).monthlyAllocation,
        3500,
      );
      expect(g.copyWith(monthlyAllocation: 2000).monthlyAllocation, 2000);
    });
  });

  group('GoalModel monthly allotment (Add Progress)', () {
    final oct = DateTime(2026, 10, 8);
    final nov = DateTime(2026, 11, 3);

    test('monthKey is zero-padded yyyy-MM', () {
      expect(GoalModel.monthKey(DateTime(2026, 1, 9)), '2026-01');
      expect(GoalModel.monthKey(DateTime(2026, 11, 9)), '2026-11');
    });

    test('allotmentFor only returns the amount for its own month', () {
      final g = goal(
        monthlyAllocation: 3000,
        allocationMonth: GoalModel.monthKey(oct),
      );
      expect(g.allotmentFor(oct), 3000);
      expect(g.allotmentFor(nov), 0);
      // Never allotted — null month never matches.
      expect(goal().allotmentFor(oct), 0);
    });

    test('withProgress accumulates deposits within a month', () {
      final g = goal(target: 50000, saved: 0);
      final first = g.withProgress(3000, oct);
      final second = first.withProgress(2000, oct);

      expect(first.currentAmount, 3000);
      expect(first.monthlyAllocation, 3000);
      expect(first.allotmentFor(oct), 3000);
      expect(second.currentAmount, 5000);
      expect(second.monthlyAllocation, 5000);
      expect(second.allotmentFor(oct), 5000);
    });

    test('withProgress records only the amount actually applied (overshoot capped)', () {
      final g = goal(target: 10000, saved: 9000);
      final updated = g.withProgress(3000, oct);

      expect(updated.currentAmount, 10000);
      // Only 1000 fit; the allotment must not claim the full 3000 deposit.
      expect(updated.monthlyAllocation, 1000);
      expect(updated.isCompleted, isTrue);
    });

    test('withProgress resets the allotment when a new month starts', () {
      final g = goal(
        target: 50000,
        saved: 3000,
        monthlyAllocation: 3000,
        allocationMonth: GoalModel.monthKey(oct),
      );
      final updated = g.withProgress(1500, nov);

      expect(updated.currentAmount, 4500);
      expect(updated.allotmentFor(nov), 1500);
      // The October allotment is no longer visible to the November plan.
      expect(updated.allotmentFor(oct), 0);
    });

    test('withWithdrawal rolls back this month\'s allotment, never below zero', () {
      final g = goal(
        target: 50000,
        saved: 5000,
        monthlyAllocation: 3000,
        allocationMonth: GoalModel.monthKey(oct),
      );
      final partial = g.withWithdrawal(1200, oct);
      expect(partial.currentAmount, 3800);
      expect(partial.allotmentFor(oct), 1800);

      final full = g.withWithdrawal(4000, oct);
      expect(full.currentAmount, 1000);
      expect(full.allotmentFor(oct), 0);
    });

    test('allocationMonth round-trips through toMap/fromMap', () {
      final g = goal(
        monthlyAllocation: 2500,
        allocationMonth: GoalModel.monthKey(oct),
      );
      final map = g.toMap();
      expect(map['allocationMonth'], '2026-10');

      final restored = GoalModel.fromMap('g1', {
        ...map,
        'createdAt': null,
      });
      expect(restored.allocationMonth, '2026-10');
      expect(restored.monthlyAllocation, 2500);
      expect(restored.allotmentFor(oct), 2500);
    });
  });

  group('summarizeGoals', () {
    test('sums targets and saved over active goals only', () {
      final s = summarizeGoals([
        goal(id: 'a', target: 1000, saved: 200),
        goal(id: 'b', target: 500, saved: 300),
        goal(id: 'c', target: 10000, saved: 10000, completed: true),
      ]);
      expect(s.totalTarget, 1500);
      expect(s.totalSaved, 500);
      expect(s.activeCount, 2);
      expect(s.completedCount, 1);
      expect(s.progress, closeTo(1 / 3, 1e-9));
    });

    test('progress is 0 when there are no active targets', () {
      final s = summarizeGoals([
        goal(completed: true, target: 1000, saved: 1000),
      ]);
      expect(s.totalTarget, 0);
      expect(s.totalSaved, 0);
      expect(s.progress, 0);
      expect(s.activeCount, 0);
      expect(s.completedCount, 1);
    });

    test('empty list yields all zeros', () {
      final s = summarizeGoals(const []);
      expect(s.totalTarget, 0);
      expect(s.totalSaved, 0);
      expect(s.progress, 0);
      expect(s.activeCount, 0);
      expect(s.completedCount, 0);
    });

    test('clamps progress to 100%', () {
      final s = summarizeGoals([
        goal(target: 100, saved: 500, completed: false),
      ]);
      expect(s.progress, 1.0);
    });
  });

  // daysLeftAt() exists so this branch is testable at all: the old
  // `DateTime.now()`-only getter could not be pinned to a fixed date.
  group('GoalModel.daysLeftAt', () {
    final now = DateTime(2026, 6, 15, 12);

    test('null deadline yields null (no countdown rendered)', () {
      expect(goal(targetDate: null).daysLeftAt(now), isNull);
    });

    test('a future deadline counts whole days ahead', () {
      expect(goal(targetDate: now.add(const Duration(days: 10))).daysLeftAt(now), 10);
    });

    test('a past deadline goes NEGATIVE — it is not clamped', () {
      // Deliberate: the goals UI renders overdue goals in red, which needs the
      // sign. (Contrast ChallengeModel.daysLeftAt, which floors at 0.)
      final past = now.subtract(const Duration(days: 3));
      expect(goal(targetDate: past).daysLeftAt(now), -3);
    });

    test('the same deadline yields the same value on a later call', () {
      final g = goal(targetDate: now.add(const Duration(days: 5)));
      expect(g.daysLeftAt(now), g.daysLeftAt(now));
    });
  });
}