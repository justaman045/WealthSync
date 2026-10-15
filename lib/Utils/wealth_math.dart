import 'dart:math' as math;

import 'package:intl/intl.dart';

/// Linearly interpolates between the two bracketing entries in [milestones].
/// [age] is clamped to the table's min/max range.
double milestone(int age, Map<int, double> milestones) {
  final keys = milestones.keys.toList()..sort();
  if (age <= keys.first) return milestones[keys.first]!;
  if (age >= keys.last) return milestones[keys.last]!;
  int lo = keys.first, hi = keys.last;
  for (final k in keys) {
    if (k <= age) lo = k;
    if (k >= age && k < hi) hi = k;
  }
  if (lo == hi) return milestones[lo]!;
  final t = (age - lo) / (hi - lo);
  return milestones[lo]! + t * (milestones[hi]! - milestones[lo]!);
}

/// Compact number formatting: 1.2Cr, 5L, 10K, or raw.
///
/// Rounds down at every step, so the label never reports more than the actual
/// amount: rounding up turns 99999 into "100K" and 1500 into "2K", which
/// overstates a balance the user is looking at.
String compact(double v) {
  final sign = v < 0 ? '-' : '';
  final absVal = v.abs();
  if (absVal >= 10000000) {
    return "$sign${(absVal / 1000000).floor() / 10.0}Cr";
  }
  if (absVal >= 100000) {
    return "$sign${(absVal / 10000).floor() / 10.0}L";
  }
  if (absVal >= 1000) return "$sign${(absVal / 1000).floor()}K";
  return v.toStringAsFixed(0);
}

// ── Age-milestone tables ────────────────────────────────────────────────
// Values are multiples of annual expense at each age bracket.
// Source: Fidelity lifecycle model adapted for India, SEBI/AMFI guidelines.
// Linear interpolation is used between brackets.

const sipM = {22: 0.0, 25: 0.5, 30: 2.0, 35: 5.0, 40: 10.0, 50: 20.0, 60: 35.0};
const stocksM = {22: 0.0, 25: 0.3, 30: 1.0, 35: 3.0, 40: 6.0, 50: 12.0, 60: 20.0};
const etfM = {22: 0.0, 25: 0.2, 30: 0.8, 35: 2.0, 40: 4.0, 50: 8.0, 60: 12.0};
const foreignM = {22: 0.0, 25: 0.0, 30: 0.5, 35: 1.0, 40: 2.0, 50: 4.0, 60: 6.0};
const startupM = {22: 0.0, 25: 0.1, 30: 0.3, 35: 0.5, 40: 0.5, 50: 0.5, 60: 0.5};
const pfM = {22: 0.5, 25: 0.8, 30: 1.5, 35: 3.0, 40: 6.0, 50: 12.0, 60: 18.0};
const ppfM = {22: 0.3, 25: 0.5, 30: 1.5, 35: 3.0, 40: 6.0, 50: 10.0, 60: 15.0};
const vpfM = {22: 0.0, 25: 0.0, 30: 0.5, 35: 1.0, 40: 2.0, 50: 4.0, 60: 7.0};
const npsM = {22: 0.0, 25: 0.0, 30: 0.5, 35: 1.5, 40: 3.0, 50: 7.0, 60: 12.0};
const bondsM = {22: 0.0, 25: 0.0, 30: 0.5, 35: 1.0, 40: 2.0, 50: 5.0, 60: 10.0};
const goldM = {22: 0.2, 25: 0.3, 30: 0.5, 35: 0.7, 40: 1.0, 50: 1.2, 60: 1.5};
const sgbM = {22: 0.0, 25: 0.1, 30: 0.3, 35: 0.5, 40: 0.7, 50: 1.0, 60: 1.2};
const cryptoM = {22: 0.0, 25: 0.1, 30: 0.2, 35: 0.2, 40: 0.2, 50: 0.1, 60: 0.0};
const reitM = {22: 0.0, 25: 0.0, 30: 0.3, 35: 0.7, 40: 1.5, 50: 3.0, 60: 4.0};
const p2pM = {22: 0.0, 25: 0.1, 30: 0.3, 35: 0.5, 40: 0.7, 50: 1.0, 60: 1.0};
const insuranceM = {22: 5.0, 25: 8.0, 30: 10.0, 35: 10.0, 40: 10.0, 50: 8.0, 60: 5.0};

