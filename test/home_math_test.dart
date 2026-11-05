import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Utils/home_math.dart';

/// Expense convention: `amount < 0`, `senderId == uid`.
/// Income convention: `amount > 0`, `recipientId == uid`.
TransactionModel _tx({
  required double amount,
  required DateTime date,
  String senderId = 'me',
  String recipientId = '',
  double tax = 0,
  DateTime? createdAt,
}) {
  return TransactionModel(
    id: 'tx-${date.millisecondsSinceEpoch}-$amount-$senderId-$recipientId',
    senderId: senderId,
    recipientId: recipientId,
    recipientName: 'x',
    amount: amount,
    currency: 'INR',
    tax: tax,
    date: date,
    createdAt: createdAt ?? date,
  );
}

void main() {
  group('summarizeHomeMonth — window', () {
    final now = DateTime(2026, 3, 15, 12);

    test('counts this month-to-date only', () {
      final summary = summarizeHomeMonth(
        [
          _tx(amount: -100, date: DateTime(2026, 3, 1)),
          _tx(amount: -50, date: DateTime(2026, 3, 15)),
          _tx(amount: 500, date: DateTime(2026, 3, 2), senderId: '', recipientId: 'me'),
        ],
        uid: 'me',
        now: now,
      );

      expect(summary.spend, 150);
      expect(summary.income, 500);
      expect(summary.net, 350);
      expect(summary.hasActivity, isTrue);
    });

    test('ignores future-dated transactions in the same month', () {
      final summary = summarizeHomeMonth(
        [
          _tx(amount: -100, date: DateTime(2026, 3, 10)),
          // Scheduled for later this month — has not happened yet.
          _tx(amount: -900, date: DateTime(2026, 3, 28)),
          _tx(amount: 900, date: DateTime(2026, 3, 28), senderId: '', recipientId: 'me'),
        ],
        uid: 'me',
        now: now,
      );

      expect(summary.spend, 100);
      expect(summary.income, 0);
    });

    test('ignores last month and older for the headline totals', () {
      final summary = summarizeHomeMonth(
        [
          _tx(amount: -100, date: DateTime(2026, 3, 10)),
          _tx(amount: -700, date: DateTime(2026, 2, 10)),
          _tx(amount: -900, date: DateTime(2026, 1, 10)),
        ],
        uid: 'me',
        now: now,
      );

      expect(summary.spend, 100);
    });
  });

  group('summarizeHomeMonth — month-over-month', () {
    test('compares against the same day range last month', () {
      final summary = summarizeHomeMonth(
        [
          // This month-to-date (the 15th): 150.
          _tx(amount: -100, date: DateTime(2026, 3, 2)),
          _tx(amount: -50, date: DateTime(2026, 3, 14)),
          // Last month days 1-15: 100.
          _tx(amount: -100, date: DateTime(2026, 2, 3)),
          // Last month days 16-28: must NOT count — comparing against the full
          // previous month is what made every mid-month delta look negative.
          _tx(amount: -800, date: DateTime(2026, 2, 20)),
        ],
        uid: 'me',
        now: DateTime(2026, 3, 15, 12),
      );

      expect(summary.spend, 150);
      // (150 - 100) / 100 * 100.
      expect(summary.momPercent, closeTo(50, 0.0001));
    });

    test('reports a drop as a negative percentage', () {
      final summary = summarizeHomeMonth(
        [
          _tx(amount: -50, date: DateTime(2026, 3, 3)),
          _tx(amount: -200, date: DateTime(2026, 2, 3)),
        ],
        uid: 'me',
        now: DateTime(2026, 3, 15),
      );

      expect(summary.momPercent, closeTo(-75, 0.0001));
    });

    test('is null when last month had no comparable spend', () {
      final summary = summarizeHomeMonth(
        [_tx(amount: -50, date: DateTime(2026, 3, 3))],
        uid: 'me',
        now: DateTime(2026, 3, 15),
      );

      expect(summary.momPercent, isNull);
    });

    test('is null on the 1st — the comparable window is empty', () {
      final summary = summarizeHomeMonth(
        [
          _tx(amount: -50, date: DateTime(2026, 3, 1)),
          _tx(amount: -200, date: DateTime(2026, 2, 1)),
        ],
        uid: 'me',
        now: DateTime(2026, 3, 1, 18),
      );

      expect(summary.momPercent, isNull);
    });

    test('clamps the day when comparing against a shorter month', () {
      // 31 March: the comparable window is 1-28 February, not "Feb 31" which
      // DateTime would normalise forward into March.
      final summary = summarizeHomeMonth(
        [
          _tx(amount: -100, date: DateTime(2026, 3, 31)),
          _tx(amount: -100, date: DateTime(2026, 2, 28)),
        ],
        uid: 'me',
        now: DateTime(2026, 3, 31, 23),
      );

      expect(summary.spend, 100);
      expect(summary.momPercent, closeTo(0, 0.0001));
    });
  });

  group('summarizeHomeMonth — money semantics', () {
    test('spending includes tax, matching the bank balance', () {
      final summary = summarizeHomeMonth(
        [_tx(amount: -100, tax: 5, date: DateTime(2026, 3, 5))],
        uid: 'me',
        now: DateTime(2026, 3, 15),
      );

      expect(summary.spend, 105);
    });

    test('income is net of tax, matching the bank balance', () {
      final summary = summarizeHomeMonth(
        [
          _tx(
            amount: 200,
            tax: 5,
            date: DateTime(2026, 3, 5),
            senderId: '',
            recipientId: 'me',
          ),
        ],
        uid: 'me',
        now: DateTime(2026, 3, 15),
      );

      expect(summary.income, 195);
    });

    test('a self-transfer is neither income nor spending', () {
      final summary = summarizeHomeMonth(
        [
          _tx(
            amount: -500,
            date: DateTime(2026, 3, 5),
            senderId: 'me',
            recipientId: 'me',
          ),
        ],
        uid: 'me',
        now: DateTime(2026, 3, 15),
      );

      expect(summary.spend, 0);
      expect(summary.income, 0);
      expect(summary.hasActivity, isFalse);
    });

    test('ignores transactions that do not belong to the user', () {
      final summary = summarizeHomeMonth(
        [
          _tx(
            amount: -100,
            date: DateTime(2026, 3, 5),
            senderId: 'someone-else',
            recipientId: 'another',
          ),
        ],
        uid: 'me',
        now: DateTime(2026, 3, 15),
      );

      expect(summary.hasActivity, isFalse);
    });
  });

  group('selectRecentTransactions', () {
    test('orders by transaction date, not createdAt', () {
      final olderButRecordedLater = _tx(
        amount: -10,
        date: DateTime(2026, 3, 1),
        createdAt: DateTime(2026, 3, 20),
      );
      final newerButRecordedEarlier = _tx(
        amount: -20,
        date: DateTime(2026, 3, 10),
        createdAt: DateTime(2026, 3, 2),
      );

      final ordered = selectRecentTransactions(
        [olderButRecordedLater, newerButRecordedEarlier],
        uid: 'me',
      );

      expect(ordered.first.id, newerButRecordedEarlier.id);
      expect(ordered.last.id, olderButRecordedLater.id);
    });

    test('breaks same-day ties with createdAt descending', () {
      final recordedFirst = _tx(
        amount: -10,
        date: DateTime(2026, 3, 10),
        createdAt: DateTime(2026, 3, 10, 8),
      );
      final recordedSecond = _tx(
        amount: -20,
        date: DateTime(2026, 3, 10),
        createdAt: DateTime(2026, 3, 10, 9),
      );

      final ordered = selectRecentTransactions(
        [recordedFirst, recordedSecond],
        uid: 'me',
      );

      expect(ordered.first.id, recordedSecond.id);
    });

    test('caps the list and drops foreign rows', () {
      final txs = [
        for (var i = 0; i < 12; i++)
          _tx(amount: -1, date: DateTime(2026, 3, i + 1)),
        _tx(
          amount: -99,
          date: DateTime(2026, 3, 30),
          senderId: 'someone-else',
        ),
      ];

      final recent = selectRecentTransactions(txs, uid: 'me');

      expect(recent, hasLength(8));
      expect(recent.first.date, DateTime(2026, 3, 12));
      expect(recent.every((t) => t.senderId == 'me'), isTrue);
    });

    test('includes income as well as spending', () {
      final income = _tx(
        amount: 300,
        date: DateTime(2026, 3, 11),
        senderId: '',
        recipientId: 'me',
      );

      final recent = selectRecentTransactions([income], uid: 'me');

      expect(recent.single.id, income.id);
    });
  });
}
