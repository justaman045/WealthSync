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

/// Geo baselines are city-average incomes captured before the current
/// planning year; fold in an inflation factor so a 2026 plan is not sized off
/// pre-2025 averages (an 18K/mo baseline from an old table reads as realistic
/// in 2026 when it is not).
const double geoIncomeInflationFactor = 1.25;

/// Resolves the monthly income a wealth plan should be sized against.
///
/// Real transaction income (when the user has any in the window) always wins -
/// it is the most personal signal we have. Otherwise the geo location baseline
/// (city average) is used, adjusted for planning-year inflation.
double resolvePlanningMonthlyIncome({
  required double? transactionIncomeMonthly,
  required double geoBaselineMonthly,
}) {
  final real = transactionIncomeMonthly ?? 0;
  if (real > 0) return real;
  return geoBaselineMonthly * geoIncomeInflationFactor;
}

/// Emergency-fund months by age: <30 -> 3, >50 -> 12, else 6.
///
/// Single source of truth so the service, the screen and any future caller
/// classify an age the same way (no drifted copies).
int emergencyFundMonths(int age) => age < 30 ? 3 : age > 50 ? 12 : 6;

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

/// A committed bill counts as paid once this share of its usual amount has
/// been recorded. The forecast and the per-category insight both use it: they
/// diverged (0.95 vs 0.90), so a bill at 92% of its usual amount read as "paid"
/// on one card and "partially paid" on the other.
const double kBillPaidFraction = 0.95;

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

/// Completed months (plus the current, partial one) the blend averages over.
const int kIncomeBlendMonths = 3;

/// Months of spending history the forecast and insights may use. Anything
/// older is noise — spending patterns from years ago distort this month's
/// forecast — and the scan cost grows without bound.
const int kInsightHistoryMonths = 12;

/// First day of the earliest month inside the [kInsightHistoryMonths] window
/// that ends with the month containing [now]. Transactions before it are
/// outside the history the forecast is allowed to learn from.
DateTime monthKeyFloor(DateTime now, {int months = kInsightHistoryMonths}) =>
    DateTime(now.year, now.month - (months - 1), 1);

/// Categories whose credits are money coming *back*, not money earned.
///
/// They reuse the fixed-expense keyword matcher so "Self Transfer" and
/// "Transfer" both match. These names are the ones this app's own SMS/CSV
/// importer writes, and a refund or a transfer between the user's own accounts
/// counted as income inflates the monthly expectation — and with it the daily
/// limit the user is told they can spend.
const List<String> kNonIncomeKeywords = [
  'refund',
  'cashback',
  'reversal',
  'transfer',
  'loan/emi', // a disbursement is a liability, not income
];

final Map<String, RegExp> _nonIncomeKeywordReCache = {};

/// Matches a non-income keyword and its inflections ("Transferred", "Refunded",
/// "Cashbacks"). Unlike [_fixedKeywordRe] this allows trailing letters: the
/// importer writes free-form categories, and `Transferred rental income` is
/// still a transfer. The leading boundary is kept so a keyword cannot fire in
/// the middle of an unrelated word.
RegExp _nonIncomeKeywordRe(String keyword) =>
    _nonIncomeKeywordReCache.putIfAbsent(
      keyword,
      () => RegExp('(^|[^a-z])${RegExp.escape(keyword)}[a-z]*([^a-z]|\$)'),
    );

/// True when [category] names a credit that is not new income.
bool isNonIncomeCategory(String? category) {
  if (category == null) return false;
  final c = category.toLowerCase().trim();
  if (c.isEmpty) return false;
  for (final keyword in kNonIncomeKeywords) {
    if (_nonIncomeKeywordRe(keyword).hasMatch(c)) return true;
  }
  return false;
}

/// A category is optional on transactions built from fixtures/maps, so read it
/// defensively: a missing field means "not excluded", never a crash.
String? _categoryOf(dynamic tx) {
  try {
    final value = (tx as dynamic).category;
    return value is String ? value : null;
  } catch (_) {
    return null;
  }
}

/// True when [tx] is income for [uid]: paid *to* them, positive, and not a
/// refund/transfer (see [isNonIncomeCategory]).
///
/// `recipientId == uid` alone is not enough — the app stores a refund or a
/// self-transfer with the same shape as a salary credit.
bool _isIncomeTx(dynamic tx, String uid) {
  if (tx.recipientId != uid) return false;
  final amount = tx.amount;
  if (amount is! num || amount <= 0) return false;
  return !isNonIncomeCategory(_categoryOf(tx));
}

