import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Services/wealth_service.dart';

/// Wealth math that used to be wrong in ways the UI could not show: income
/// counted gross of TDS, a rolling 90-day window that dropped the salary
/// halfway through the month, and a divisor of 3 that made a one-month-old
/// account look poor. `uid` is injected so none of this needs Firebase.
TransactionModel _tx({
  required double amount,
  String senderId = 'other',
  String recipientId = '',
  double tax = 0,
  String? category,
  DateTime? date,
}) {
  final day = date ?? DateTime(2026, 11, 10);
  return TransactionModel(
    id: '${category ?? 'tx'}-$amount-${day.millisecondsSinceEpoch}-$senderId',
    senderId: senderId,
    recipientId: recipientId,
    recipientName: category ?? 'x',
    amount: amount,
    currency: 'INR',
    tax: tax,
    category: category,
    date: day,
    createdAt: day,
  );
}

TransactionModel _expense(double amount, {double tax = 0, DateTime? date}) =>
    // Expense convention: negative amount, sender is the user.
    _tx(amount: -amount.abs(), senderId: 'me', tax: tax, date: date);

TransactionModel _income(
  double amount, {
  double tax = 0,
  String? category,
  DateTime? date,
}) =>
    _tx(
      amount: amount,
      senderId: '',
      recipientId: 'me',
      tax: tax,
      category: category,
      date: date,
    );