/// Target keys that represent accumulated savings (not coverage or debt).
/// Insurance is excluded because it is coverage, not a savings corpus.
const List<String> investableTargetKeys = [
  'bank', 'fd', 'postOffice',
  'sip', 'stocks', 'etf', 'foreignStocks', 'startupEquity',
  'pf', 'ppf', 'vpf', 'nps', 'bonds',
  'gold', 'sgb', 'crypto', 'reit', 'p2p',
];

/// Result of an ideal-income calculation.
class IdealIncome {
  final double monthlyExpense;
  final double idealMonthlyIncome;
  final double idealAnnualIncome;
  final double monthlySavingsNeeded;

  const IdealIncome({
    required this.monthlyExpense,
    required this.idealMonthlyIncome,
    required this.idealAnnualIncome,
    required this.monthlySavingsNeeded,
  });
}

/// Computes the monthly income the user should aim for so that their current
/// spending is covered AND every investable target is funded by retirement.
///
/// - Savings needed = sum of (target.effective − currentValue) gaps over
///   [investableTargetKeys], divided by months until age 60 (minimum 1 year).
/// - A minimum savings rate ([minSavingsRate] of monthly expense) is enforced
///   so the figure never drops to bare living cost even when targets are met.
IdealIncome calculateIdealIncome({
  required double monthlyExpense,
  required Map<String, double> targetEffective,
  required Map<String, double> current,
  required int age,
  double minSavingsRate = 0.20,
}) {
  final expense = monthlyExpense < 0 ? 0.0 : monthlyExpense;

  final monthsToRetirement = ((60 - age) * 12.0).clamp(12, double.infinity);
  double deficit = 0;
  for (final key in investableTargetKeys) {
    final target = targetEffective[key] ?? 0;
    final have = current[key] ?? 0;
    final gap = target - have;
    if (gap > 0) deficit += gap;
  }
  final deficitMonthly = deficit / monthsToRetirement;
  final monthlySavings = deficitMonthly > expense * minSavingsRate
      ? deficitMonthly
      : expense * minSavingsRate;

  final idealMonthly = expense + monthlySavings;
  return IdealIncome(
    monthlyExpense: expense,
    idealMonthlyIncome: idealMonthly,
    idealAnnualIncome: idealMonthly * 12,
    monthlySavingsNeeded: monthlySavings,
  );
}

/// Currency-aware annual income label. INR uses LPA / Cr p.a.; other
/// currencies use a compact symbol + "/yr" (e.g. $85K/yr).
String formatAnnualIncome(
  double annual, {
  required String currencyCode,
  required String symbol,
}) {
  if (currencyCode == 'INR') {
    if (annual >= 10000000) {
      return "$symbol${(annual / 10000000).toStringAsFixed(1)} Cr p.a.";
    }
    return "$symbol${(annual / 100000).toStringAsFixed(1)} LPA";
  }
  final formatter = NumberFormat.compactCurrency(
    symbol: symbol,
    locale: 'en_US',
    decimalDigits: 1,
  );
  return "${formatter.format(annual)}/yr";
}

/// The balance the home card headlines, assembled from the opt-in overlays the
/// user toggles on the card itself.
///
/// Both overlays are *temporary view* switches, never persisted: [includeLent]
/// folds money owed back to the user into the figure, [includeDues] subtracts
/// this month's not-yet-debited commitments. Dues are excluded by default
/// because an undebited subscription is money the account still holds, and
/// deducting it unasked reports a balance that does not exist.
///
/// Deliberately unclamped: a net-lent or dues overlay can legitimately take the
/// headline negative, and hiding that would misreport the position.
double computeDisplayTotal({
  required double balance,
  double netLent = 0,
  bool includeLent = false,
  double pendingDues = 0,
  bool includeDues = false,
}) {
  var total = balance;
  if (includeLent) total += netLent;
  if (includeDues) total -= pendingDues;
  return total;
}

/// Compact monthly label (e.g. ₹1.3L or $7.2K). Locale-aware for INR.
String formatMonthlyIncome(
  double monthly, {
  required String currencyCode,
  required String symbol,
}) {
  final formatter = NumberFormat.compactCurrency(
    symbol: symbol,
    locale: currencyCode == 'INR' ? 'en_IN' : 'en_US',
    decimalDigits: 1,
  );
  return formatter.format(monthly);
}

/// Default share of income reserved for savings when advising a daily limit.
const double kDefaultSavingsRate = 0.20;

/// Category keywords that name a fixed/committed monthly expense (rent, EMIs,
/// bills, subscriptions, …). Drives the fixed-vs-discretionary split behind
/// [computeDailyLimit]; see [isFixedExpenseCategory].
const List<String> kFixedExpenseKeywords = [
  'rent',
  'emi',
  'mortgage',
  'loan',
  'insurance',
  'premium',
  'subscription',
  'bill',
  'utility',
  'electricity',
  'water',
  'gas',
  'internet',
  'broadband',
  'wifi',
  'telephone',
  'mobile',
  'recharge',
  'credit card',
  'tax',
  'fee',
  'tuition',
  'school',
  'maintenance',
];

