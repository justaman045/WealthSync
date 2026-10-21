import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Utils/wealth_math.dart';

/// Minimal transaction fixture. Income convention: `recipientId == uid` with a
/// positive amount; expenses are negative with an empty recipient.
TransactionModel _tx({
  required double amount,
  required DateTime date,
  String? category,
  String senderId = 'me',
  String recipientId = '',
}) {
  return TransactionModel(
    id: '$category-$amount-${date.millisecondsSinceEpoch}',
    senderId: senderId,
    recipientId: recipientId,
    recipientName: category ?? 'x',
    amount: amount,
    currency: 'INR',
    tax: 0,
    category: category,
    date: date,
    createdAt: date,
  );
}

void main() {
  group('milestone() interpolation', () {
    const table = {22: 0.0, 25: 0.5, 30: 2.0, 35: 5.0, 40: 10.0, 50: 20.0, 60: 35.0};

    test('clamps to lowest age', () {
      expect(milestone(18, table), 0.0);
      expect(milestone(22, table), 0.0);
    });

    test('clamps to highest age', () {
      expect(milestone(60, table), 35.0);
      expect(milestone(65, table), 35.0);
    });

    test('returns exact value at exact bracket', () {
      expect(milestone(30, table), 2.0);
      expect(milestone(40, table), 10.0);
      expect(milestone(50, table), 20.0);
    });

    test('linearly interpolates between brackets', () {
      // age 32: 60% between 30(2.0) and 35(5.0)
      final result = milestone(32, table);
      // t = (32-30)/(35-30) = 0.4
      // 2.0 + 0.4 * (5.0 - 2.0) = 2.0 + 1.2 = 3.2
      expect(result, closeTo(3.2, 0.001));
    });

    test('interpolates in first segment', () {
      // age 24: 66.7% between 22(0.0) and 25(0.5)
      final result = milestone(24, table);
      expect(result, closeTo(0.333, 0.001));
    });

    test('interpolates in last segment', () {
      // age 55: 50% between 50(20.0) and 60(35.0)
      final result = milestone(55, table);
      expect(result, closeTo(27.5, 0.001));
    });

    test('handles single-entry table', () {
      expect(milestone(30, {30: 5.0}), 5.0);
      expect(milestone(20, {30: 5.0}), 5.0);
      expect(milestone(40, {30: 5.0}), 5.0);
    });

    test('handles two-entry table', () {
      expect(milestone(22, {20: 0.0, 30: 10.0}), 2.0);
    });
  });

  group('milestone table values are consistent', () {
    test('sipM increases monotonically', () {
      final vals = sipM.values.toList();
      for (int i = 1; i < vals.length; i++) {
        expect(vals[i], greaterThanOrEqualTo(vals[i - 1]),
            reason: 'sipM value at index $i dropped');
      }
    });

    test('pfM corpus at 60 is 36× the age-22 value', () {
      expect(pfM[60]! / pfM[22]!, closeTo(36.0, 1));
    });

    test('insuranceM peaks at 30-40 then tapers', () {
      expect(insuranceM[30]!, greaterThan(insuranceM[25]!));
      expect(insuranceM[40]!, insuranceM[30]!);
      expect(insuranceM[50]!, lessThan(insuranceM[40]!));
      expect(insuranceM[60]!, lessThan(insuranceM[50]!));
    });

    test('cryptoM tapers to 0 by 60', () {
      expect(cryptoM[60]!, 0.0);
    });
  });

  group('compact() number formatting', () {
    test('formats crores', () {
      expect(compact(12300000), '1.2Cr');
      expect(compact(10000000), '1.0Cr');
    });

    test('formats lakhs', () {
      expect(compact(500000), '5.0L');
      expect(compact(999999), '9.9L');
    });

    test('formats thousands', () {
      expect(compact(1500), '1K');
      expect(compact(99999), '99K');
    });

    test('formats small numbers', () {
      expect(compact(999), '999');
      expect(compact(0), '0');
      expect(compact(500), '500');
    });

    test('handles boundary between K and L', () {
      expect(compact(100000), '1.0L');
      expect(compact(99999), '99K');
    });

    test('never overstates the amount', () {
      expect(compact(1999), '1K');
      expect(compact(1099999), '10.9L');
      expect(compact(9999999), '99.9L');
      expect(compact(19999999), '1.9Cr');
    });

    test('keeps the sign on negative amounts', () {
      expect(compact(-1500), '-1K');
      expect(compact(-99999), '-99K');
      expect(compact(-250000), '-2.5L');
    });
  });

  group('calculateIdealIncome()', () {
    test('splits target deficits over months until retirement', () {
      // age 30 → 360 months. Bank 3L + sip 1Cr + fd 3L = 1.06Cr deficit.
      final result = calculateIdealIncome(
        monthlyExpense: 50000,
        age: 30,
        targetEffective: {'bank': 300000, 'sip': 10000000, 'fd': 300000},
        current: {'bank': 0, 'sip': 0, 'fd': 0},
      );
      expect(result.monthlyExpense, 50000);
      // 10600000 / 360 = 29444.44 > 20% floor (10000)
      expect(result.monthlySavingsNeeded, closeTo(29444.44, 0.1));
      expect(result.idealMonthlyIncome, closeTo(79444.44, 0.1));
      expect(result.idealAnnualIncome, closeTo(953333.33, 1));
    });

    test('enforces 20% savings floor when targets are met', () {
      final result = calculateIdealIncome(
        monthlyExpense: 50000,
        age: 30,
        targetEffective: {'bank': 300000, 'sip': 500000},
        current: {'bank': 300000, 'sip': 500000},
      );
      expect(result.monthlySavingsNeeded, 10000);
      expect(result.idealMonthlyIncome, 60000);
    });

    test('excludes insurance coverage from deficits', () {
      // 18.3L investable deficit vs 5Cr insurance — insurance must not count.
      final result = calculateIdealIncome(
        monthlyExpense: 50000,
        age: 30,
        targetEffective: {'bank': 300000, 'sip': 18000000, 'insurance': 50000000},
        current: {'bank': 0, 'sip': 0, 'insurance': 0},
      );
      // (300000 + 18000000) / 360 = 50833.33
      expect(result.monthlySavingsNeeded, closeTo(50833.33, 0.1));
      expect(result.idealMonthlyIncome, closeTo(100833.33, 0.1));
    });

    test('clamps horizon to 12 months at retirement age', () {
      final result = calculateIdealIncome(
        monthlyExpense: 50000,
        age: 60,
        targetEffective: {'bank': 300000},
        current: {'bank': 0},
      );
      // 300000 / 12 = 25000 > floor
      expect(result.monthlySavingsNeeded, 25000);
      expect(result.idealMonthlyIncome, 75000);
    });

    test('handles empty targets and zero expense', () {
      final result = calculateIdealIncome(
        monthlyExpense: 0,
        age: 30,
        targetEffective: {},
        current: {},
      );
      expect(result.idealMonthlyIncome, 0);
      expect(result.idealAnnualIncome, 0);
    });
  });

  group('formatAnnualIncome()', () {
    test('formats INR as LPA', () {
      expect(
        formatAnnualIncome(1580000, currencyCode: 'INR', symbol: '₹'),
        '₹15.8 LPA',
      );
    });

    test('formats INR as Cr p.a. above 1 Cr', () {
      expect(
        formatAnnualIncome(12000000, currencyCode: 'INR', symbol: '₹'),
        '₹1.2 Cr p.a.',
      );
    });

    test('formats non-INR currencies with /yr compact', () {
      expect(
        formatAnnualIncome(85000, currencyCode: 'USD', symbol: r'$'),
        r'$85K/yr',
      );
      expect(
        formatAnnualIncome(1200000, currencyCode: 'EUR', symbol: '€'),
        '€1.2M/yr',
      );
    });
  });

  group('formatMonthlyIncome()', () {
    test('uses en_IN compact for INR', () {
      expect(
        formatMonthlyIncome(130000, currencyCode: 'INR', symbol: '₹'),
        '₹1.3L',
      );
      expect(
        formatMonthlyIncome(7200, currencyCode: 'INR', symbol: '₹'),
        '₹7.2K',
      );
    });

    test('uses en_US compact for other currencies', () {
      expect(
        formatMonthlyIncome(85000, currencyCode: 'USD', symbol: r'$'),
        r'$85K',
      );
    });
  });

  group('formatPercent()', () {
    test('takes the percent itself (no ×100) and rounds up to 2 dp', () {
      expect(formatPercent(0.5643), '0.57');
      expect(formatPercent(1.3361), '1.34');
    });

    test('trims trailing zeros', () {
      expect(formatPercent(0.56), '0.56');
      expect(formatPercent(50.0), '50');
      expect(formatPercent(55.5), '55.5');
      expect(formatPercent(0), '0');
    });

    test('does not overshoot an exact value', () {
      expect(formatPercent(56), '56');
      expect(formatPercent(99.99), '99.99');
    });

    test('caps below 100 only when asked', () {
      expect(formatPercent(99.995, capBelowHundred: true), '99.99');
      expect(formatPercent(100, capBelowHundred: true), '99.99');
      expect(formatPercent(100), '100');
    });

    test('handles non-finite input as zero', () {
      expect(formatPercent(double.nan), '0');
      expect(formatPercent(double.infinity), '0');
      expect(formatPercent(-5), '0');
    });
  });

  group('computeDailyLimit()', () {
    test('reserves savings and fixed, then spreads the rest', () {
      // 45000 income, 20% savings (9000), 10000 bills, 6000 already spent,
      // 10 days left → (45000 - 9000 - 10000 - 6000) / 10 = 2000/day.
      final d = computeDailyLimit(
        expectedIncome: 45000,
        fixedForecast: 10000,
        variableSpent: 6000,
        remainingDays: 10,
      );
      expect(d.savingsReserved, closeTo(9000, 0.001));
      expect(d.disposableBudget, closeTo(26000, 0.001));
      expect(d.remainingVariable, closeTo(20000, 0.001));
      expect(d.dailyLimit, closeTo(2000, 0.001));
    });

    test('honors a custom savings rate and a zero rate', () {
      final ten = computeDailyLimit(
        expectedIncome: 10000,
        fixedForecast: 0,
        variableSpent: 0,
        remainingDays: 1,
        savingsRate: 0.10,
      );
      expect(ten.savingsReserved, 1000);
      expect(ten.dailyLimit, 9000);

      final none = computeDailyLimit(
        expectedIncome: 10000,
        fixedForecast: 0,
        variableSpent: 0,
        remainingDays: 1,
        savingsRate: 0,
      );
      expect(none.savingsReserved, 0);
      expect(none.dailyLimit, 10000);
    });

    test('overspending clamps the daily limit to zero', () {
      final d = computeDailyLimit(
        expectedIncome: 20000,
        fixedForecast: 5000,
        variableSpent: 50000,
        remainingDays: 15,
      );
      // disposable = 20000 - 4000 - 5000 = 11000; spent 50000 → 0 left.
      expect(d.remainingVariable, 0);
      expect(d.dailyLimit, 0);
    });

    test('a fixed forecast that eats all income yields zero, never negative', () {
      final d = computeDailyLimit(
        expectedIncome: 10000,
        fixedForecast: 99999,
        variableSpent: 0,
        remainingDays: 10,
      );
      expect(d.disposableBudget, 0);
      expect(d.remainingVariable, 0);
      expect(d.dailyLimit, 0);
    });

    test('clamps savingsRate into [0, 1]', () {
      final over = computeDailyLimit(
        expectedIncome: 10000,
        fixedForecast: 0,
        variableSpent: 0,
        remainingDays: 1,
        savingsRate: 5,
      );
      expect(over.savingsReserved, 10000);
      expect(over.dailyLimit, 0);

      final under = computeDailyLimit(
        expectedIncome: 10000,
        fixedForecast: 0,
        variableSpent: 0,
        remainingDays: 1,
        savingsRate: -2,
      );
      expect(under.savingsReserved, 0);
      expect(under.dailyLimit, 10000);
    });

    test('treats non-positive inputs as zero and remainingDays < 1 as 1', () {
      final d = computeDailyLimit(
        expectedIncome: -500,
        fixedForecast: -100,
        variableSpent: -50,
        remainingDays: 0,
      );
      expect(d.expectedIncome, 0);
      expect(d.fixedForecast, 0);
      expect(d.variableSpent, 0);
      expect(d.remainingDays, 1);
      expect(d.dailyLimit, 0);
    });

    test('no income yields no budget', () {
      final d = computeDailyLimit(
        expectedIncome: 0,
        fixedForecast: 0,
        variableSpent: 0,
        remainingDays: 20,
      );
      expect(d.disposableBudget, 0);
      expect(d.dailyLimit, 0);
    });

    test('reported case: income 50013, bills 32867 → 7143 left if no variable spend',
        () {
      // The "₹0 over 17 days" report: with 20% savings and 32867 bills the user
      // should still see 7143 to spread, and the caption must surface the
      // variableSpent term so an opaque 0 is impossible.
      final d = computeDailyLimit(
        expectedIncome: 50013,
        fixedForecast: 32867,
        variableSpent: 0,
        remainingDays: 17,
      );
      expect(d.savingsReserved, closeTo(10002.6, 0.01));
      expect(d.disposableBudget, closeTo(7143.4, 0.01));
      expect(d.remainingVariable, closeTo(7143.4, 0.01));
      expect(d.dailyLimit, closeTo(420.2, 0.01));

      // A single flexible spend larger than the pot legitimately zeroes it —
      // and is now visible in the caption, not hidden.
      final zeroed = computeDailyLimit(
        expectedIncome: 50013,
        fixedForecast: 32867,
        variableSpent: 8000,
        remainingDays: 17,
      );
      expect(zeroed.remainingVariable, 0);
      expect(zeroed.dailyLimit, 0);
      expect(zeroed.variableSpent, 8000);
    });
  });

  group('isFixedExpenseCategory()', () {
    test('matches real-world fixed category names, not just the bare keyword', () {
      for (final name in const [
        'Rent',
        'EMI',
        'Loan EMI',
        'Bills',
        'Credit Card Bill',
        'Electricity Bill',
        'Water Bill',
        'Insurance',
        'Subscription',
        'School Fees',
        'Maintenance',
      ]) {
        expect(isFixedExpenseCategory(name), true, reason: '"$name" should be fixed');
      }
    });

    test('does not misfile discretionary names containing a keyword substring', () {
      for (final name in const [
        'Coffee', // contains "fee"
        'Freelance', // contains "fee"/"rent" fragments
        'Food',
        'Shopping',
        'Travel',
        'Salary',
        'Cashback',
        'Others',
      ]) {
        expect(isFixedExpenseCategory(name), false, reason: '"$name" must be variable');
      }
    });

    test('is case-insensitive and tolerant of null/blank', () {
      expect(isFixedExpenseCategory('  RENT  '), true);
      expect(isFixedExpenseCategory('emi'), true);
      expect(isFixedExpenseCategory(null), false);
      expect(isFixedExpenseCategory(''), false);
      expect(isFixedExpenseCategory('   '), false);
    });
  });

  group('income detection helpers', () {
    test('isInFirstWeek identifies days 1-7', () {
      expect(isInFirstWeek(DateTime(2026, 10, 1)), true);
      expect(isInFirstWeek(DateTime(2026, 10, 7)), true);
      expect(isInFirstWeek(DateTime(2026, 10, 8)), false);
      expect(isInFirstWeek(DateTime(2026, 9, 5)), true);
    });

    test('lastWorkingDayOfMonth skips weekends', () {
      // Example months
      final oct = lastWorkingDayOfMonth(2026, 10); // Oct 2026 ends Sat? Oct 31 2026 is Sat
      expect(oct.weekday != DateTime.saturday && oct.weekday != DateTime.sunday, true);
    });

    test('isLastWorkingDay matches lastWorkingDayOfMonth', () {
      final d = lastWorkingDayOfMonth(2026, 9);
      expect(isLastWorkingDay(d), true);
      expect(isLastWorkingDay(DateTime(d.year, d.month, d.day - 1)), false);
    });
  });

  // computeExpectedIncome reads DateTime.now() internally, so every fixture is
  // built relative to `now` — the branches under test are the mode precedence
  // and the "manual with no value falls back to blend" rule. These were
  // previously unasserted, so a wrong branch shipped silently.
  group('computeExpectedIncome() mode precedence', () {
    // Income is recipientId == uid with a positive amount (see AGENTS.md).
    TransactionModel income(double amount, DateTime date, {String uid = 'me'}) =>
        _tx(amount: amount, date: date, recipientId: uid, senderId: '');

    test('manual wins when a positive value is set', () {
      final r = computeExpectedIncome(
        allTx: [income(5000, DateTime.now())],
        uid: 'me',
        mode: IncomeMode.manual,
        manualMonthly: 42000,
      );
      expect(r.expectedIncome, 42000);
      expect(r.effectiveMode, IncomeMode.manual);
      expect(r.usedManual, true);
      expect(r.fellBackToBlend, false);
    });

    test('manual with NO value falls back to blend, not to zero', () {
      final now = DateTime.now();
      final r = computeExpectedIncome(
        allTx: [income(3000, now)],
        uid: 'me',
        mode: IncomeMode.manual,
        manualMonthly: 0,
      );
      // The trap: manual-with-no-value must NOT report 0 income.
      expect(r.fellBackToBlend, true);
      expect(r.usedManual, false);
      expect(r.effectiveMode, IncomeMode.autoBlend);
      expect(r.expectedIncome, greaterThan(0));
    });

    test('non-finite manual value is not treated as set', () {
      final r = computeExpectedIncome(
        allTx: [income(3000, DateTime.now())],
        uid: 'me',
        mode: IncomeMode.manual,
        manualMonthly: double.infinity,
      );
      expect(r.usedManual, false);
      expect(r.fellBackToBlend, true);
    });

    test('blend takes the max of this-month income and the 3-month average', () {
      final now = DateTime.now();
      // All four are inside the 90-day window, so the "3-month average"
      // includes THIS month: last3m = 6000, avg = 2000, thisMonth = 6000.
      final r = computeExpectedIncome(
        allTx: [
          income(1000, now),
          income(1000, now),
          income(1000, now),
          income(3000, now),
        ],
        uid: 'me',
        mode: IncomeMode.autoBlend,
        manualMonthly: 0,
      );
      expect(r.expectedIncome, closeTo(6000, 0.01));
    });

    test('blend floors at the 3-month average when this month is quiet', () {
      final now = DateTime.now();
      // A prior-month income inside the 90-day window: this month = 0,
      // so the 3-month average (9000/3 = 3000) is the floor that wins.
      final lastMonth = DateTime(
        now.month == 1 ? now.year - 1 : now.year,
        now.month == 1 ? 12 : now.month - 1,
        15,
      );
      final r = computeExpectedIncome(
        allTx: [income(9000, lastMonth)],
        uid: 'me',
        mode: IncomeMode.autoBlend,
        manualMonthly: 0,
      );
      expect(r.expectedIncome, closeTo(3000, 0.01));
    });

    test('blend ignores income older than the 90-day cutoff', () {
      final now = DateTime.now();
      // 200 days old: outside the window, and not this month → contributes 0.
      final stale = now.subtract(const Duration(days: 200));
      final r = computeExpectedIncome(
        allTx: [income(99000, stale)],
        uid: 'me',
        mode: IncomeMode.autoBlend,
        manualMonthly: 0,
      );
      expect(r.expectedIncome, 0);
    });

    test('blend ignores transactions whose recipient is not this user', () {
      final now = DateTime.now();
      final r = computeExpectedIncome(
        allTx: [
          income(9000, now),
          _tx(amount: 9000, date: now, recipientId: 'someone-else', senderId: ''),
        ],
        uid: 'me',
        mode: IncomeMode.autoBlend,
        manualMonthly: 0,
      );
      expect(r.expectedIncome, closeTo(9000, 0.01));
    });

    test('empty salary window reports 0 AND flags the window as empty', () {
      final r = computeExpectedIncome(
        allTx: const [],
        uid: 'me',
        mode: IncomeMode.autoSalaryWindow,
        manualMonthly: 0,
      );
      expect(r.expectedIncome, 0);
      // The UI renders this as a note ("no salary recorded"), not an error —
      // the flag is what tells it apart from a real zero.
      expect(r.salaryWindowEmpty, true);
      expect(r.effectiveMode, IncomeMode.autoSalaryWindow);
    });

    test('salary window sums income inside the first week of this month', () {
      final now = DateTime.now();
      final day3 = DateTime(now.year, now.month, 3);
      final r = computeExpectedIncome(
        allTx: [income(71000, day3)],
        uid: 'me',
        mode: IncomeMode.autoSalaryWindow,
        manualMonthly: 0,
      );
      expect(r.expectedIncome, closeTo(71000, 0.01));
      expect(r.salaryWindowEmpty, false);
    });

    test('a manual value does not leak into salary-window mode', () {
      // manualMonthly is only consulted in IncomeMode.manual.
      final r = computeExpectedIncome(
        allTx: const [],
        uid: 'me',
        mode: IncomeMode.autoSalaryWindow,
        manualMonthly: 99999,
      );
      expect(r.expectedIncome, 0);
      expect(r.usedManual, false);
      expect(r.salaryWindowEmpty, true);
    });
  });
}
