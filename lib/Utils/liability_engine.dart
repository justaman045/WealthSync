/// Unified liability calculation layer for credit cards, loans, EMIs and
/// recurring payments.
///
/// One shared engine so every screen (Wealth Builder, AI Insights bills,
/// Credit Card Detail, Loan Tracker) agrees on the same outstanding balance,
/// instead of each screen summing its own slice with different rules.
///
/// All functions are pure — no Firestore, no GetX — so they are unit-testable
/// without a widget tree or Firebase.
library;

import 'dart:math' as math;

import 'package:money_control/Models/recurring_payment_model.dart';

/// Result of a liability recalculation from actual payment history.
class LiabilityResult {
  /// Original / starting principal.
  final double principal;

  /// Balance still owed after all recorded payments.
  final double outstanding;

  /// Total interest accrued to date.
  final double interestAccrued;

  /// Total principal paid to date.
  final double principalPaid;

  /// Total amount paid (principal + interest) to date.
  final double totalPaid;

  /// Monthly EMI / minimum payment due.
  final double monthlyDue;

  /// True when the liability is fully paid off.
  final bool isPaidOff;

  const LiabilityResult({
    required this.principal,
    required this.outstanding,
    required this.interestAccrued,
    required this.principalPaid,
    required this.totalPaid,
    required this.monthlyDue,
    required this.isPaidOff,
  });
}

/// One row of an amortization schedule.
class AmortizationRow {
  final int month;
  final double openingBalance;
  final double principalPaid;
  final double interestPaid;
  final double totalPayment;
  final double closingBalance;

  const AmortizationRow({
    required this.month,
    required this.openingBalance,
    required this.principalPaid,
    required this.interestPaid,
    required this.totalPayment,
    required this.closingBalance,
  });
}

/// Compute the outstanding balance for a credit card / loan EMI from actual
/// recorded payment history plus the contractual terms.
///
/// When [calculationMethod] is [CalculationMethod.amortizing] and [interestRate]
/// is set, the balance uses the reducing-balance amortization formula.
/// Otherwise it uses simple linear reduction.
///
/// [paymentsMade] is the list of transactions linked to this liability
/// (filtered to this month/date window by the caller). Each payment reduces the
/// balance; when a payment is less than the monthly due, the shortfall carries
/// forward under [carryForward].
LiabilityResult recalculateLiability({
  required double principal,
  required double monthlyPayment,
  required CalculationMethod calculationMethod,
  required CarryForward carryForward,
  required double interestRate, // annual %, 0 for interest-free
  required int? numberOfPayments,
  required DateTime? termEndDate,
  required DateTime startDate,
  required List<double> paymentsMade, // amounts actually paid toward this liability
  required DateTime asOf,
}) {
  final monthlyRate = interestRate / 12 / 100;
  final monthsElapsed = _elapsedMonths(startDate, asOf);
  final monthsTotal =
      numberOfPayments ??
      (termEndDate != null ? _monthsBetween(startDate, termEndDate) : 0);

  // Simple case: no amortization, no interest — linear reduction from payments.
  double remaining = principal;
  double interestAccrued = 0.0;
  double totalPaid = paymentsMade.fold<double>(0, (s, v) => s + v);

  if (calculationMethod == CalculationMethod.amortizing &&
      monthlyRate > 0 &&
      monthsTotal > 0) {
    // Reducing-balance amortization:
    //   remaining = principal * (1+r)^n - payment * (((1+r)^n - 1) / r)
    // where n = months elapsed and payment = monthlyPayment.
    double r = monthlyRate;
    int n = monthsElapsed.clamp(0, monthsTotal.toDouble()).toInt();
    double factor = math.pow(1 + r, n).toDouble();
    remaining = principal * factor -
        monthlyPayment * (factor - 1) / r;

    // Track interest and principal components from the amortization schedule.
    double bal = principal;
    double interestAccruedLocal = 0.0;
    for (int m = 1; m <= n; m++) {
      final interest = bal * r;
      final principalPart = monthlyPayment - interest;
      interestAccruedLocal += interest;
      bal = (bal - principalPart).clamp(0, double.infinity);
    }
    interestAccrued = interestAccruedLocal;

    // Subtract any extra payments beyond the scheduled EMI.
    double scheduledTotal = monthlyPayment * n;
    double extraPaid = totalPaid - scheduledTotal;
    if (extraPaid > 0) {
      remaining = (remaining - extraPaid).clamp(0, principal);
    } else {
      remaining = remaining.clamp(0, principal);
    }
  } else {
    // Simple linear reduction or interest-free: remaining = principal - payments.
    remaining = (principal - totalPaid).clamp(0, principal);
  }

  remaining = remaining.clamp(0, principal);

  // Carry-forward: if a payment this cycle was below the monthly due, the
  // shortfall is added to the outstanding balance.
  if ((carryForward == CarryForward.always ||
          (carryForward == CarryForward.onMissed &&
              paymentsMade.isNotEmpty &&
              paymentsMade.last < monthlyPayment)) &&
      paymentsMade.isNotEmpty &&
      paymentsMade.last < monthlyPayment) {
    remaining = (remaining + (monthlyPayment - paymentsMade.last))
        .clamp(0, principal);
  }

  final monthlyDue = calculationMethod == CalculationMethod.amortizing &&
          monthlyRate > 0 &&
          monthsTotal > 0
      ? (principal *
              monthlyRate *
              math.pow(1 + monthlyRate, monthsTotal) /
              (math.pow(1 + monthlyRate, monthsTotal) - 1))
          .toDouble()
      : monthlyPayment;

  final principalPaid = principal - remaining;

  return LiabilityResult(
    principal: principal,
    outstanding: remaining,
    interestAccrued: interestAccrued,
    principalPaid: principalPaid.clamp(0, principal),
    totalPaid: totalPaid,
    monthlyDue: monthlyDue,
    isPaidOff: remaining <= 0,
  );
}

