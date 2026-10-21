import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Models/loan_model.dart';

/// Builds a loan whose EMI is the mathematically correct payment for its
/// principal/rate/tenure, so amortization assertions are exact rather than
/// tuned to arbitrary numbers.
LoanModel _loan({
  double principal = 1000000,
  double rate = 8.5,
  int tenure = 240,
  DateTime? startDate,
  double? emi,
}) {
  return LoanModel(
    id: 'l1',
    name: 'Home Loan',
    loanType: LoanType.home,
    principalAmount: principal,
    interestRate: rate,
    emiAmount: emi ?? LoanModel.calcEmi(principal, rate, tenure),
    tenureMonths: tenure,
    // Far-future start date → monthsPaid clamps to 0, i.e. "not started yet".
    startDate: startDate ?? DateTime.now().add(const Duration(days: 3650)),
  );
}

void main() {
  group('LoanModel.calcEmi()', () {
    test('matches the standard reducing-balance EMI', () {
      // 10L @ 8.5% for 20y → ~8,678/month (textbook value).
      expect(LoanModel.calcEmi(1000000, 8.5, 240), closeTo(8678, 5));
    });

    test('zero rate is a flat principal/tenure split', () {
      expect(LoanModel.calcEmi(120000, 0, 12), closeTo(10000, 0.001));
    });

    test('guards non-positive tenure (would divide by zero)', () {
      // Both branches of the formula blow up without this guard.
      expect(LoanModel.calcEmi(100000, 8.5, 0), 0);
      expect(LoanModel.calcEmi(100000, 8.5, -12), 0);
      expect(LoanModel.calcEmi(0, 8.5, 12), 0);
      expect(LoanModel.calcEmi(-5, 8.5, 12), 0);
    });

    test('never returns a non-finite EMI', () {
      // A pathologically long tenure compounds to Infinity — must clamp to 0
      // rather than persist Infinity into Firestore.
      final emi = LoanModel.calcEmi(1000000, 50, 100000);
      expect(emi.isFinite, true);
    });

    test('a larger rate yields a larger EMI', () {
      expect(
        LoanModel.calcEmi(500000, 12, 60),
        greaterThan(LoanModel.calcEmi(500000, 6, 60)),
      );
    });
  });

  group('LoanModel.monthsPaid', () {
    test('clamps to 0 before the loan starts', () {
      expect(_loan().monthsPaid, 0);
    });

    test('counts whole months elapsed', () {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month - 3, 15);
      expect(_loan(startDate: start).monthsPaid, 3);
    });

    test('caps at the tenure so an ended loan never over-counts', () {
      final start = DateTime.now().subtract(const Duration(days: 365 * 40));
      expect(_loan(tenure: 24, startDate: start).monthsPaid, 24);
    });
  });

  group('LoanModel.outstandingBalance', () {
    test('equals the principal before any payment', () {
      // monthsPaid == 0 → nothing repaid, so outstanding IS the principal.
      expect(_loan().outstandingBalance, closeTo(1000000, 0.01));
    });

    test('is fully repaid once the tenure elapses', () {
      final start = DateTime.now().subtract(const Duration(days: 365 * 30));
      expect(_loan(startDate: start).outstandingBalance, 0);
    });

    test('decreases as payments are made', () {
      final now = DateTime.now();
      final fresh = _loan(startDate: DateTime(now.year, now.month - 1, 1));
      final seasoned = _loan(startDate: DateTime(now.year, now.month - 24, 1));
      expect(seasoned.outstandingBalance, lessThan(fresh.outstandingBalance));
    });

    test('never exceeds the principal and is never negative', () {
      final now = DateTime.now();
      for (final months in [0, 1, 12, 60, 120]) {
        final start = DateTime(now.year, now.month - months, 1);
        final o = _loan(startDate: start).outstandingBalance;
        expect(o, greaterThanOrEqualTo(0));
        expect(o, lessThanOrEqualTo(1000000));
      }
    });

    test('a zero-rate loan amortizes linearly', () {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month - 10, 1);
      final loan = _loan(
        principal: 120000,
        rate: 0,
        tenure: 12,
        emi: 10000,
        startDate: start,
      );
      // 10 payments of 10,000 against 120,000 → 20,000 left.
      expect(loan.outstandingBalance, closeTo(20000, 0.01));
      expect(loan.principalPaid, closeTo(100000, 0.01));
    });
  });

  group('LoanModel.progressPercent', () {
    test('is 0 before the first payment and 1 once repaid', () {
      expect(_loan().progressPercent, 0);
      final done = DateTime.now().subtract(const Duration(days: 365 * 30));
      expect(_loan(startDate: done).progressPercent, 1.0);
    });

    test('is 0 (not NaN) when the principal is zero', () {
      // Guards the `principalAmount > 0` branch — a 0/0 would be NaN and break
      // the progress bar widget.
      final l = _loan(principal: 0, emi: 0);
      expect(l.progressPercent, 0);
      expect(l.progressPercent.isNaN, false);
    });

    test('stays within 0..1', () {
      final now = DateTime.now();
      for (final months in [0, 6, 60, 240]) {
        final p = _loan(
          startDate: DateTime(now.year, now.month - months, 1),
        ).progressPercent;
        expect(p, greaterThanOrEqualTo(0.0));
        expect(p, lessThanOrEqualTo(1.0));
      }
    });
  });

  group('LoanModel.buildSchedule()', () {
    test('has one entry per month and ends fully repaid', () {
      final schedule = _loan(tenure: 12, principal: 120000, rate: 12).buildSchedule();
      expect(schedule.length, 12);
      expect(schedule.last.outstanding, closeTo(0, 0.01));
    });

    test('interest shrinks and principal grows over the term', () {
      final schedule = _loan(tenure: 24, principal: 200000, rate: 10).buildSchedule();
      expect(
        schedule.first.interestPaid,
        greaterThan(schedule.last.interestPaid),
      );
    });

    test('the final entry fully clears the balance (no rounding residue)', () {
      final schedule = _loan(tenure: 36, principal: 500000, rate: 9).buildSchedule();
      expect(schedule.last.outstanding, closeTo(0, 0.5));
    });

    test('outstanding decreases monotonically', () {
      final schedule = _loan(tenure: 18, principal: 300000, rate: 7).buildSchedule();
      for (var i = 1; i < schedule.length; i++) {
        expect(
          schedule[i].outstanding,
          lessThanOrEqualTo(schedule[i - 1].outstanding + 0.01),
        );
      }
    });

    test('principal + interest paid reconciles against the principal', () {
      final loan = _loan(tenure: 12, principal: 120000, rate: 6);
      final schedule = loan.buildSchedule();
      final principalSum = schedule.fold<double>(
        0,
        (s, e) => s + e.principalPaid,
      );
      // Every rupee of principal must be accounted for across the schedule.
      expect(principalSum, closeTo(120000, 1.0));
    });
  });

  group('LoanModel.totalInterestPayable', () {
    test('is positive for an interest-bearing loan', () {
      expect(_loan().totalInterestPayable, greaterThan(0));
    });

    test('is exactly zero for a zero-rate loan', () {
      expect(
        _loan(principal: 120000, rate: 0, tenure: 12, emi: 10000)
            .totalInterestPayable,
        closeTo(0, 0.001),
      );
    });
  });

  group('LoanModel.fromMap()', () {
    test('reads an unknown loanType as other instead of throwing', () {
      // A value written by a newer client must not crash the list.
      final l = LoanModel.fromMap('l1', {
        'name': 'X',
        'loanType': 'crypto_margin',
        'principalAmount': '1000',
        'interestRate': '5',
        'emiAmount': '100',
        'tenureMonths': '12',
      });
      expect(l.loanType, LoanType.other);
    });

    test('parses numeric fields persisted as strings', () {
      final l = LoanModel.fromMap('l1', {
        'name': 'X',
        'loanType': 'car',
        'principalAmount': '1000.5',
        'interestRate': '5',
        'emiAmount': '100',
        'tenureMonths': '12',
      });
      expect(l.principalAmount, 1000.5);
      expect(l.tenureMonths, 12);
      expect(l.loanType, LoanType.car);
    });

    test('a NaN principal reads as 0 rather than poisoning totals', () {
      final l = LoanModel.fromMap('l1', {
        'name': 'X',
        'loanType': 'car',
        'principalAmount': 'NaN',
        'interestRate': 5,
        'emiAmount': 100,
        'tenureMonths': 12,
      });
      expect(l.principalAmount, 0);
      expect(l.principalAmount.isNaN, false);
    });

    test('defaults isActive to true when the field is absent', () {
      final l = LoanModel.fromMap('l1', {
        'name': 'X',
        'loanType': 'car',
        'principalAmount': 1,
        'interestRate': 1,
        'emiAmount': 1,
        'tenureMonths': 1,
      });
      expect(l.isActive, true);
    });
  });

  group('LoanModel.copyWith()', () {
    test('preserves identity and money fields', () {
      final l = _loan();
      final copy = l.copyWith(isActive: false);
      expect(copy.id, l.id);
      expect(copy.principalAmount, l.principalAmount);
      expect(copy.emiAmount, l.emiAmount);
      expect(copy.isActive, false);
    });
  });
}
