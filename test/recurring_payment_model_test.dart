import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Models/recurring_payment_model.dart';

void main() {
  Map<String, dynamic> baseMap() => {
    'userId': 'u1',
    'title': 'Netflix',
    'amount': 499.0,
    'category': 'Entertainment',
    'frequency': 'monthly',
    'startDate': Timestamp.fromDate(DateTime(2026, 8, 1)),
    'nextDueDate': Timestamp.fromDate(DateTime(2026, 9, 1)),
    'isActive': true,
    'autoPay': true,
  };

  group('RecurringPayment autoPay defaults', () {
    test('constructor defaults autoPay to false (opt-in)', () {
      final p = RecurringPayment(
        id: '1',
        userId: 'u1',
        title: 'Netflix',
        amount: 499,
        category: 'Entertainment',
        frequency: RecurringFrequency.monthly,
        startDate: DateTime(2026, 8, 1),
        nextDueDate: DateTime(2026, 9, 1),
        isActive: true,
      );
      expect(p.autoPay, false);
    });

    test('legacy doc without autoPay field defaults to false (no auto-deduct)', () {
      final map = baseMap()..remove('autoPay');
      final p = RecurringPayment.fromMap('1', map);
      expect(p.autoPay, false);
      expect(p.isActive, true);
    });

    test('explicit autoPay: false is preserved', () {
      final p = RecurringPayment.fromMap('1', baseMap()..['autoPay'] = false);
      expect(p.autoPay, false);
    });

    test('explicit autoPay: true is preserved', () {
      final p = RecurringPayment.fromMap('1', baseMap());
      expect(p.autoPay, true);
    });

    test('toMap writes autoPay field', () {
      final p = RecurringPayment.fromMap('1', baseMap()..['autoPay'] = false);
      expect(p.toMap()['autoPay'], false);
    });
  });

  group('RecurringPayment kind / outstanding', () {
    test('legacy doc without kind reads back as a plain bill', () {
      final p = RecurringPayment.fromMap('1', baseMap());
      expect(p.kind, RecurringKind.bill);
      expect(p.kind.isLiability, isFalse);
      expect(p.outstanding, isNull);
    });

    test('an unknown kind never becomes a liability', () {
      final p = RecurringPayment.fromMap(
        '1',
        baseMap()..['kind'] = 'somethingElse',
      );
      expect(p.kind, RecurringKind.bill);
    });

    test('credit card and loan EMI round-trip with their outstanding', () {
      for (final kind in [RecurringKind.creditCard, RecurringKind.loanEmi]) {
        final p = RecurringPayment.fromMap(
          '1',
          baseMap()
            ..['kind'] = kind.name
            ..['outstanding'] = 42000,
        );
        expect(p.kind, kind);
        expect(p.kind.isLiability, isTrue);
        expect(p.outstanding, 42000);

        final map = p.toMap();
        expect(map['kind'], kind.name);
        expect(map['outstanding'], 42000);
        expect(RecurringPayment.fromMap('1', map).kind, kind);
      }
    });

    test('outstanding is normalised to paisa and ignores non-numeric values', () {
      final p = RecurringPayment.fromMap(
        '1',
        baseMap()..['outstanding'] = 10242.621637042335,
      );
      expect(p.outstanding, 10242.62);
      final bad = RecurringPayment.fromMap(
        '1',
        baseMap()..['outstanding'] = 'n/a',
      );
      expect(bad.outstanding, isNull);
    });

    test('monthlyEquivalent normalises every frequency', () {
      RecurringPayment withFrequency(RecurringFrequency f) =>
          RecurringPayment.fromMap('1', baseMap()..['frequency'] = f.name);

      expect(
        withFrequency(RecurringFrequency.monthly).monthlyEquivalent,
        499,
      );
      expect(
        withFrequency(RecurringFrequency.weekly).monthlyEquivalent,
        closeTo(499 * 52 / 12, 0.001),
      );
      expect(
        withFrequency(RecurringFrequency.yearly).monthlyEquivalent,
        closeTo(499 / 12, 0.001),
      );
    });
  });
}
