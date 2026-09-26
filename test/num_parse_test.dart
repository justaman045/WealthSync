import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Utils/num_parse.dart';

void main() {
  group('safeToDouble()', () {
    test('passes finite numbers through', () {
      expect(safeToDouble(42), 42.0);
      expect(safeToDouble(-7.5), -7.5);
      expect(safeToDouble(0), 0.0);
    });

    test('parses finite numeric strings', () {
      expect(safeToDouble('1234.56'), 1234.56);
      expect(safeToDouble('-99'), -99.0);
    });

    test('rejects non-finite doubles', () {
      expect(safeToDouble(double.nan), 0.0);
      expect(safeToDouble(double.infinity), 0.0);
      expect(safeToDouble(double.negativeInfinity), 0.0);
    });

    test('rejects the strings double.tryParse would otherwise accept', () {
      expect(safeToDouble('NaN'), 0.0);
      expect(safeToDouble('Infinity'), 0.0);
      expect(safeToDouble('-Infinity'), 0.0);
    });

    test('falls back to zero for unusable input', () {
      expect(safeToDouble(null), 0.0);
      expect(safeToDouble('abc'), 0.0);
      expect(safeToDouble(''), 0.0);
      expect(safeToDouble(true), 0.0);
      expect(safeToDouble(<String>[]), 0.0);
    });
  });

  group('isValidAmount()', () {
    test('accepts strictly positive finite values', () {
      expect(isValidAmount(1), isTrue);
      expect(isValidAmount(0.01), isTrue);
    });

    test('rejects zero and negatives', () {
      expect(isValidAmount(0), isFalse);
      expect(isValidAmount(-1), isFalse);
    });

    test('rejects NaN and infinity', () {
      expect(isValidAmount(double.nan), isFalse);
      expect(isValidAmount(double.infinity), isFalse);
      expect(isValidAmount(double.negativeInfinity), isFalse);
    });

    test('rejects null', () {
      expect(isValidAmount(null), isFalse);
    });
  });

  group('TransactionModel.fromMap amount coercion', () {
    test('a stored NaN amount reads as 0 instead of poisoning totals', () {
      final tx = TransactionModel.fromMap('t1', {
                'amount': 'NaN',
        'senderId': 'me',
      });
      expect(tx.amount, 0.0);
    });

    test('a stored Infinity amount reads as 0', () {
      final tx = TransactionModel.fromMap('t1', {
                'amount': 'Infinity',
        'senderId': 'me',
      });
      expect(tx.amount, 0.0);
    });

    test('a normal string amount still parses', () {
      final tx = TransactionModel.fromMap('t1', {
                'amount': '250.75',
        'senderId': 'me',
      });
      expect(tx.amount, 250.75);
    });

    test('a numeric amount is preserved with its sign convention', () {
      final expense = TransactionModel.fromMap('t1', {
                'amount': -500,
        'senderId': 'me',
      });
      final income = TransactionModel.fromMap('t1', {
                'amount': 500,
        'recipientId': 'me',
      });
      expect(expense.amount, -500.0);
      expect(income.amount, 500.0);
    });

    test('a NaN tax field does not leak either', () {
      final tx = TransactionModel.fromMap('t1', {
                'amount': 100,
        'tax': 'NaN',
        'senderId': 'me',
      });
      expect(tx.tax, 0.0);
      expect(tx.amount, 100.0);
    });
  });
}