final Map<String, RegExp> _fixedKeywordReCache = {};

RegExp _fixedKeywordRe(String keyword) => _fixedKeywordReCache.putIfAbsent(
      keyword,
      () => RegExp('(^|[^a-z])${RegExp.escape(keyword)}(s)?([^a-z]|\$)'),
    );

/// True when [category] names a fixed/committed expense.
///
/// Matches whole words (plural-tolerant) anywhere in the name, so "Bills",
/// "Loan EMI" and "Credit Card Bill" are fixed while "Coffee", "Freelance" and
/// "Food" are not — a naive `contains('fee')` would misfile "Coffee" as fixed
/// because it contains "fee". Used identically for the current-month variable
/// total and the fixed forecast so a bill can never be counted as
/// discretionary while its forecast is still reserved.
bool isFixedExpenseCategory(String? category) {
  if (category == null) return false;
  final c = category.toLowerCase().trim();
  if (c.isEmpty) return false;
  for (final keyword in kFixedExpenseKeywords) {
    if (_fixedKeywordRe(keyword).hasMatch(c)) return true;
  }
  return false;
}

/// How a category's spending counts toward the Smart Daily Limit.
///
/// [fixed] is a committed bill (reserved before the daily allowance is worked
/// out); [variable] is discretionary "other items" spending that eats into the
/// allowance; [ignored] is excluded from the limit entirely — the right call for
/// investments/SIPs/transfers, which are savings, not spending (the savings rate
/// already reserves them, so counting them again would double-penalise).
enum DailyLimitRole { fixed, variable, ignored }

/// Resolves [category]'s role toward the daily limit.
///
/// [treatmentOverrides] maps a lowercased, trimmed category name to `'fixed'` or
/// `'ignored'` (a user's per-category choice). An explicit override always wins;
/// otherwise the keyword classifier decides fixed vs variable, and `'auto'` /
/// missing entries are never ignored.
DailyLimitRole resolveDailyLimitRole(
  String? category, {
  Map<String, String> treatmentOverrides = const {},
}) {
  final key = category?.toLowerCase().trim();
  if (key != null && key.isNotEmpty) {
    // Try exact normalized first, then also fall back to a case/space-insensitive
    // match against the provided override keys (callers may pass raw names).
    String? overrideValue = treatmentOverrides[key];
    if (overrideValue == null || overrideValue.isEmpty) {
      for (final entry in treatmentOverrides.entries) {
        final overrideKey = entry.key.toLowerCase().trim();
        if (overrideKey == key) {
          overrideValue = entry.value;
          break;
        }
      }
    }
    if (overrideValue != null && overrideValue.isNotEmpty) {
      switch (overrideValue.toLowerCase().trim()) {
        case 'fixed':
          return DailyLimitRole.fixed;
        case 'ignored':
          return DailyLimitRole.ignored;
        default:
          break;
      }
    }
  }
  return isFixedExpenseCategory(category)
      ? DailyLimitRole.fixed
      : DailyLimitRole.variable;
}

/// Income source modes used by [computeExpectedIncome].
enum IncomeMode { manual, autoBlend, autoSalaryWindow }

/// Returns true if [date] is in the first week of its month (calendar days 1–7 inclusive).
bool isInFirstWeek(DateTime date) {
  // Calendar days 1-7, inclusive. Time component ignored.
  final d = DateTime(date.year, date.month, date.day);
  return d.day >= 1 && d.day <= 7;
}

/// Returns the last working day (Mon–Fri) of [month]/[year]. Bank holidays are
/// skipped for now. If the month ends Sat/Sun, returns the preceding Fri.
DateTime lastWorkingDayOfMonth(int year, int month) {
  // Get last calendar day of month.
  final lastDay = DateTime(year, month + 1, 0);
  DateTime d = DateTime(lastDay.year, lastDay.month, lastDay.day);
  while (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
    d = d.subtract(const Duration(days: 1));
  }
  return DateTime(d.year, d.month, d.day);
}
/// Returns the last working day (Mon–Fri) of the previous month relative to [reference].
DateTime lastWorkingDayOfPreviousMonth(DateTime reference) {
  final prevMonth = reference.month == 1 ? 12 : reference.month - 1;
  final prevYear = reference.month == 1 ? reference.year - 1 : reference.year;
  return lastWorkingDayOfMonth(prevYear, prevMonth);
}


