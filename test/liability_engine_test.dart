import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Models/recurring_payment_model.dart';
import 'package:money_control/Utils/liability_engine.dart';

void main() {
  group('CreditCardEntry.fromInput()', () {
    test('spent mode: outstanding wins, available derived', () {
      final entry = CreditCardEntry.fromInput(
        creditLimit: 100000,
        value: 30000,
        enterAvailable: false,
      );
      expect(entry.spentOrOutstanding, 30000);
      expect(entry.availableBalance, 70000);
      expect(entry.isConsistent, true);
      expect(entry.isOverLimit, false);
    });

    test('available mode: available wins, outstanding derived', () {
      final entry = CreditCardEntry.fromInput(
        creditLimit: 100000,
        value: 70000,
        enterAvailable: true,
      );
      expect(entry.availableBalance, 70000);
      expect(entry.spentOrOutstanding, 30000);
      expect(entry.isConsistent, true);
    });

    test('clamps outstanding at the limit (no over-limit)', () {
      final entry = CreditCardEntry.fromInput(
        creditLimit: 50000,
        value: 80000,
        enterAvailable: false,
      );
      expect(entry.spentOrOutstanding, 50000);
      expect(entry.availableBalance, 0);
      expect(entry.isOverLimit, false);
    });

    test('clamps available at zero (no negative)', () {
      final entry = CreditCardEntry.fromInput(
        creditLimit: 50000,
        value: 0,
        enterAvailable: true,
      );
      expect(entry.availableBalance, 0);
      expect(entry.spentOrOutstanding, 50000);
    });

    test('zero limit yields zero entry', () {
      final entry = CreditCardEntry.fromInput(
        creditLimit: 0,
        value: 1000,
        enterAvailable: false,
      );
      expect(entry.spentOrOutstanding, 0);
      expect(entry.availableBalance, 0);
      expect(entry.isConsistent, true);
    });
  });

  group('recalculateLiability() simple / interest-free', () {
    test('linear reduction from payments', () {
      final result = recalculateLiability(
        principal: 100000,
        monthlyPayment: 5000,
        calculationMethod: CalculationMethod.simple,
        carryForward: CarryForward.never,
        interestRate: 0,
        numberOfPayments: 24,
        termEndDate: null,
        startDate: DateTime(2026, 1, 1),
        paymentsMade: [10000, 10000],
        asOf: DateTime(2026, 3, 1),
      );
      expect(result.outstanding, 80000);
      expect(result.principalPaid, 20000);
      expect(result.totalPaid, 20000);
      expect(result.interestAccrued, 0);
      expect(result.isPaidOff, false);
    });

    test('fully paid off', () {
      final result = recalculateLiability(
        principal: 10000,
        monthlyPayment: 5000,
        calculationMethod: CalculationMethod.simple,
        carryForward: CarryForward.never,
        interestRate: 0,
        numberOfPayments: 2,
        termEndDate: null,
        startDate: DateTime(2026, 1, 1),
        paymentsMade: [10000],
        asOf: DateTime(2026, 2, 1),
      );
      expect(result.outstanding, 0);
      expect(result.isPaidOff, true);
    });

    test('clamps at zero, never negative', () {
      final result = recalculateLiability(
        principal: 5000,
        monthlyPayment: 1000,
        calculationMethod: CalculationMethod.simple,
        carryForward: CarryForward.never,
        interestRate: 0,
        numberOfPayments: 6,
        termEndDate: null,
        startDate: DateTime(2026, 1, 1),
        paymentsMade: [10000],
        asOf: DateTime(2026, 2, 1),
      );
      expect(result.outstanding, 0);
      expect(result.principalPaid, 5000);
    });
  });

  group('recalculateLiability() amortizing', () {
    test('reducing balance with interest', () {
      final result = recalculateLiability(
        principal: 120000,
        monthlyPayment: 20000,
        calculationMethod: CalculationMethod.amortizing,
        carryForward: CarryForward.never,
        interestRate: 12,
        numberOfPayments: 12,
        termEndDate: null,
        startDate: DateTime(2026, 1, 1),
        paymentsMade: [20000, 20000],
        asOf: DateTime(2026, 3, 1),
      );
      // After 2 months at 1%/month:
      // Month 1: interest=1200, principal=18800, remaining=101200
      // Month 2: interest=1012, principal=18988, remaining=82212
      expect(result.outstanding, lessThan(120000));
      expect(result.outstanding, greaterThan(0));
      expect(result.interestAccrued, greaterThan(0));
      expect(result.principalPaid, greaterThan(0));
      expect(result.totalPaid, 40000);
      expect(result.isPaidOff, false);
    });

    test('monthly due matches EMI formula', () {
      final result = recalculateLiability(
        principal: 100000,
        monthlyPayment: 0, // ignored when amortizing
        calculationMethod: CalculationMethod.amortizing,
        carryForward: CarryForward.never,
        interestRate: 12,
        numberOfPayments: 12,
        termEndDate: null,
        startDate: DateTime(2026, 1, 1),
        paymentsMade: [],
        asOf: DateTime(2026, 1, 1),
      );
      // EMI = P * r * (1+r)^n / ((1+r)^n - 1), r=0.01, n=12
      // ≈ 8885
      expect(result.monthlyDue, closeTo(8885, 1));
    });
  });

  group('buildAmortizationSchedule()', () {
    test('produces one row per month until paid off', () {
      final schedule = buildAmortizationSchedule(
        principal: 30000,
        monthlyPayment: 10000,
        interestRate: 0,
      );
      expect(schedule.length, 3);
      expect(schedule.last.closingBalance, 0);
      expect(schedule.fold<double>(0, (s, r) => s + r.principalPaid), 30000);
      expect(schedule.fold<double>(0, (s, r) => s + r.interestPaid), 0);
    });

    test('interest rows accrue interest', () {
      final schedule = buildAmortizationSchedule(
        principal: 12000,
        monthlyPayment: 1000,
        interestRate: 12,
      );
      expect(schedule.first.interestPaid, 120); // 12000 * 1%
      expect(schedule.last.closingBalance, 0);
    });
  });

  group('creditCardOutstandingUnified()', () {
    test('sums portfolio tracked + recurring credit-card kind', () {
      final payments = [
        RecurringPayment(
          id: '1', userId: 'u', title: 'Card A', amount: 5000,
          category: 'Credit Card', frequency: RecurringFrequency.monthly,
          startDate: DateTime(2026, 1, 1), nextDueDate: DateTime(2026, 12, 1),
          isActive: true, kind: RecurringKind.creditCard, outstanding: 20000,
        ),
        RecurringPayment(
          id: '2', userId: 'u', title: 'Card B', amount: 5000,
          category: 'Credit Card', frequency: RecurringFrequency.monthly,
          startDate: DateTime(2026, 1, 1), nextDueDate: DateTime(2026, 12, 1),
          isActive: true, kind: RecurringKind.creditCard, outstanding: 30000,
        ),
        RecurringPayment(
          id: '3', userId: 'u', title: 'Netflix', amount: 500,
          category: 'Subscription', frequency: RecurringFrequency.monthly,
          startDate: DateTime(2026, 1, 1), nextDueDate: DateTime(2026, 12, 1),
          isActive: true, kind: RecurringKind.bill,
        ),
      ];
      final total = creditCardOutstandingUnified(
        portfolioCreditCard: 15000,
        recurringPayments: payments,
      );
      expect(total, 65000); // 15000 + 20000 + 30000
    });

    test('excludes inactive and non-credit-card-kind', () {
      final payments = [
        RecurringPayment(
          id: '1', userId: 'u', title: 'Card A', amount: 5000,
          category: 'Credit Card', frequency: RecurringFrequency.monthly,
          startDate: DateTime(2026, 1, 1), nextDueDate: DateTime(2026, 12, 1),
          isActive: false, kind: RecurringKind.creditCard, outstanding: 20000,
        ),
      ];
      final total = creditCardOutstandingUnified(
        portfolioCreditCard: 0,
        recurringPayments: payments,
      );
      expect(total, 0);
    });
  });

  group('totalLiabilityOutstanding()', () {
    test('sums all liability-kind recurring payments', () {
      final payments = [
        RecurringPayment(
          id: '1', userId: 'u', title: 'Card', amount: 5000,
          category: 'Credit Card', frequency: RecurringFrequency.monthly,
          startDate: DateTime(2026, 1, 1), nextDueDate: DateTime(2026, 12, 1),
          isActive: true, kind: RecurringKind.creditCard, outstanding: 10000,
        ),
        RecurringPayment(
          id: '2', userId: 'u', title: 'EMI', amount: 5000,
          category: 'EMI', frequency: RecurringFrequency.monthly,
          startDate: DateTime(2026, 1, 1), nextDueDate: DateTime(2026, 12, 1),
          isActive: true, kind: RecurringKind.loanEmi, outstanding: 50000,
        ),
        RecurringPayment(
          id: '3', userId: 'u', title: 'Bill', amount: 500,
          category: 'Subscription', frequency: RecurringFrequency.monthly,
          startDate: DateTime(2026, 1, 1), nextDueDate: DateTime(2026, 12, 1),
          isActive: true, kind: RecurringKind.bill,
        ),
      ];
      expect(totalLiabilityOutstanding(payments), 60000);
    });
  });
}