/// Build a full amortization schedule for a loan or credit card.
///
/// [monthlyPayment] is the fixed EMI/minimum payment. [interestRate] is annual
/// %. Returns one row per month until the balance reaches zero or [monthsCap]
/// is reached.
List<AmortizationRow> buildAmortizationSchedule({
  required double principal,
  required double monthlyPayment,
  required double interestRate, // annual %
  int monthsCap = 600, // 50 years max
}) {
  final schedule = <AmortizationRow>[];
  if (principal <= 0 || monthlyPayment <= 0) return schedule;

  final r = (interestRate / 12 / 100).toDouble();
  double outstanding = principal;

  for (int m = 1; m <= monthsCap && outstanding > 0; m++) {
    final opening = outstanding;
    final interest = (opening * r).toDouble();
    final principalPart = (monthlyPayment - interest).toDouble();
    final actualPrincipal = principalPart.clamp(0, opening).toDouble();
    outstanding = (opening - actualPrincipal).clamp(0, double.infinity).toDouble();
    schedule.add(AmortizationRow(
      month: m,
      openingBalance: opening,
      principalPaid: actualPrincipal,
      interestPaid: interest,
      totalPayment: monthlyPayment,
      closingBalance: outstanding,
    ));
    if (outstanding == 0) break;
  }
  return schedule;
}

/// Given a credit limit and one of {spent/outstanding, available balance},
/// compute the missing value so the three stay consistent.
///
/// - If [spentOrOutstanding] is provided (> 0), it wins and
///   [availableBalance] = limit - spentOrOutstanding.
/// - Else if [availableBalance] is provided (>= 0),
///   [spentOrOutstanding] = limit - availableBalance.
/// - Else both are zero.
///
/// Values are clamped so outstanding never exceeds the limit and available
/// never goes negative. Backward compatible: existing records that only set
/// `outstanding` continue to work (availableBalance is derived).
class CreditCardEntry {
  final double creditLimit;
  final double spentOrOutstanding;
  final double availableBalance;

  const CreditCardEntry({
    required this.creditLimit,
    required this.spentOrOutstanding,
    required this.availableBalance,
  });

  /// Build from either the spent/outstanding amount or the available balance.
  /// [mode] = 'spent' means [value] is the outstanding; 'available' means
  /// [value] is the remaining headroom.
  factory CreditCardEntry.fromInput({
    required double creditLimit,
    required double value,
    required bool enterAvailable,
  }) {
    final limit = creditLimit.clamp(0, double.infinity).toDouble();
    final val = value.clamp(0, double.infinity).toDouble();
    double spent, available;
    if (enterAvailable) {
      available = val.clamp(0, limit).toDouble();
      spent = (limit - available).clamp(0, limit).toDouble();
    } else {
      spent = val.clamp(0, limit).toDouble();
      available = (limit - spent).clamp(0, limit).toDouble();
    }
    return CreditCardEntry(
      creditLimit: limit,
      spentOrOutstanding: spent,
      availableBalance: available,
    );
  }

  /// True when the entry would exceed the credit limit (invalid state).
  bool get isOverLimit => spentOrOutstanding > creditLimit;

  /// True when the three values are mutually consistent.
  bool get isConsistent =>
      (spentOrOutstanding + availableBalance - creditLimit).abs() < 0.01;
}

/// Outstanding credit-card debt across both entry points: the manually tracked
/// portfolio total plus any credit-card-kind recurring liabilities.
///
/// This is the single source of truth used by Wealth Builder, AI Insights and
/// the net-worth card — replacing the previous per-screen sums that disagreed.
double creditCardOutstandingUnified({
  required double portfolioCreditCard,
  required Iterable<RecurringPayment> recurringPayments,
}) {
  final tracked = portfolioCreditCard > 0 ? portfolioCreditCard : 0.0;
  final recurring = recurringPayments
      .where((x) => x.kind == RecurringKind.creditCard && x.isActive)
      .fold<double>(
        0,
        (sum, x) => sum + (x.outstanding ?? 0).clamp(0, double.infinity),
      );
  return tracked + recurring;
}

/// Outstanding balance across all liability kinds (credit card, loan EMI,
/// BNPL, and recurring liabilities) from the recurring-payments list.
double totalLiabilityOutstanding(Iterable<RecurringPayment> payments) {
  double total = 0;
  for (final payment in payments) {
    if (!payment.isActive || !payment.kind.isLiability) continue;
    double owed = payment.autoCalculate &&
            payment.autoCalculatedOutstanding.isFinite
        ? payment.autoCalculatedOutstanding
        : (payment.outstanding ?? 0);
    total += owed.clamp(0, double.infinity);
  }
  return total;
}

/// Elapsed months between [start] and [end] (fractional for partial months).
double _elapsedMonths(DateTime start, DateTime end) {
  if (end.isBefore(start)) return 0;
  return (end.year - start.year) * 12 +
      (end.month - start.month) +
      (end.day >= start.day ? 0 : -0.5);
}

/// Whole months between [from] and [to].
int _monthsBetween(DateTime from, DateTime to) {
  if (to.isBefore(from)) return 0;
  return (to.year - from.year) * 12 + (to.month - from.month) + 1;
}

/// Principal component paid = principal - remaining (clamped).
double principalAmountPaid(double principal, double remaining) {
  final paid = principal - remaining;
  return paid.clamp(0, principal);
}