void main() {
  group('calculateBankBalance()', () {
    test('income lands net of TDS, not gross', () {
      final balance = WealthService.calculateBankBalance(
        [_income(100000, tax: 10000)],
        uid: 'me',
      );
      // The old code added `amount.abs()`: 100000, as if no tax was withheld.
      expect(balance, 90000);
    });

    test('an expense is stored negative, so its net total is subtracted', () {
      final balance = WealthService.calculateBankBalance(
        [_income(100000), _expense(20000, tax: 200)],
        uid: 'me',
      );
      expect(balance, 100000 - 20200);
    });

    test('a row between the user\'s own accounts counts once', () {
      // Both ids match the user; `||` must not add it twice (once as income,
      // once as an expense) the way two independent branches would.
      final selfTransfer = _tx(
        amount: -5000,
        senderId: 'me',
        recipientId: 'me',
        category: 'Transfer',
      );
      expect(
        WealthService.calculateBankBalance([selfTransfer], uid: 'me'),
        -5000,
      );
    });

    test('other people\'s transactions are ignored', () {
      final balance = WealthService.calculateBankBalance(
        [
          _treasury(),
          _tx(amount: -900, senderId: 'someone-else'),
          _tx(amount: 500, recipientId: 'someone-else'),
        ],
        uid: 'me',
      );
      expect(balance, 0);
    });

    test('an unknown viewer sees nothing', () {
      expect(
        WealthService.calculateBankBalance([_income(5000)], uid: 'nobody'),
        0,
      );
    });
  });

  group('calculateAverageMonthlyIncome()', () {
    test('divides by months that have income, not by the window size', () {
      // One month of data, three-month window: 30k is the average, not 10k.
      final avg = WealthService.calculateAverageMonthlyIncome(
        [_income(30000, date: DateTime(2026, 11, 2))],
        uid: 'me',
        now: DateTime(2026, 11, 20),
      );
      expect(avg, 30000);
    });

    test('empty months do not drag the average down', () {
      final avg = WealthService.calculateAverageMonthlyIncome(
        [
          _income(20000, date: DateTime(2026, 10, 5)),
          _income(30000, date: DateTime(2026, 9, 5)),
          // August is empty.
        ],
        uid: 'me',
        now: DateTime(2026, 11, 20),
      );
      expect(avg, 25000);
    });

    test('refunds and transfers are not income', () {
      final avg = WealthService.calculateAverageMonthlyIncome(
        [
          _income(50000, date: DateTime(2026, 11, 2)),
          _income(9000, category: 'Refund', date: DateTime(2026, 11, 3)),
          _income(7000, category: 'Transfer', date: DateTime(2026, 11, 4)),
          _income(3000, category: 'Loan/EMI', date: DateTime(2026, 11, 5)),
        ],
        uid: 'me',
        now: DateTime(2026, 11, 20),
      );
      expect(avg, 50000);
    });

    test('income uses calendar months, so a 1st-of-month salary is kept', () {
      // A 90-day cutoff from 2026-11-20 drops 2026-08-01; calendar bucketing
      // keeps the whole of August and September.
      final avg = WealthService.calculateAverageMonthlyIncome(
        [
          _income(60000, date: DateTime(2026, 8, 1)),
          _income(60000, date: DateTime(2026, 9, 1)),
        ],
        uid: 'me',
        now: DateTime(2026, 11, 20),
        months: 3,
      );
      expect(avg, 60000);
    });

    test('income older than the window is ignored', () {
      final avg = WealthService.calculateAverageMonthlyIncome(
        [_income(90000, date: DateTime(2025, 11, 10))],
        uid: 'me',
        now: DateTime(2026, 11, 20),
      );
      expect(avg, 0);
    });

    test('a zero-month window is not divided by zero', () {
      expect(
        WealthService.calculateAverageMonthlyIncome(
          [_income(1000)],
          uid: 'me',
          months: 0,
        ),
        0,
      );
    });
  });

  group('source guards', () {
    test('a brand-new portfolio has no gold cap', () {
      final src = File('lib/Services/wealth_service.dart').readAsStringSync();
      // `0.10 * 0.0` zeroed the gold target, so a starter card read as done.
      expect(src, contains('double.infinity'));
      expect(src, contains('visibleNetWorth > 0'));
    });

    test('manual targets apply only in Custom Mode', () {
      final service = File('lib/Services/wealth_service.dart').readAsStringSync();
      expect(service, contains('bool useOverrides = true'));
      expect(service, contains('if (useOverrides) {'));

      final builder = File('lib/Screens/wealth_builder.dart').readAsStringSync();
      // Smart Mode (`_ageBasedEnabled`) must not let a Custom-Mode override win.
      expect(builder, contains('useOverrides: !_ageBasedEnabled'));
      expect(builder, contains('useOverrides: !ageBasedEnabled'));
    });

    test('the currency symbol is resolved before the insight try block', () {
      final src = File('lib/Services/wealth_service.dart').readAsStringSync();
      final symbol = src.indexOf('final symbol = _currencySymbol();');
      final tryAfter = src.indexOf('try {', symbol);
      expect(symbol, greaterThan(0));
      expect(tryAfter, greaterThan(symbol));
      // A missing controller must not be reported as "failed to generate".
      expect(
        src.substring(tryAfter, tryAfter + 600),
        isNot(contains('Get.find<CurrencyController>()')),
      );
    });

    test('forecast and insights share one paid-bill fraction', () {
      final analysis = File('lib/Screens/analysis.dart').readAsStringSync();
      final bills = File('lib/Utils/bills_math.dart').readAsStringSync();
      // The paid threshold moved into the pure bill maths, which the forecast,
      // the insight cards and the bills sheet all read.
      expect('$analysis\n$bills', contains('kBillPaidFraction'));
      // No second hardcoded threshold: they had drifted to 0.95 vs 0.90.
      expect(analysis, isNot(contains('typicalAmount * 0.95')));
      expect(analysis, isNot(contains('catHistAvg * 0.9')));
      expect(bills, isNot(contains('0.95')));
      expect(bills, isNot(contains('0.9')));
    });

    test('analysis learns only from the recent year of history', () {
      final analysis = File('lib/Screens/analysis.dart').readAsStringSync();
      expect(analysis, contains('monthKeyFloor'));
      expect(analysis, contains('historyFloor'));
    });
  });
}

/// A row that belongs to neither the user as sender nor as recipient, used to
/// keep "ignored rows" fixtures easy to read.
TransactionModel _treasury() => _tx(amount: 999999, senderId: 'bank');
