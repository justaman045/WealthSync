import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Models/recurring_payment_model.dart';
import 'package:money_control/Utils/bills_math.dart';
import 'package:money_control/Utils/wealth_math.dart';

RecurringPayment payment({
  String id = 'p1',
  String title = 'Rent',
  double amount = 15000,
  String category = 'Rent',
  RecurringFrequency frequency = RecurringFrequency.monthly,
  DateTime? nextDueDate,
  bool isActive = true,
  RecurringKind kind = RecurringKind.bill,
  double? outstanding,
}) {
  final due = nextDueDate ?? DateTime(2026, 11, 5);
  return RecurringPayment(
    id: id,
    userId: 'u1',
    title: title,
    amount: amount,
    category: category,
    frequency: frequency,
    startDate: due.subtract(const Duration(days: 30)),
    nextDueDate: due,
    isActive: isActive,
    kind: kind,
    outstanding: outstanding,
  );
}

/// 2026-11 is the current month in these tests.
const int nov = 2026 * 100 + 11;
const int oct = 2026 * 100 + 10;
const int sep = 2026 * 100 + 9;
const int aug = 2026 * 100 + 8;
final _now = DateTime(2026, 11, 15);

void main() {
  group('billMonthlyAverage', () {
    test('averages the months that have spending (500 then 600 is 550)', () {
      expect(billMonthlyAverage([500, 600]), 550);
    });

    test('skips empty months instead of dividing by the window size', () {
      // A user who started two months ago must not have the bill diluted by
      // ten empty months in the 12-month window.
      expect(billMonthlyAverage([500, 0, 600]), 550);
      expect(billMonthlyAverage([0, 0, 0, 0, 300]), 300);
    });

    test('returns 0 with no history', () {
      expect(billMonthlyAverage(const []), 0);
      expect(billMonthlyAverage([0, 0]), 0);
    });
  });

  group('recurring due', () {
    test('counts this month and overdue, ignores inactive and future', () {
      final payments = [
        payment(id: 'this-month', category: 'Rent'),
        payment(
          id: 'overdue',
          category: 'Utilities',
          nextDueDate: DateTime(2026, 9, 3),
        ),
        payment(
          id: 'inactive',
          category: 'Gym',
          isActive: false,
        ),
        payment(
          id: 'future',
          category: 'Insurance',
          nextDueDate: DateTime(2026, 12, 1),
        ),
      ];
      final due = recurringDueByCategory(payments, now: _now);
      expect(due.keys, containsAll(['rent', 'utilities']));
      expect(due.keys, isNot(contains('gym')));
      expect(due.keys, isNot(contains('insurance')));
      expect(due['utilities']!.amount, 15000);
      expect(due['utilities']!.date, DateTime(2026, 9, 3));
    });

    test('normalises weekly and yearly amounts to a monthly equivalent', () {
      final due = recurringDueByCategory([
        payment(
          id: 'w',
          category: 'Milk',
          amount: 120,
          frequency: RecurringFrequency.weekly,
        ),
        payment(
          id: 'y',
          category: 'Insurance',
          amount: 12000,
          frequency: RecurringFrequency.yearly,
        ),
      ], now: _now);
      expect(due['milk']!.amount, closeTo(120 * 52 / 12, 0.001));
      expect(due['insurance']!.amount, 1000);
    });

    test('keeps the earliest date and flags liabilities', () {
      final due = recurringDueByCategory([
        payment(
          id: 'a',
          category: 'Credit Card',
          nextDueDate: DateTime(2026, 11, 20),
          kind: RecurringKind.creditCard,
        ),
        payment(
          id: 'b',
          category: 'Credit Card',
          amount: 500,
          nextDueDate: DateTime(2026, 11, 3),
        ),
      ], now: _now);
      expect(due['credit card']!.amount, 15500);
      expect(due['credit card']!.date, DateTime(2026, 11, 3));
      expect(due['credit card']!.isLiability, isTrue);
    });

    test('liabilityOutstanding sums only active liabilities', () {
      final total = liabilityOutstanding([
        payment(
          id: 'cc',
          category: 'Credit Card',
          kind: RecurringKind.creditCard,
          outstanding: 42000,
        ),
        payment(
          id: 'emi',
          category: 'Loan EMI',
          kind: RecurringKind.loanEmi,
          outstanding: 80000,
        ),
        payment(id: 'rent', category: 'Rent', outstanding: 99999),
        payment(
          id: 'paused',
          category: 'Old EMI',
          kind: RecurringKind.loanEmi,
          outstanding: 5000,
          isActive: false,
        ),
      ]);
      expect(total, 122000);
    });
  });

  group('MonthlyBill', () {
    MonthlyBill bill({
      double auto = 0,
      double override = 0,
      double recurring = 0,
      double spent = 0,
      DailyLimitRole role = DailyLimitRole.fixed,
    }) => MonthlyBill(
      category: 'Rent',
      autoAmount: auto,
      overrideAmount: override,
      recurringDue: recurring,
      spentThisMonth: spent,
      role: role,
    );

    test('plan takes the largest source, never their sum', () {
      // Rent is both a historical average and a recurring payment: counting
      // both would reserve the month's rent twice.
      final b = bill(auto: 15000, recurring: 15000);
      expect(b.plan, 15000);
      expect(b.committed, 15000);
    });

    test('a manual amount wins over auto and recurring', () {
      final b = bill(auto: 15000, recurring: 15000, override: 12000);
      expect(b.isOverridden, isTrue);
      expect(b.plan, 12000);
    });

    test('plan never falls below what was already spent', () {
      expect(bill(auto: 500, spent: 900).plan, 900);
    });

    test('fixed role is committed in full', () {
      expect(bill(auto: 2000, spent: 500).committed, 2000);
    });

    test('discretionary plan is shown but only the unpaid recurring part is '
        'committed', () {
      final b = bill(
        recurring: 500,
        spent: 200,
        role: DailyLimitRole.variable,
      );
      expect(b.plan, 500);
      expect(b.committed, 300);
      // Fully paid recurring in a variable category reserves nothing extra.
      expect(
        bill(recurring: 500, spent: 500, role: DailyLimitRole.variable).committed,
        0,
      );
    });

    test('ignored categories never reserve money', () {
      final b = bill(auto: 10000, recurring: 5000, role: DailyLimitRole.ignored);
      expect(b.committed, 0);
      expect(b.plan, 10000);
    });

    test('isPaid follows the shared paid fraction', () {
      final almost = bill(auto: 1000, spent: 949);
      final paid = bill(auto: 1000, spent: 950);
      expect(almost.isPaid, isFalse);
      expect(almost.isUnpaid, isTrue);
      expect(paid.isPaid, isTrue);
    });
  });

  group('buildMonthlyBills', () {
    MonthlyBills build({
      Map<String, Map<int, double>>? categoryMonthly,
      Map<String, double> overrides = const {},
      Map<String, String> treatmentOverrides = const {},
      List<RecurringPayment> recurring = const [],
    }) => buildMonthlyBills(
      categoryMonthly:
          categoryMonthly ??
          {
            'Food': {sep: 500, oct: 600, nov: 120},
          },
      currentMonthKey: nov,
      historyFloorMonthKey: aug,
      fixedAmountOverrides: overrides,
      treatmentOverrides: treatmentOverrides,
      recurring: recurring,
      now: _now,
    );

    test('uses completed months only, so this month does not inflate it', () {
      final bills = build();
      final food = bills.billFor('Food')!;
      expect(food.autoAmount, 550);
      expect(food.spentThisMonth, 120);
      expect(food.plan, 550);
    });

    test('respects the history floor', () {
      final bills = build(
        categoryMonthly: {
          'Food': {aug: 1000, sep: 500, oct: 600, nov: 0},
        },
      );
      // `aug` is the floor and included; anything older is not in the map.
      expect(bills.billFor('Food')!.autoAmount, 700);
    });

    test('a recurring payment gives a bill to a category with no history', () {
      final bills = build(
        categoryMonthly: const {},
        recurring: [payment(category: 'Rent', amount: 15000)],
      );
      final rent = bills.billFor('Rent')!;
      expect(rent.autoAmount, 0);
      expect(rent.recurringDue, 15000);
      expect(rent.plan, 15000);
      expect(rent.isRecurring, isTrue);
      expect(bills.committedTotal, 15000);
    });

    test('does not double count history and a recurring payment', () {
      final bills = build(
        categoryMonthly: {
          'Rent': {sep: 15000, oct: 15000, nov: 15000},
        },
        recurring: [payment(category: 'Rent', amount: 15000)],
      );
      expect(bills.billFor('Rent')!.plan, 15000);
      expect(bills.committedTotal, 15000);
    });

    test('manual override is applied and reported', () {
      final bills = build(
        categoryMonthly: {
          'Food': {sep: 500, oct: 600},
        },
        overrides: {'food': 900},
      );
      expect(bills.billFor('Food')!.plan, 900);
      expect(bills.billFor('Food')!.isOverridden, isTrue);
    });

    test('committed total reserves bills plus unpaid commitments only', () {
      final bills = build(
        categoryMonthly: {
          'Food': {sep: 500, oct: 600},
          'Rent': {sep: 15000, oct: 15000},
          'SIP': {sep: 5000, oct: 5000},
        },
        treatmentOverrides: const {'sip': 'ignored'},
        recurring: [
          payment(category: 'Rent', amount: 15000),
          payment(
            id: 'sub',
            category: 'Entertainment',
            amount: 499,
          ),
        ],
      );
      // Rent 15000 (fixed, recurring, not double counted) + Entertainment 499
      // (variable role, only the unpaid recurring part). Food is discretionary
      // and has no recurring payment, SIP is ignored.
      expect(bills.committedTotal, 15499);
      expect(bills.billFor('Food')!.committed, 0);
      expect(bills.billFor('SIP')!.committed, 0);
    });

    test('reports liabilities and their outstanding balance', () {
      final bills = build(
        categoryMonthly: const {},
        recurring: [
          payment(
            id: 'cc',
            category: 'Credit Card',
            amount: 4000,
            kind: RecurringKind.creditCard,
            outstanding: 42000,
          ),
        ],
      );
      expect(bills.outstanding, 42000);
      expect(bills.liabilityDueTotal, 4000);
      expect(bills.billFor('Credit Card')!.isLiability, isTrue);
    });

    test('unpaid recurring bills are listed with their due date', () {
      final bills = build(
        categoryMonthly: const {},
        recurring: [
          payment(category: 'Rent', nextDueDate: DateTime(2026, 11, 5)),
          payment(
            id: 'paid',
            category: 'Internet',
            nextDueDate: DateTime(2026, 11, 8),
          ),
        ],
      );
      final unpaid = bills.unpaidRecurring;
      expect(unpaid.map((b) => b.category), containsAll(['Rent', 'Internet']));
      expect(bills.nextDueDate, DateTime(2026, 11, 5));
    });

    test('sorts by planned amount, descending', () {
      final bills = build(
        categoryMonthly: {
          'Food': {sep: 500, oct: 600},
          'Rent': {sep: 15000, oct: 15000},
        },
      );
      expect(bills.categories.map((b) => b.category).first, 'Rent');
    });

    test('planned total includes discretionary plans, committed does not', () {
      final bills = build();
      expect(bills.plannedTotal, 550);
      expect(bills.committedTotal, 0);
    });
  });
}
