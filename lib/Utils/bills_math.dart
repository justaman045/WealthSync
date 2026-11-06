/// Monthly-bill maths behind the AI Insights "bills" figure and the
/// per-category bill card.
///
/// The product rule, in one sentence: a category's monthly bill is the average
/// of the months that actually have spending in it (500 one month and 600 the
/// next is ₹550, not a fixed `/3`), a recurring payment marks that category as
/// due this month even before any transaction exists, and a user-entered amount
/// always wins.
///
/// Everything here is pure so the screen, the projection and the tests cannot
/// disagree about the same numbers.
library;

import 'dart:math' as math;

import 'package:money_control/Models/recurring_payment_model.dart';
import 'package:money_control/Utils/wealth_math.dart';

/// Average monthly spend for a category, over the months that have spending.
///
/// The divisor is the number of months **with data**, not the window size: a
/// user who started two months ago must not have their bill halved by ten empty
/// months. Months without spending are missing data, not a month of zero.
double billMonthlyAverage(Iterable<double> monthlyTotals) {
  double sum = 0;
  int months = 0;
  for (final total in monthlyTotals) {
    if (total > 0) {
      sum += total;
      months++;
    }
  }
  if (months == 0) return 0;
  return sum / months;
}

/// One category's recurring commitments due in the current month.
class RecurringDue {
  /// Monthly-equivalent amount (weekly/yearly normalised, see
  /// [RecurringPayment.monthlyEquivalent]).
  final double amount;

  /// Earliest due date among the payments counted.
  final DateTime date;

  /// True when any counted payment is a credit card / loan EMI.
  final bool isLiability;

  const RecurringDue({
    required this.amount,
    required this.date,
    required this.isLiability,
  });
}

/// A recurring payment counts once its due date has arrived; the amount stays
/// in the month it is due until the payment is marked paid and the date
/// advances. "Due" therefore means: this calendar month, or overdue.
bool recurringIsDue(RecurringPayment payment, DateTime now) {
  if (!payment.isActive) return false;
  final due = payment.nextDueDate;
  if (due.year == now.year && due.month == now.month) return true;
  return due.isBefore(DateTime(now.year, now.month, 1));
}

