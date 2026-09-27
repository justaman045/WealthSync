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
