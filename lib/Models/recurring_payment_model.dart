import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:money_control/Utils/num_parse.dart';

enum RecurringFrequency { monthly, weekly, yearly }

/// What a recurring payment actually is. Bills are ordinary committed
/// expenses; a credit card payment and a loan EMI are also *liabilities* — they
/// carry an outstanding balance the user is still paying down, which the bills
/// screen and AI Insights surface separately.
///
/// Stored as the enum `name`; a doc without the field (every subscription
/// created before this existed) reads back as [bill].
enum RecurringKind { bill, creditCard, loanEmi }

extension RecurringKindX on RecurringKind {
  bool get isLiability => this != RecurringKind.bill;
}

/// Calculation method for the outstanding balance.
enum CalculationMethod { simple, amortizing, interestFree }

/// Carry-forward behaviour when a payment is missed or under‑paid.
enum CarryForward { never, always, onMissed }

/// One category's recurring commitments due in the current month.
class RecurringPayment {
  final String id;
  final String userId;
  final String title;
  final double amount;
  final String category;
  final RecurringFrequency frequency;
  final DateTime startDate;
  final DateTime nextDueDate;
  final bool isActive;
  final bool autoPay;

  /// Bill, credit card payment or loan EMI. Defaults to [RecurringKind.bill].
  final RecurringKind kind;

  /// Remaining balance owed on a credit card / loan. Only meaningful when
  /// [kind] is a liability; `null` (or 0) means "not tracked".
  final double? outstanding;

  /// How the outstanding balance is computed.
  final CalculationMethod calculationMethod;

  /// What happens to unpaid amounts at month end.
  final CarryForward carryForward;

  /// Last day of the loan/term. If null, the balance is computed from
  /// [numberOfPayments] and [startDate].
  final DateTime? termEndDate;

  /// Number of monthly payments in the term. Used when [termEndDate] is null.
  final int? numberOfPayments;

  /// Annual interest rate in percent (e.g. 12 for 12%). Only used when
  /// [calculationMethod] is not [CalculationMethod.interestFree].
  final double? interestRate;

  /// When true, the outstanding balance is auto‑calculated from the term
  /// details instead of being entered manually. When false, [outstanding]
  /// is the sole source of truth.
  final bool autoCalculate;

  RecurringPayment({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    required this.category,
    required this.frequency,
    required this.startDate,
    required this.nextDueDate,
    required this.isActive,
    this.autoPay = false,
    this.kind = RecurringKind.bill,
    this.outstanding,
    this.calculationMethod = CalculationMethod.simple,
    this.carryForward = CarryForward.never,
    this.termEndDate,
    this.numberOfPayments,
    this.interestRate,
    this.autoCalculate = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'amount': amount,
      'category': category,
      'frequency': frequency.name,
      'startDate': Timestamp.fromDate(startDate),
      'nextDueDate': Timestamp.fromDate(nextDueDate),
      'isActive': isActive,
      'autoPay': autoPay,
      'kind': kind.name,
      'outstanding': outstanding,
      'calculationMethod': calculationMethod.name,
      'carryForward': carryForward.name,
      'termEndDate': termEndDate?.toIso8601String(),
      'numberOfPayments': numberOfPayments,
      'interestRate': interestRate,
      'autoCalculate': autoCalculate,
    };
  }

  factory RecurringPayment.fromMap(String id, Map<String, dynamic> map) {
    return RecurringPayment(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? 'Unknown',
      amount: _parseNum(map['amount']),
      category: map['category'] ?? 'Other',
      frequency: RecurringFrequency.values.firstWhere(
        (e) => e.name == map['frequency'],
        orElse: () => RecurringFrequency.monthly,
      ),
      startDate: ((map['startDate'] as dynamic)?.toDate()) ?? DateTime.now(),
      nextDueDate: ((map['nextDueDate'] as dynamic)?.toDate()) ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
      // Opt-in: only explicit `autoPay: true` enables auto-deduction. Docs
      // missing the field (legacy subscriptions created before the auto-pay
      // feature) must NOT silently auto-pay.
      autoPay: map['autoPay'] ?? false,
      // Unknown/absent kind is a plain bill, never a liability: a legacy doc
      // must not start inflating the outstanding-balance total.
      kind: RecurringKind.values.firstWhere(
        (e) => e.name == map['kind'],
        orElse: () => RecurringKind.bill,
      ),
      outstanding: map['outstanding'] is num
          ? _parseNum(map['outstanding'])
          : null,
      // New fields – fall back to defaults for legacy docs.
      calculationMethod: map['calculationMethod'] != null
          ? CalculationMethod.values.firstWhere(
              (e) => e.name == map['calculationMethod'],
              orElse: () => CalculationMethod.simple,
            )
          : CalculationMethod.simple,
      carryForward: map['carryForward'] != null
          ? CarryForward.values.firstWhere(
              (e) => e.name == map['carryForward'],
              orElse: () => CarryForward.never,
            )
          : CarryForward.never,
      termEndDate: map['termEndDate'] != null
          ? DateTime.tryParse(map['termEndDate'].toString())
          : null,
      numberOfPayments: map['numberOfPayments'] is num
          ? (map['numberOfPayments'] as num).toInt()
          : null,
      interestRate: map['interestRate'] is num
          ? (map['interestRate'] as num).toDouble()
          : null,
      autoCalculate: map['autoCalculate'] as bool? ?? true,
    );
  }

