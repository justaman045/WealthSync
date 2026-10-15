import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Utils/spending_filter.dart';

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
  final month = DateTime(2026, 10, 15);

  group('splitMonthlyExpenses()', () {
    test('separates discretionary from fixed and sums each bucket', () {
      final all = [
        _tx(amount: -2000, date: DateTime(2026, 10, 3), category: 'Rent'),
        _tx(amount: -300, date: DateTime(2026, 10, 5), category: 'Food'),
        _tx(amount: -1500, date: DateTime(2026, 10, 8), category: 'Loan EMI'),
        _tx(amount: -800, date: DateTime(2026, 10, 9), category: 'Shopping'),
      ];

      final split = splitMonthlyExpenses(all, uid: 'me', month: month);

      expect(
        split.discretionary.map((t) => t.category),
        ['Shopping', 'Food'], // newest first
      );
      expect(
        split.fixed.map((t) => t.category),
        ['Loan EMI', 'Rent'],
      );
      expect(split.discretionaryTotal, 1100);
      expect(split.fixedTotal, 3500);
      expect(split.discretionaryCount, 2);
      expect(split.fixedCount, 2);
    });

    test('the two buckets partition every expense of the month', () {
      final all = [
        _tx(amount: -100, date: DateTime(2026, 10, 1), category: 'Food'),
        _tx(amount: -100, date: DateTime(2026, 10, 2), category: 'Rent'),
        _tx(amount: -100, date: DateTime(2026, 10, 3), category: 'Coffee'),
      ];
      final split = splitMonthlyExpenses(all, uid: 'me', month: month);
      expect(
        split.discretionary.length + split.fixed.length,
        all.length,
      );
    });

    test('excludes income and other users', () {
      final all = [
        // Income: positive, senderId empty, recipientId == uid.
        _tx(
          amount: 50000,
          date: DateTime(2026, 10, 2),
          category: 'Salary',
          senderId: '',
          recipientId: 'me',
        ),
        // Someone else's expense.
        _tx(
          amount: -100,
          date: DateTime(2026, 10, 2),
          category: 'Food',
          senderId: 'other',
        ),
        _tx(amount: -100, date: DateTime(2026, 10, 2), category: 'Food'),
      ];
      final split = splitMonthlyExpenses(all, uid: 'me', month: month);
      expect(split.discretionaryCount, 1);
      expect(split.fixedCount, 0);
      expect(split.discretionaryTotal, 100);
    });

    test('excludes other months', () {
      final all = [
        _tx(amount: -100, date: DateTime(2026, 9, 30), category: 'Food'),
        _tx(amount: -250, date: DateTime(2026, 10, 31), category: 'Food'),
        _tx(amount: -999, date: DateTime(2026, 11, 1), category: 'Food'),
      ];
      final split = splitMonthlyExpenses(all, uid: 'me', month: month);
      expect(split.discretionaryCount, 1);
      expect(split.discretionaryTotal, 250);
    });

    test('null category falls into the discretionary bucket', () {
      final all = [
        _tx(amount: -75, date: DateTime(2026, 10, 4), category: null),
      ];
      final split = splitMonthlyExpenses(all, uid: 'me', month: month);
      expect(split.discretionaryCount, 1);
      expect(split.fixedCount, 0);
    });

    test('empty input yields empty buckets', () {
      final split = splitMonthlyExpenses(
        const [],
        uid: 'me',
        month: month,
      );
      expect(split.discretionary, isEmpty);
      expect(split.fixed, isEmpty);
      expect(split.discretionaryTotal, 0);
      expect(split.fixedTotal, 0);
    });
  });
}
