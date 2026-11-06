import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Utils/wealth_math.dart';

TransactionModel _expenseTx({
  required double amount,
  required DateTime date,
  String category = 'Groceries',
  String uid = 'me',
}) {
  return TransactionModel(
    id: '$category-${amount}-${date.millisecondsSinceEpoch}',
    senderId: uid,
    recipientId: '',
    recipientName: category,
    amount: -amount.abs(),
    currency: 'INR',
    tax: 0,
    category: category,
    date: date,
    createdAt: date,
  );
}

TransactionModel _incomeTx({
  required double amount,
  required DateTime date,
  String category = 'Salary',
  String uid = 'me',
}) {
  return TransactionModel(
    id: '$category-${amount}-${date.millisecondsSinceEpoch}',
    senderId: '',
    recipientId: uid,
    recipientName: category,
    amount: amount.abs(),
    currency: 'INR',
    tax: 0,
    category: category,
    date: date,
    createdAt: date,
  );
}

void main() {
  group('resolveDailyLimitRole — category casing consistency (issue 7)', () {
    test('same category with different case resolves to the same role', () {
      final overrides = <String, String>{};
      expect(
        resolveDailyLimitRole('Groceries', treatmentOverrides: overrides),
        resolveDailyLimitRole('groceries', treatmentOverrides: overrides),
      );
      expect(
        resolveDailyLimitRole('GROCERIES', treatmentOverrides: overrides),
        resolveDailyLimitRole('groceries', treatmentOverrides: overrides),
      );
    });

    test('fixed keyword matches regardless of case', () {
      expect(resolveDailyLimitRole('RENT'), DailyLimitRole.fixed);
      expect(resolveDailyLimitRole('rent'), DailyLimitRole.fixed);
      expect(resolveDailyLimitRole('Rent'), DailyLimitRole.fixed);
      expect(resolveDailyLimitRole('  RENT  '), DailyLimitRole.fixed);
    });

    test('override wins over keyword classifier', () {
      final overrides = {'rent': 'ignored'};
      expect(resolveDailyLimitRole('RENT', treatmentOverrides: overrides),
          DailyLimitRole.ignored);
    });

    test('null and empty categories are never ignored', () {
      expect(resolveDailyLimitRole(null), DailyLimitRole.variable);
      expect(resolveDailyLimitRole(''), DailyLimitRole.variable);
      expect(resolveDailyLimitRole('   '), DailyLimitRole.variable);
    });
  });

  group('computeDailyLimit — clamps never negative (issue 6)', () {
    test('overspending clamps to zero daily limit', () {
      final d = computeDailyLimit(
        expectedIncome: 50000,
        fixedForecast: 10000,
        variableSpent: 60000,
        remainingDays: 20,
      );
      expect(d.dailyLimit, 0);
      expect(d.remainingVariable, 0);
    });

    test('no income yields zero budget', () {
      final d = computeDailyLimit(
        expectedIncome: 0,
        fixedForecast: 0,
        variableSpent: 0,
        remainingDays: 20,
      );
      expect(d.dailyLimit, 0);
      expect(d.disposableBudget, 0);
    });

    test('remainingDays < 1 treated as 1', () {
      final d = computeDailyLimit(
        expectedIncome: 30000,
        fixedForecast: 0,
        variableSpent: 0,
        remainingDays: 0,
      );
      expect(d.remainingDays, 1);
      expect(d.dailyLimit, closeTo(24000, 0.01)); // 30000 * 0.8 / 1
    });
  });

  group('computeDailyAllowance — splits budget for today (issue 6)', () {
    test('spentBeforeToday excludes today, todaySpent compared separately', () {
      final a = computeDailyAllowance(
        expectedIncome: 60000,
        fixedForecast: 10000,
        spentBeforeToday: 10000,
        todaySpent: 2000,
        remainingDays: 20,
      );
      // disposable = 60000 - 12000(savings) - 10000(fixed) = 38000
      // remainingBeforeToday = 38000 - 10000 = 28000
      // todayAllowance = 28000 / 20 = 1400
      // remainingToday = max(0, 1400 - 2000) = 0
      expect(a.todayAllowance, closeTo(1400, 0.01));
      expect(a.remainingToday, 0);
      expect(a.isExhausted, true);
    });

    test('today not yet spent', () {
      final a = computeDailyAllowance(
        expectedIncome: 60000,
        fixedForecast: 10000,
        spentBeforeToday: 10000,
        todaySpent: 0,
        remainingDays: 20,
      );
      expect(a.todayAllowance, closeTo(1400, 0.01));
      expect(a.remainingToday, closeTo(1400, 0.01));
      expect(a.isExhausted, false);
    });
  });

  group('Future-date exclusion — current-month spend ignores future rows', () {
    final now = DateTime(2026, 11, 15);
    final todayKey = DateTime(2026, 11, 15);

    test('past transaction counts toward current month spend', () {
      final tx = _expenseTx(amount: 1000, date: DateTime(2026, 11, 10));
      final currentKey = 202611;
      final monthKey = tx.date.year * 100 + tx.date.month;
      final isFuture = !tx.date.isBefore(now) &&
          !tx.date.isAtSameMomentAs(now);
      expect(monthKey, currentKey);
      expect(isFuture, false);
    });

    test('future transaction is excluded from current month spend', () {
      final tx = _expenseTx(amount: 5000, date: DateTime(2026, 11, 25));
      final currentKey = 202611;
      final monthKey = tx.date.year * 100 + tx.date.month;
      final isFuture = !tx.date.isBefore(now) &&
          !tx.date.isAtSameMomentAs(now);
      expect(monthKey, currentKey);
      expect(isFuture, true); // future-dated -> scheduled, not spent
    });

    test('same-day transaction counts as today, not future', () {
      final tx = _expenseTx(amount: 500, date: todayKey);
      final isFuture = !tx.date.isBefore(now) && !tx.date.isAtSameMomentAs(now);
      expect(isFuture, false);
    });
  });

  group('Income detection excludes refunds and transfers (issue 8)', () {
    final now = DateTime(2026, 11, 15);

    test('refund category is not income', () {
      expect(isNonIncomeCategory('Refund'), true);
      expect(isNonIncomeCategory('REFUND'), true);
      expect(isNonIncomeCategory('Refund from Amazon'), true);
    });

    test('transfer category is not income', () {
      expect(isNonIncomeCategory('Transfer'), true);
      expect(isNonIncomeCategory('Self Transfer'), true);
    });

    test('cashback is not income', () {
      expect(isNonIncomeCategory('Cashback'), true);
    });

    test('salary is income', () {
      expect(isNonIncomeCategory('Salary'), false);
      expect(isNonIncomeCategory('Income'), false);
    });

    test('keyword substring does not misfire', () {
      expect(isNonIncomeCategory('Coffee'), false); // contains 'fee'? no
      expect(isNonIncomeCategory('Freelance Income'), false);
    });
  });
}
