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
      expect(compact(999999), '10.0L');
    });

    test('formats thousands', () {
      expect(compact(1500), '1K');
      expect(compact(99999), '100K');
    });

    test('formats small numbers', () {
      expect(compact(999), '999');
      expect(compact(0), '0');
      expect(compact(500), '500');
    });

    test('handles boundary between K and L', () {
      expect(compact(100000), '1.0L');
      expect(compact(99999), '100K');
    });
  });
}