  /// Monthly cost of this payment, normalised across frequencies so a weekly
  /// or yearly commitment can be compared with monthly ones.
  double get monthlyEquivalent {
    switch (frequency) {
      case RecurringFrequency.monthly:
        return amount;
      case RecurringFrequency.weekly:
        return amount * 52 / 12;
      case RecurringFrequency.yearly:
        return amount / 12;
    }
  }

  /// Auto‑calculated outstanding balance based on term details.
  ///
  /// When [autoCalculate] is false or the term fields are not set, returns
  /// [outstanding] (or 0.0 if that is null).
  double get autoCalculatedOutstanding {
    // If the user has provided a manual outstanding value and autoCalculate
    // is off, respect the manual entry.
    if (!autoCalculate && outstanding != null && outstanding!.isFinite) {
      return outstanding!.abs();
    }

    // Need term information to compute.
    if (numberOfPayments == null && termEndDate == null) {
      return outstanding?.abs() ?? 0.0;
    }

    double totalAmount =
        outstanding ?? amount; // fall back to the original amount if no
    // manual outstanding is set.

    double monthsElapsed = _elapsedMonths(startDate, DateTime.now());
    double monthsTotal =
        (numberOfPayments ?? _monthsBetween(startDate, termEndDate ?? DateTime.now())).toDouble();

    // Guard against division by zero or degenerate terms.
    if (monthsTotal <= 0) return totalAmount;

    double monthlyPortion = totalAmount / monthsTotal;

    // Apply interest if method is amortizing and an interest rate is given.
    double remaining = totalAmount; // start from full amount
    if (calculationMethod == CalculationMethod.amortizing &&
        interestRate != null &&
        interestRate! > 0) {
      double monthlyRate = interestRate! / 12 / 100;
      // Simple amortising approximation: remaining = principal * (1+r)^n - payment * (( (1+r)^n - 1) / r)
      // Here we approximate the payment as the monthly portion + interest on the remaining.
      // For a pure “remaining balance after n payments” we use the standard formula:
      // remaining = principal * (1+r)^n - payment * (( (1+r)^n - 1) / r)
      // We'll treat monthlyPortion as the fixed payment amount.
      double r = monthlyRate;
      double n = monthsElapsed;
      double payment = monthlyPortion; // fixed monthly cash outflow
      remaining = totalAmount * math.pow(1 + r, n) -
          payment * (math.pow(1 + r, n) - 1) / r;
    } else {
      // Simple linear reduction: remaining = total - (monthlyPortion * elapsed)
      remaining = totalAmount - monthlyPortion * monthsElapsed;
    }

    // Ensure we never return negative.
    remaining = remaining.clamp(0, totalAmount);

    // Carry‑forward logic:
    // If the user has paid less than the monthlyPortion this month, the shortfall
    // is added to the next month’s remaining balance.
    // The caller (UI / insights) should add any shortfall from the current month
    // before displaying this value.
    // For now we just return the computed remaining; the carrier‑forward decision
    // is left to the UI layer that knows the actual payment made this month.

    return remaining.clamp(0, double.infinity);
  }

  /// Returns the number of whole months between two [DateTime]s.
  static int _monthsBetween(DateTime from, DateTime to) {
    if (to.isBefore(from)) return 0;
    return (to.year - from.year) * 12 + (to.month - from.month) + 1; // +1 so that the current month counts
  }

  /// Returns how many complete months have passed since [startDate].
  static double _elapsedMonths(DateTime start, DateTime now) {
    if (now.isBefore(start)) return 0;
    return (now.year - start.year) * 12 + (now.month - start.month) +
        (now.day >= start.day ? 0 : -0.5); // partial month handling
  }

  static double _parseNum(dynamic value) => roundAmount(safeToDouble(value));

  // Normalize money to paisa precision (2 decimals). Guards against legacy
  // float garbage like 10242.621637042335 leaking into new transactions.
  static double roundAmount(double value) =>
      double.parse(value.toStringAsFixed(2));
}