/// Returns true if [date] is exactly the last working day of its own month.
bool isLastWorkingDay(DateTime date) {
  final lwm = lastWorkingDayOfMonth(date.year, date.month);
  final d = DateTime(date.year, date.month, date.day);
  return d.year == lwm.year && d.month == lwm.month && d.day == lwm.day;
}

/// Sum of income (recipientId == uid) in the union of:
/// - first week of current month (calendar days 1–7) AND/OR
/// - last working day of previous month (Mon–Fri).
/// Union sum; only recorded transactions counted.
double sumIncomeInSalaryWindowThisMonth(List<dynamic> allTx, String uid) {
  final now = DateTime.now();
  final year = now.year;
  final month = now.month;
  final lwmPrev = lastWorkingDayOfPreviousMonth(now);
  double sum = 0;

  for (final tx in allTx) {
    final recipientId = tx.recipientId;
    if (recipientId != uid) continue;
    final tDate = tx.date as DateTime;

    final inFirstWeekCurrent = (tDate.year == year && tDate.month == month && tDate.day >= 1 && tDate.day <= 7);
    final isLwmPrev = (tDate.year == lwmPrev.year && tDate.month == lwmPrev.month && tDate.day == lwmPrev.day);
    if (inFirstWeekCurrent || isLwmPrev) {
      final amt = tx.amount;
      if (amt < 0) {
        sum += (-amt);
      } else {
        sum += amt.abs();
      }
    }
  }
  return sum;
}

/// Result of [computeExpectedIncome].
class ExpectedIncomeResult {
  final double expectedIncome; // 0.0 means not available
  final IncomeMode effectiveMode;
  final bool usedManual;
  final bool fellBackToBlend;
  final bool salaryWindowEmpty;

  const ExpectedIncomeResult({
    required this.expectedIncome,
    required this.effectiveMode,
    this.usedManual = false,
    this.fellBackToBlend = false,
    this.salaryWindowEmpty = false,
  });
}

/// Computes effective expected monthly income given mode + manual and transactions.
ExpectedIncomeResult computeExpectedIncome({
  required List<dynamic> allTx,
  required String uid,
  required IncomeMode mode,
  required double manualMonthly,
}) {
  final manualSet = manualMonthly > 0.0 && manualMonthly.isFinite;

  // Manual mode takes precedence if set.
  if (mode == IncomeMode.manual) {
    if (manualSet) {
      return ExpectedIncomeResult(
        expectedIncome: manualMonthly,
        effectiveMode: IncomeMode.manual,
        usedManual: true,
        fellBackToBlend: false,
        salaryWindowEmpty: false,
      );
    }
    // Manual requested but not set → fallback to Auto – Blend
    // Compute blend.
  }

  if (mode == IncomeMode.manual && !manualSet) {
    // fallback to blend
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    final incomeCutoff = now.subtract(const Duration(days: 90));
    double thisMonthIncome = 0;
    double last3mIncome = 0;
    for (final tx in allTx) {
      if (tx.recipientId != uid) continue;
      final amt = tx.amount.abs();
      final d = tx.date as DateTime;
      if (d.year == year && d.month == month) {
        thisMonthIncome += amt;
      }
      if (d.isAfter(incomeCutoff)) {
        last3mIncome += amt;
      }
    }
    final avg3m = last3mIncome / 3.0;
    final expected = thisMonthIncome > avg3m ? thisMonthIncome : avg3m;
    return ExpectedIncomeResult(
      expectedIncome: expected,
      effectiveMode: IncomeMode.autoBlend,
      usedManual: false,
      fellBackToBlend: true,
      salaryWindowEmpty: false,
    );
  }

  if (mode == IncomeMode.autoSalaryWindow) {
    final w = sumIncomeInSalaryWindowThisMonth(allTx, uid);
    if (w > 0) {
      return ExpectedIncomeResult(
        expectedIncome: w,
        effectiveMode: IncomeMode.autoSalaryWindow,
        usedManual: false,
        fellBackToBlend: false,
        salaryWindowEmpty: false,
      );
    } else {
      return ExpectedIncomeResult(
        expectedIncome: 0.0,
        effectiveMode: IncomeMode.autoSalaryWindow,
        usedManual: false,
        fellBackToBlend: false,
        salaryWindowEmpty: true,
      );
    }
  }

  // Auto – Blend (default)
  {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    final incomeCutoff = now.subtract(const Duration(days: 90));
    double thisMonthIncome = 0;
    double last3mIncome = 0;
    for (final tx in allTx) {
      if (tx.recipientId != uid) continue;
      final amt = tx.amount.abs();
      final d = tx.date as DateTime;
      if (d.year == year && d.month == month) {
        thisMonthIncome += amt;
      }
      if (d.isAfter(incomeCutoff)) {
        last3mIncome += amt;
      }
    }
    final avg3m = last3mIncome / 3.0;
    final expected = thisMonthIncome > avg3m ? thisMonthIncome : avg3m;
    return ExpectedIncomeResult(
      expectedIncome: expected,
      effectiveMode: IncomeMode.autoBlend,
      usedManual: false,
      fellBackToBlend: false,
      salaryWindowEmpty: false,
    );
  }
}

