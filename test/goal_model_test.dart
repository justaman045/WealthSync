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
}
