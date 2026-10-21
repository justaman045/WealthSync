import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Models/challenge_model.dart';

/// `daysLeftAt`/`isExpiredAt` exist so the two branches that were previously
/// unpinnable — the negative-day clamp and the "completed is never expired"
/// guard — are covered. Both were reachable production bugs with no test
/// because the getters hardcoded `DateTime.now()`.
void main() {
  SavingsChallengeModel challenge({
    String id = 'c1',
    DateTime? endDate,
    bool completed = false,
    bool active = true,
  }) =>
      SavingsChallengeModel(
        id: id,
        name: 'Challenge',
        description: '',
        targetAmount: 1000,
        startDate: DateTime(2026, 1, 1),
        endDate: endDate ?? DateTime(2026, 12, 31),
        isCompleted: completed,
        isActive: active,
      );

  final now = DateTime(2026, 6, 15, 12);

  group('SavingsChallengeModel.daysLeftAt', () {
    test('counts whole days to a future end date', () {
      expect(challenge(endDate: now.add(const Duration(days: 12))).daysLeftAt(now), 12);
    });

    test('is 0 on the last day', () {
      expect(challenge(endDate: now).daysLeftAt(now), 0);
    });

    /// The clamp is the whole reason this is extracted: a UI countdown must read
    /// "0 days left", never "-4". (GoalModel.daysLeftAt deliberately does NOT
    /// clamp — it needs the sign to render overdue goals in red.)
    test('a past end date floors at 0, never negative', () {
      expect(challenge(endDate: now.subtract(const Duration(days: 4))).daysLeftAt(now), 0);
    });

    test('part of a day still counts as a whole day', () {
      // difference().inDays truncates, so 23h ahead is 0 days.
      expect(challenge(endDate: now.add(const Duration(hours: 23))).daysLeftAt(now), 0);
    });
  });

  group('SavingsChallengeModel.isExpiredAt', () {
    test('false before the deadline', () {
      expect(challenge(endDate: now.add(const Duration(days: 1))).isExpiredAt(now), isFalse);
    });

    test('true after the deadline', () {
      expect(challenge(endDate: now.subtract(const Duration(days: 1))).isExpiredAt(now), isTrue);
    });

    /// Completing a challenge before its deadline must keep it non-expired —
    /// otherwise a finished challenge shows as "expired", which is wrong and
    /// would flip its UI back to the active styling.
    test('a COMPLETED challenge past its deadline is not expired', () {
      final c = challenge(endDate: now.subtract(const Duration(days: 30)), completed: true);
      expect(c.isExpiredAt(now), isFalse);
    });

    test('the comparison is strict — exactly at the deadline is not yet expired', () {
      expect(challenge(endDate: now).isExpiredAt(now), isFalse);
    });
  });
}