/// Result of an income-based daily spending limit.
///
/// The limit answers "how much can I spend per day, on top of fixed bills, so I
/// stay under my income and still save?". Fixed/committed spend is subtracted
/// up-front, so [dailyLimit] only governs discretionary spending.
class DailyLimit {
  /// Expected income for the month (e.g. 3-month average).
  final double expectedIncome;

  /// Income set aside for savings before any spending.
  final double savingsReserved;

  /// Full-month committed spend (rent/EMI/bills) forecast.
  final double fixedForecast;

  /// Discretionary spend already recorded this month.
  final double variableSpent;

  /// Income left after savings + fixed — the pot discretionary spend may use.
  final double disposableBudget;

  /// [disposableBudget] minus what's already been spent (never negative).
  final double remainingVariable;

  /// Days left in the month, today included.
  final int remainingDays;

  /// Suggested discretionary spend per remaining day (never negative).
  final double dailyLimit;

  const DailyLimit({
    required this.expectedIncome,
    required this.savingsReserved,
    required this.fixedForecast,
    required this.variableSpent,
    required this.disposableBudget,
    required this.remainingVariable,
    required this.remainingDays,
    required this.dailyLimit,
  });
}

/// Computes an income-aware daily spending limit.
///
/// [expectedIncome] is the month's projected income; [savingsRate] (0–1) is the
/// share reserved for savings. [fixedForecast] is the month's committed spend,
/// [variableSpent] what has already been spent on discretionary items, and
/// [remainingDays] the days left (today included, minimum 1). Every result is
/// clamped so an overspent or negative input can never report phantom budget.
DailyLimit computeDailyLimit({
  required double expectedIncome,
  required double fixedForecast,
  required double variableSpent,
  required int remainingDays,
  double savingsRate = kDefaultSavingsRate,
}) {
  final income = expectedIncome > 0 ? expectedIncome : 0.0;
  final rate = savingsRate.clamp(0.0, 1.0);
  final fixed = fixedForecast > 0 ? fixedForecast : 0.0;
  final spent = variableSpent > 0 ? variableSpent : 0.0;
  final days = remainingDays < 1 ? 1 : remainingDays;

  final savingsReserved = income * rate;
  final disposableBudget = math.max(0.0, income - savingsReserved - fixed);
  final remainingVariable = math.max(0.0, disposableBudget - spent);
  final dailyLimit = remainingVariable / days;

  return DailyLimit(
    expectedIncome: income,
    savingsReserved: savingsReserved,
    fixedForecast: fixed,
    variableSpent: spent,
    disposableBudget: disposableBudget,
    remainingVariable: remainingVariable,
    remainingDays: days,
    dailyLimit: dailyLimit,
  );
}

/// Rounds a percentage [percent] (e.g. 1.3361) **up** to [decimals] places and
/// trims trailing zeros. Takes the percent itself — it does NOT multiply by 100
/// (the caller passes `ratio * 100`). 0.5643 -> "0.57", 1.3361 -> "1.34",
/// 0.56 -> "0.56", 50.0 -> "50", 0 -> "0".
///
/// With [capBelowHundred], a value that would round up to 100 is clamped to
/// 99.99 so an incomplete goal never reads as 100% (the per-goal card shows a
/// separate "Done!" state on completion).
String formatPercent(
  double percent, {
  int decimals = 2,
  bool capBelowHundred = false,
}) {
  if (!percent.isFinite || percent <= 0) return '0';
  final scale = math.pow(10, decimals).toDouble();
  // Epsilon nudge so an exact value (e.g. 50.0) isn't pushed a step up by
  // floating-point representation error before ceil().
  var roundedUp = (percent * scale - 1e-9).ceil() / scale;
  if (capBelowHundred && roundedUp >= 100) roundedUp = 100 - 1 / scale;
  return NumberFormat('#,##0.##').format(roundedUp);
}