double _incomeAmount(dynamic tx) {
  final amount = tx.amount;
  return amount is num ? amount.toDouble() : 0.0;
}

/// Income per calendar month, keyed by `year * 100 + month`, for the [months]
/// completed months before [now] plus the current (partial) month.
///
/// Calendar buckets, not a rolling 90-day window: a salary paid on the 1st
/// would otherwise fall out of the window mid-month purely because of today's
/// date.
Map<int, double> incomeByMonth(
  List<dynamic> allTx,
  String uid,
  DateTime now, {
  int months = kIncomeBlendMonths,
}) {
  final floor = DateTime(now.year, now.month - months, 1);
  final ceiling = DateTime(now.year, now.month + 1, 1);
  final buckets = <int, double>{};
  for (final tx in allTx) {
    if (!_isIncomeTx(tx, uid)) continue;
    final date = tx.date as DateTime;
    if (date.isBefore(floor) || !date.isBefore(ceiling)) continue;
    final key = date.year * 100 + date.month;
    buckets[key] = (buckets[key] ?? 0) + _incomeAmount(tx);
  }
  return buckets;
}

/// The blended monthly income: the better of this month so far and the average
/// of the months that actually recorded income.
///
/// The divisor is the number of months **with income**, not the window size. A
/// fixed `/ 3` turns a new user's single ₹30k salary into "₹10k expected", and
/// a month between jobs drags the daily limit down for three months after the
/// next salary arrives. An empty month is missing data, not a month of zero
/// earnings.
double blendedMonthlyIncome(
  List<dynamic> allTx,
  String uid, {
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final buckets = incomeByMonth(allTx, uid, ref);
  if (buckets.isEmpty) return 0;
  final total = buckets.values.fold<double>(0, (sum, value) => sum + value);
  final average = total / buckets.length;
  final current = buckets[ref.year * 100 + ref.month] ?? 0;
  return math.max(current, average);
}

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

/// Sum of income (paid to [uid]) in the union of:
/// - first week of current month (calendar days 1–7) AND/OR
/// - last working day of previous month (Mon–Fri).
/// Union sum; refunds/transfers are not income ([isNonIncomeCategory]) and
/// negative rows are never counted.
double sumIncomeInSalaryWindowThisMonth(
  List<dynamic> allTx,
  String uid, {
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final year = ref.year;
  final month = ref.month;
  final lwmPrev = lastWorkingDayOfPreviousMonth(ref);
  double sum = 0;

  for (final tx in allTx) {
    if (!_isIncomeTx(tx, uid)) continue;
    final tDate = tx.date as DateTime;

    final inFirstWeekCurrent = (tDate.year == year && tDate.month == month && tDate.day >= 1 && tDate.day <= 7);
    final isLwmPrev = (tDate.year == lwmPrev.year && tDate.month == lwmPrev.month && tDate.day == lwmPrev.day);
    if (inFirstWeekCurrent || isLwmPrev) {
      sum += _incomeAmount(tx);
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

/// Computes effective expected monthly income given mode + manual and
/// transactions.
///
/// [now] is injectable so callers and tests agree on "this month"; it defaults
/// to the wall clock.
ExpectedIncomeResult computeExpectedIncome({
  required List<dynamic> allTx,
  required String uid,
  required IncomeMode mode,
  required double manualMonthly,
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final manualSet = manualMonthly > 0.0 && manualMonthly.isFinite;

  // Manual mode takes precedence if set.
  if (mode == IncomeMode.manual && manualSet) {
    return ExpectedIncomeResult(
      expectedIncome: manualMonthly,
      effectiveMode: IncomeMode.manual,
      usedManual: true,
      fellBackToBlend: false,
      salaryWindowEmpty: false,
    );
  }

  // Manual requested but not set → fall back to Auto – Blend. The flag lets
  // the card explain that a chosen mode was not used.
  if (mode == IncomeMode.manual) {
    return ExpectedIncomeResult(
      expectedIncome: blendedMonthlyIncome(allTx, uid, now: ref),
      effectiveMode: IncomeMode.autoBlend,
      usedManual: false,
      fellBackToBlend: true,
      salaryWindowEmpty: false,
    );
  }

  if (mode == IncomeMode.autoSalaryWindow) {
    final window = sumIncomeInSalaryWindowThisMonth(allTx, uid, now: ref);
    if (window > 0) {
      return ExpectedIncomeResult(
        expectedIncome: window,
        effectiveMode: IncomeMode.autoSalaryWindow,
        usedManual: false,
        fellBackToBlend: false,
        salaryWindowEmpty: false,
      );
    }
    // The window is empty: the salary may be a day late, or this month's slip
    // has not been imported yet. Reporting 0 would hide the whole daily limit,
    // so fall back to the blend and keep the flag so the card can say why the
    // number is not the salary-window one.
    final fallback = blendedMonthlyIncome(allTx, uid, now: ref);
    return ExpectedIncomeResult(
      expectedIncome: fallback,
      effectiveMode: IncomeMode.autoSalaryWindow,
      usedManual: false,
      fellBackToBlend: fallback > 0,
      salaryWindowEmpty: true,
    );
  }

  // Auto – Blend (default)
  return ExpectedIncomeResult(
    expectedIncome: blendedMonthlyIncome(allTx, uid, now: ref),
    effectiveMode: IncomeMode.autoBlend,
    usedManual: false,
    fellBackToBlend: false,
    salaryWindowEmpty: false,
  );
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

/// The daily allowance split shown by the Smart Daily Limit card.
///
/// [computeDailyLimit] answers "how much may I spend per remaining day from
/// now?" after subtracting everything already spent, **including today**. That
/// is the right budget number, but comparing today's total spend against it is
/// apples-to-oranges: the divisor already counts today. This splits the same
/// budget into "what today may cost" ([todayAllowance]) and "what is left of
/// that" ([remainingToday]), so the card compares like with like.
class DailyAllowance {
  /// Income left after savings and committed bills, before any spending.
  final double disposableBudget;

  /// Discretionary spend recorded before today. Today's spend is deliberately
  /// excluded — it is what [todayAllowance] is meant to be compared against.
  final double spentBeforeToday;

  /// Days left in the month, today included.
  final int remainingDays;

  /// What today may cost: the budget left before today, spread over the
  /// remaining days.
  final double todayAllowance;

  /// Discretionary spend recorded today.
  final double todaySpent;

  /// What is still available today (never negative).
  final double remainingToday;

  const DailyAllowance({
    required this.disposableBudget,
    required this.spentBeforeToday,
    required this.remainingDays,
    required this.todayAllowance,
    required this.todaySpent,
    required this.remainingToday,
  });

  /// True when there is no discretionary money left for today.
  bool get isExhausted => todayAllowance <= 0 || remainingToday <= 0;
}

/// Splits this month's disposable budget into a per-day allowance for today.
///
/// [spentBeforeToday] must exclude today's transactions (otherwise today is
/// charged twice: once as spend and once as a day in [remainingDays]).
/// [todaySpent] is today's discretionary total. Every result is clamped so an
/// overspent month never reports a phantom allowance.
DailyAllowance computeDailyAllowance({
  required double expectedIncome,
  required double fixedForecast,
  required double spentBeforeToday,
  required double todaySpent,
  required int remainingDays,
  double savingsRate = kDefaultSavingsRate,
}) {
  final income = expectedIncome > 0 ? expectedIncome : 0.0;
  final rate = savingsRate.clamp(0.0, 1.0);
  final fixed = fixedForecast > 0 ? fixedForecast : 0.0;
  final before = spentBeforeToday > 0 ? spentBeforeToday : 0.0;
  final today = todaySpent > 0 ? todaySpent : 0.0;
  final days = remainingDays < 1 ? 1 : remainingDays;

  final savingsReserved = income * rate;
  final disposableBudget = math.max(0.0, income - savingsReserved - fixed);
  final remainingBeforeToday = math.max(0.0, disposableBudget - before);
  final todayAllowance = remainingBeforeToday / days;
  final remainingToday = math.max(0.0, todayAllowance - today);

  return DailyAllowance(
    disposableBudget: disposableBudget,
    spentBeforeToday: before,
    remainingDays: days,
    todayAllowance: todayAllowance,
    todaySpent: today,
    remainingToday: remainingToday,
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

/// Title-cases a category name for display: "groceries" → "Groceries",
/// "EMI" → "Emi", "credit card bill" → "Credit Card Bill".
/// Aggregation keys stay lowercased; only the display text is title-cased.
String titleCaseCategory(String? name) {
  if (name == null || name.isEmpty) return '';
  return name
      .trim()
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}