/// Recurring payments due (or overdue) this month, grouped by category name as
/// written on the payment. Callers match categories case-insensitively.
Map<String, RecurringDue> recurringDueByCategory(
  Iterable<RecurringPayment> payments, {
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final totals = <String, double>{};
  final dates = <String, DateTime>{};
  final liabilities = <String, bool>{};

  for (final payment in payments) {
    if (!recurringIsDue(payment, ref)) continue;
    final key = payment.category.toLowerCase().trim();
    totals[key] = (totals[key] ?? 0) + payment.monthlyEquivalent;
    final previous = dates[key];
    if (previous == null || payment.nextDueDate.isBefore(previous)) {
      dates[key] = payment.nextDueDate;
    }
    liabilities[key] =
        (liabilities[key] ?? false) || payment.kind.isLiability;
  }

  return {
    for (final entry in totals.entries)
      entry.key: RecurringDue(
        amount: entry.value,
        date: dates[entry.key]!,
        isLiability: liabilities[entry.key] ?? false,
      ),
  };
}

/// Outstanding balance still owed across every active credit card / loan EMI
/// payment. A stock, not a flow: it does not depend on the due date.
///
/// When a payment has [autoCalculate] enabled, this returns the auto-calculated
/// remaining balance based on the term details (start date, term end/number of
/// payments, interest rate, and calculation method). Otherwise it falls back to
/// the manual [outstanding] field.
double liabilityOutstanding(Iterable<RecurringPayment> payments) {
  double total = 0;
  for (final payment in payments) {
    if (!payment.isActive || !payment.kind.isLiability) continue;
    // Use auto-calculated outstanding when autoCalculate is enabled and term
    // details are available; otherwise respect the manually entered [outstanding].
    double owed = payment.autoCalculate && payment.autoCalculatedOutstanding.isFinite
        ? payment.autoCalculatedOutstanding
        : (payment.outstanding ?? 0);
    if (owed > 0) total += owed;
  }
  return total;
}

/// One category's bill for this month.
class MonthlyBill {
  final String category;

  /// Average of the months with spending (0 when there is no history yet).
  final double autoAmount;

  /// The user's own amount; 0 means Auto.
  final double overrideAmount;

  /// Recurring payments due this month, monthly-equivalent.
  final double recurringDue;

  /// What has already been recorded in this category this month.
  final double spentThisMonth;

  final DailyLimitRole role;

  /// Earliest unpaid recurring due date, when this category has one.
  final DateTime? dueDate;

  /// The due recurring payment is a credit card / loan EMI.
  final bool isLiability;

  /// Whether this bill's [plan] was derived from the auto-calculated outstanding
  /// rather than a manual entry. Useful for UI badges.
  final bool autoCalculated;

  const MonthlyBill({
    required this.category,
    required this.autoAmount,
    required this.overrideAmount,
    required this.recurringDue,
    required this.spentThisMonth,
    required this.role,
    this.dueDate,
    this.isLiability = false,
    this.autoCalculated = false,
  });

  bool get isOverridden => overrideAmount > 0;

  bool get isRecurring => recurringDue > 0;

  /// The amount this category is expected to cost this month.
  ///
  /// A manual amount always wins (the user said so). Otherwise it is the
  /// largest of what history says, what a recurring payment demands, and what
  /// has already been spent — never their sum, or a rent that is both a
  /// historical average and a recurring payment would be counted twice.
  double get plan => isOverridden
      ? overrideAmount
      : math.max(autoAmount, math.max(recurringDue, spentThisMonth));

  /// The part of [plan] reserved against income in the daily limit.
  ///
  /// Fixed-role categories are committed in full. A discretionary category is
  /// only committed for its *unpaid* recurring part: the rest is "other items",
  /// which the daily limit subtracts separately as it is spent.
  double get committed {
    if (role == DailyLimitRole.ignored) return 0;
    if (role == DailyLimitRole.fixed) return math.max(plan, spentThisMonth);
    return math.max(0, recurringDue - spentThisMonth);
  }

  /// True once enough has been recorded to treat the bill as settled.
  bool get isPaid => plan > 0 && spentThisMonth >= plan * kBillPaidFraction;

  /// Not yet settled, but expected this month.
  bool get isUnpaid => plan > 0 && !isPaid;

  /// What is still expected in this category this month (never negative).
  double get remaining => math.max(0, plan - spentThisMonth);

  MonthlyBill copyWithAmount(double amount) => MonthlyBill(
    category: category,
    autoAmount: autoAmount,
    overrideAmount: amount,
    recurringDue: recurringDue,
    spentThisMonth: spentThisMonth,
    role: role,
    dueDate: dueDate,
    isLiability: isLiability,
    autoCalculated: autoCalculated,
  );
}

/// The month's bills, per category, plus the totals the UI shows.
class MonthlyBills {
  final List<MonthlyBill> categories;
  final double outstanding;

  const MonthlyBills({required this.categories, required this.outstanding});

  /// Reserved against income (fixed-role bills + unpaid recurring commitments).
  double get committedTotal =>
      categories.fold<double>(0, (sum, bill) => sum + bill.committed);

  /// Full expected outflow, including the discretionary categories' plans.
  double get plannedTotal =>
      categories.fold<double>(0, (sum, bill) => sum + bill.plan);

  /// Bills with a recurring payment that is not settled yet.
  List<MonthlyBill> get unpaidRecurring =>
      categories.where((bill) => bill.isRecurring && bill.isUnpaid).toList();

  double get liabilityDueTotal => categories
      .where((bill) => bill.isLiability)
      .fold<double>(0, (sum, bill) => sum + bill.recurringDue);

  DateTime? get nextDueDate {
    DateTime? earliest;
    for (final bill in categories) {
      final date = bill.dueDate;
      if (date == null) continue;
      if (earliest == null || date.isBefore(earliest)) earliest = date;
    }
    return earliest;
  }

  MonthlyBill? billFor(String category) {
    final key = category.toLowerCase().trim();
    for (final bill in categories) {
      if (bill.category.toLowerCase().trim() == key) return bill;
    }
    return null;
  }
}

/// Builds the month's bills from the data the Insights screen already holds.
///
/// [categoryMonthly] is `category -> monthKey -> total` with monthKey built as
/// `year * 100 + month` (the same key `analysis.dart` uses). [currentMonthKey]
/// and [historyFloorMonthKey] bound the window: only completed months inside it
/// feed the average, so this month's partial spending cannot inflate its own
/// bill.
MonthlyBills buildMonthlyBills({
  required Map<String, Map<int, double>> categoryMonthly,
  required int currentMonthKey,
  required int historyFloorMonthKey,
  required Map<String, double> fixedAmountOverrides,
  required Map<String, String> treatmentOverrides,
  required Iterable<RecurringPayment> recurring,
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final dueByCategory = recurringDueByCategory(recurring, now: ref);

  final names = <String>{...categoryMonthly.keys};
  for (final payment in recurring) {
    if (!payment.isActive) continue;
    final name = payment.category.trim();
    if (name.isNotEmpty) names.add(name);
  }

  final bills = <MonthlyBill>[];
  // Canonical name per lowercased key: keeps the first-seen original casing
  // so "EMI" (recurring) and "emi" (transactions) don't create duplicate bills.
  final canonicalNames = <String, String>{};
  for (final name in names) {
    final key = name.toLowerCase().trim();
    canonicalNames.putIfAbsent(key, () => name.trim());
    final canonicalName = canonicalNames[key]!;
    // Try the original name first (tests construct maps with original casing),
    // then the lowercased key (analysis.dart builds categoryMonthly with
    // _categoryKey which lowercases).
    final months =
        categoryMonthly[name.trim()] ?? categoryMonthly[key] ?? const <int, double>{};

    final history = <double>[];
    for (final entry in months.entries) {
      if (entry.key >= historyFloorMonthKey && entry.key < currentMonthKey) {
        history.add(entry.value);
      }
    }
    final auto = billMonthlyAverage(history);
    final spent = months[currentMonthKey] ?? 0;
    final due = dueByCategory[key];
    final override = fixedAmountOverrides[key] ?? 0;
    final role = resolveDailyLimitRole(
      canonicalName,
      treatmentOverrides: treatmentOverrides,
    );

    // A category nobody spent on, planned or owes anything for is noise.
    if (auto == 0 && spent == 0 && due == null && override == 0) continue;

    // Determine if this bill's outstanding should be auto-calculated.
    final recurringPayment = recurring.firstWhere(
      (p) => p.category.toLowerCase().trim() == key && p.isActive,
      orElse: () => RecurringPayment(
        id: '',
        userId: '',
        title: canonicalName,
        amount: 0,
        category: canonicalName,
        frequency: RecurringFrequency.monthly,
        startDate: DateTime.now(),
        nextDueDate: DateTime.now(),
        isActive: false,
      ),
    );
    final bool useAutoCalc =
        recurringPayment.autoCalculate &&
            (recurringPayment.termEndDate != null ||
                recurringPayment.numberOfPayments != null) &&
            recurringPayment.autoCalculatedOutstanding.isFinite;

    bills.add(
      MonthlyBill(
        category: canonicalName,
        autoAmount: auto,
        overrideAmount: override,
        recurringDue: due?.amount ?? 0,
        spentThisMonth: spent,
        role: role,
        dueDate: due?.date,
        isLiability: due?.isLiability ?? false,
        // Flag that the outstanding for this category was auto-calculated.
        autoCalculated: useAutoCalc,
      ),
    );
  }

  bills.sort((a, b) {
    final byPlan = b.plan.compareTo(a.plan);
    return byPlan != 0 ? byPlan : a.category.compareTo(b.category);
  });

  return MonthlyBills(
    categories: bills,
    outstanding: liabilityOutstanding(recurring),
  );
}