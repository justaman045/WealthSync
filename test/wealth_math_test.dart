import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Utils/wealth_math.dart';

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
}
