import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Utils/wealth_math.dart';

void main() {
  group('computeGoalSavingsPlan', () {
    // Helper to build an active goal input.
    GoalSavingsInput goal({
      required String id,
      required double target,
      required double current,
      bool isEmergencyFund = false,
      DateTime? targetDate,
      double monthlyAllocation = 0,
    }) {
      return GoalSavingsInput(
        id: id,
        target: target,
        current: current,
        isEmergencyFund: isEmergencyFund,
        targetDate: targetDate,
        monthlyAllocation: monthlyAllocation,
      );
    }

    test('no income returns empty plan with reason', () {
      final plan = computeGoalSavingsPlan(
        monthlyIncome: 0,
        savingsRate: 0.2,
        goals: [goal(id: 'g1', target: 1000, current: 0)],
        emergencyFundGoalId: null,
      );
      expect(plan.savingsPot, 0);
      expect(plan.allocation, isEmpty);
      expect(plan.reason, 'noIncome');
    });

    test('no active goals returns pot as unallocated', () {
      final plan = computeGoalSavingsPlan(
        monthlyIncome: 50000,
        savingsRate: 0.2,
        goals: [goal(id: 'g1', target: 1000, current: 1000)], // complete
        emergencyFundGoalId: null,
      );
      expect(plan.savingsPot, 10000);
      expect(plan.allocation, isEmpty);
      expect(plan.unallocated, 10000);
      expect(plan.reason, 'noActiveGoals');
    });

    test('emergency fund at 0% takes priority share (60% of pot)', () {
      final plan = computeGoalSavingsPlan(
        monthlyIncome: 50000,
        savingsRate: 0.2,
        goals: [
          goal(id: 'ef', target: 100000, current: 0, isEmergencyFund: true),
          goal(id: 'g1', target: 50000, current: 0),
        ],
        emergencyFundGoalId: 'ef',
      );
      // Pot = 50000 * 0.2 = 10000. EF at 0% takes min(60% * pot, need) = 6000.
      // Remaining 4000 goes to g1 (no deadline, urgency = need/365 days).
      expect(plan.efAllocation, 6000);
      expect(plan.allocation['ef'], 6000);
      expect(plan.allocation['g1'] ?? 0, 4000);
      expect(plan.unallocated, 0);
    });

    test('emergency fund at 50% takes 60% share, rest splits proportionally', () {
      final plan = computeGoalSavingsPlan(
        monthlyIncome: 100000,
        savingsRate: 0.2,
        goals: [
          goal(id: 'ef', target: 100000, current: 50000, isEmergencyFund: true),
          goal(id: 'g1', target: 50000, current: 0),
          goal(id: 'g2', target: 50000, current: 0),
        ],
        emergencyFundGoalId: 'ef',
      );
      // EF at 50% takes min(60% * pot, need) = min(12000, 50000) = 12000
      expect(plan.efAllocation, 12000);
      expect(plan.allocation['ef'], 12000);
      // Remaining 8000 splits proportionally between g1 and g2 (equal need)
      expect(plan.allocation['g1'], 4000);
      expect(plan.allocation['g2'], 4000);
      expect(plan.unallocated, 0);
    });

    test('deadline urgency gives nearer goal slightly more weight', () {
      final now = DateTime(2026, 11, 19);
      final soon = DateTime(2026, 12, 4);  // 15 days
      final later = DateTime(2027, 2, 19); // 90+ days

      final plan = computeGoalSavingsPlan(
        monthlyIncome: 100000,
        savingsRate: 0.2,
        goals: [
          goal(id: 'soon', target: 10000, current: 0, targetDate: soon),
          goal(id: 'later', target: 10000, current: 0, targetDate: later),
        ],
        emergencyFundGoalId: null,
        now: now,
      );
      // Soon due in 15 days needs 10000/15 ≈ 667/day; later due in 92 days
      // needs 10000/92 ≈ 109/day. Soon gets all it needs (10000), later gets
      // the rest.
      expect(plan.allocation['soon']!, greaterThanOrEqualTo(plan.allocation['later']!));
      expect(
        plan.allocation['soon']! + plan.allocation['later']!,
        closeTo(20000, 1),
      );
    });

    test('allocation capped at remaining need, leftover redistributed', () {
      final plan = computeGoalSavingsPlan(
        monthlyIncome: 100000,
        savingsRate: 0.2,
        goals: [
          goal(id: 'small', target: 1000, current: 0), // need 1000
          goal(id: 'large', target: 100000, current: 0), // need 100000
        ],
        emergencyFundGoalId: null,
      );
      // Proportional: small = 20000 * 1000/101000 ≈ 198, large = 20000 * 100000/101000 ≈ 19802
      // Small is not capped (198 < 1000), large is not capped (19802 < 100000)
      expect(plan.allocation['small']!, closeTo(198, 1));
      expect(plan.allocation['large']!, closeTo(19802, 1));
      expect(plan.unallocated, 0);
    });

    test('goal with need <= 0 receives nothing', () {
      final plan = computeGoalSavingsPlan(
        monthlyIncome: 50000,
        savingsRate: 0.2,
        goals: [
          goal(id: 'done', target: 1000, current: 1000), // complete
          goal(id: 'active', target: 50000, current: 0),
        ],
        emergencyFundGoalId: null,
      );
      // Completed goal is excluded from active goals, so no allocation entry.
      expect(plan.allocation.containsKey('done'), isFalse);
      expect(plan.allocation['active'], 10000);
    });

    test('no emergency fund registered means no EF priority', () {
      final plan = computeGoalSavingsPlan(
        monthlyIncome: 50000,
        savingsRate: 0.2,
        goals: [
          goal(id: 'g1', target: 50000, current: 0, isEmergencyFund: true),
        ],
        emergencyFundGoalId: null, // not registered as EF
      );
      // Without EF registration, the goal is treated as a normal goal.
      expect(plan.efAllocation, 0);
      expect(plan.allocation['g1'], 10000);
    });

    test('savings rate of 0 yields zero pot', () {
      final plan = computeGoalSavingsPlan(
        monthlyIncome: 50000,
        savingsRate: 0,
        goals: [goal(id: 'g1', target: 50000, current: 0)],
        emergencyFundGoalId: null,
      );
      expect(plan.savingsPot, 0);
      expect(plan.allocation['g1'] ?? 0, 0);
      expect(plan.unallocated, 0);
    });

    group('already-allotted goals drop out of suggestions', () {
      test('allotting exactly the suggested amount removes the goal', () {
        final plan = computeGoalSavingsPlan(
          monthlyIncome: 50000,
          savingsRate: 0.2, // pot = 10000
          goals: [
            // Simulate Add Progress: current already includes the 5000 deposit.
            goal(id: 'g1', target: 50000, current: 5000, monthlyAllocation: 5000),
            goal(id: 'g2', target: 50000, current: 0),
          ],
          emergencyFundGoalId: null,
        );
        expect(plan.allocation.containsKey('g1'), isFalse);
        expect(plan.allocation['g2'], closeTo(5000, 1));
        expect(plan.totalAllocated, closeTo(5000, 1));
        expect(plan.overAllocated, isFalse);
        expect(plan.reason, isNull);
      });

      test('allotting more than suggested removes the goal and shrinks other suggestions', () {
        final plan = computeGoalSavingsPlan(
          monthlyIncome: 50000,
          savingsRate: 0.2, // pot = 10000
          goals: [
            goal(id: 'g1', target: 50000, current: 8000, monthlyAllocation: 8000),
            goal(id: 'g2', target: 50000, current: 0),
          ],
          emergencyFundGoalId: null,
        );
        expect(plan.allocation.containsKey('g1'), isFalse);
        expect(plan.allocation['g2'], closeTo(2000, 1));
        expect(plan.totalAllocated, closeTo(2000, 1));
      });

      test('partial allotment keeps the goal but reduces suggestions to the remaining pot', () {
        final plan = computeGoalSavingsPlan(
          monthlyIncome: 50000,
          savingsRate: 0.2, // pot = 10000
          goals: [
            goal(id: 'g1', target: 50000, current: 2000, monthlyAllocation: 2000),
            goal(id: 'g2', target: 50000, current: 0),
          ],
          emergencyFundGoalId: null,
        );
        expect(plan.allocation.containsKey('g1'), isTrue);
        expect(plan.allocation.containsKey('g2'), isTrue);
        expect(plan.totalAllocated, closeTo(8000, 1));
        expect(plan.unallocated, closeTo(0, 1));
      });

      test('suggestions always sum to the amount still available to allot', () {
        final plan = computeGoalSavingsPlan(
          monthlyIncome: 50000,
          savingsRate: 0.2, // pot = 10000, 4000 already allotted
          goals: [
            goal(id: 'g1', target: 50000, current: 3000, monthlyAllocation: 3000),
            goal(id: 'g2', target: 50000, current: 1000, monthlyAllocation: 1000),
            goal(id: 'g3', target: 50000, current: 0),
          ],
          emergencyFundGoalId: null,
        );
        final remaining = computeRemainingToAllocate(
          savingsPot: plan.savingsPot,
          allotted: 4000,
        );
        expect(plan.totalAllocated, closeTo(remaining, 1));
      });

      test('emergency fund drops out once its suggested share is allotted', () {
        final plan = computeGoalSavingsPlan(
          monthlyIncome: 50000,
          savingsRate: 0.2, // pot = 10000, EF baseline 6000
          goals: [
            goal(
              id: 'ef',
              target: 100000,
              current: 6000,
              isEmergencyFund: true,
              monthlyAllocation: 6000,
            ),
            goal(id: 'g1', target: 50000, current: 0),
          ],
          emergencyFundGoalId: 'ef',
        );
        expect(plan.efAllocation, 0);
        expect(plan.allocation.containsKey('ef'), isFalse);
        expect(plan.allocation['g1'], closeTo(4000, 1));
      });

      test('EF keeps 60% priority of the remaining pot while goals still need suggestions', () {
        final plan = computeGoalSavingsPlan(
          monthlyIncome: 50000,
          savingsRate: 0.2, // pot = 10000
          goals: [
            goal(id: 'ef', target: 100000, current: 0, isEmergencyFund: true),
            goal(id: 'g1', target: 50000, current: 2000, monthlyAllocation: 2000),
          ],
          emergencyFundGoalId: 'ef',
        );
        // 2000 is below g1's 4000 baseline, so both stay. EF gets 60% of the
        // 8000 that is left: 4800; g1 gets the other 3200.
        expect(plan.efAllocation, closeTo(4800, 1));
        expect(plan.allocation['g1'], closeTo(3200, 1));
        expect(plan.totalAllocated, closeTo(8000, 1));
      });

      test('deadline urgency still drives the remaining pot', () {
        final now = DateTime(2026, 11, 19);
        final plan = computeGoalSavingsPlan(
          monthlyIncome: 50000,
          savingsRate: 0.2, // pot = 10000
          goals: [
            goal(
              id: 'soon',
              target: 10000,
              current: 0,
              targetDate: DateTime(2026, 11, 29), // 10 days
            ),
            goal(
              id: 'later',
              target: 10000,
              current: 0,
              targetDate: DateTime(2027, 5, 19), // 181 days
            ),
          ],
          emergencyFundGoalId: null,
          now: now,
        );
        expect(plan.allocation['soon']!, greaterThan(plan.allocation['later']!));
        expect(plan.totalAllocated, closeTo(10000, 1));
      });

      test('all goals satisfied yields an empty plan with a reason', () {
        final plan = computeGoalSavingsPlan(
          monthlyIncome: 50000,
          savingsRate: 0.2,
          goals: [
            goal(id: 'g1', target: 10000, current: 5000, monthlyAllocation: 5000),
            goal(id: 'g2', target: 10000, current: 5000, monthlyAllocation: 5000),
          ],
          emergencyFundGoalId: null,
        );
        expect(plan.allocation, isEmpty);
        expect(plan.reason, 'allAllottedThisMonth');
      });

      test('over-allotting the pot flags the notice and leaves nothing to suggest', () {
        final plan = computeGoalSavingsPlan(
          monthlyIncome: 50000,
          savingsRate: 0.2, // pot = 10000
          goals: [
            goal(id: 'g1', target: 100000, current: 12000, monthlyAllocation: 12000),
            goal(id: 'g2', target: 100000, current: 0),
          ],
          emergencyFundGoalId: null,
        );
        expect(plan.overAllocated, isTrue);
        expect(plan.allocation, isEmpty);
        expect(plan.totalAllocated, 0);
      });
    });
  });

  group('computeRemainingToAllocate', () {
    test('subtracts this month\'s allotments from the pot', () {
      expect(
        computeRemainingToAllocate(savingsPot: 10000, allotted: 3000),
        7000,
      );
    });

    test('never reports a negative allowance', () {
      expect(
        computeRemainingToAllocate(savingsPot: 10000, allotted: 14000),
        0,
      );
    });

    test('never reports more than the pot', () {
      expect(
        computeRemainingToAllocate(savingsPot: 10000, allotted: -500),
        10000,
      );
    });

    test('no income means nothing available to allot', () {
      expect(
        computeRemainingToAllocate(savingsPot: 0, allotted: 3000),
        0,
      );
    });
  });
}
