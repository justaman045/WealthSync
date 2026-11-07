/// The single source of truth for every number on AI Insights.
///
/// One function reads transactions, categories, recurring payments and income
/// settings and returns an immutable [MonthInsights]. The screen, the forecast
/// card, the daily-limit card and the bills sheet all render from this one
/// object, so no two surfaces can disagree about spend, forecast or remaining.
///
/// Invariants (pinned by test/insights_math_test.dart):
///   - forecastTotal == committedBills + variableForecast
///   - remaining == max(0, forecastTotal - (variableSpentMtd + fixedSpentMtd))
///   - savingsReserved == income * rate whenever income > 0
///   - future-dated expense counts as scheduled, never as spent
///   - ignored spend is excluded from every total and surfaced separately
library;

import 'dart:math' as math;

import 'package:money_control/Models/cateogary.dart';
import 'package:money_control/Models/recurring_payment_model.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Utils/bills_math.dart';
import 'package:money_control/Utils/wealth_math.dart';

/// Lowercased, trimmed aggregation key. Transactions store whatever casing the
/// user typed (emi / EMI / Emi); this normalises them so all three aggregate
/// onto one key.
String categoryKey(String? category) {
  final name = category?.trim();
  if (name == null || name.isEmpty) return __kUncategorizedCategory;
  return name.toLowerCase();
}

const String __kUncategorizedCategory = '__uncategorized__';

/// Title-cases a category name for display, preserving short all-caps tokens so
/// every spelling of the same word converges on one canonical form:
///   emi / EMI / Emi → EMI
///   sip / SIP / Sip → SIP
///   credit card bill → Credit Card Bill
String categoryDisplay(String key) {
  if (key.isEmpty || key == __kUncategorizedCategory) return 'Uncategorized';
  return titleCaseCategory(key);
}

/// Every derived figure the AI Insights screen shows, computed once per pass.
class MonthInsights {
  /// Expected monthly income for this account's income mode.
  final double income;

  /// Savings reserved against income (income × savings rate).
  final double savingsReserved;

  /// Fixed-role categories committed in full, plus unpaid recurring
  /// commitments in discretionary categories.
  final double committedBills;

  /// Variable-role spend recorded this month so far (past + today).
  final double variableSpentMtd;

  /// Variable-role spend recorded before today.
  final double variableSpentBeforeToday;

  /// Variable-role spend recorded today.
  final double todayVariableSpent;

  /// Number of variable-role transactions this month (for the Other Items card).
  final int currentVariableTxCount;

  /// Fixed-role spend recorded this month so far.
  final double fixedSpentMtd;

  /// Ignored-role spend recorded this month so far (excluded everywhere).
  final double ignoredSpentMtd;

  /// Future-dated expense transactions due this month but not yet spent.
  final double scheduledFuture;

  /// Projected discretionary spend for the full month.
  final double variableForecast;

  /// Projected total outflow: committed + variable forecast.
  final double forecastTotal;

  /// What is left of the forecast after spend so far, floored at zero.
  final double remaining;

  /// Full-history weighted average monthly total (ignored excluded).
  final double usualMonthAvg;

  /// One row per canonical category key, sorted by planned amount desc.
  final List<CategoryInsight> categories;

  /// Discretionary spend per day over the history window.
  final double typicalDailySpend;

  /// Per-day spending for this month, keyed by DateTime(year, month, day).
  final Map<DateTime, double> dailySpending;

  const MonthInsights({
    required this.income,
    required this.savingsReserved,
    required this.committedBills,
    required this.variableSpentMtd,
    required this.variableSpentBeforeToday,
    required this.todayVariableSpent,
    required this.currentVariableTxCount,
    required this.fixedSpentMtd,
    required this.ignoredSpentMtd,
    required this.scheduledFuture,
    required this.variableForecast,
    required this.forecastTotal,
    required this.remaining,
    required this.usualMonthAvg,
    required this.categories,
    required this.typicalDailySpend,
    required this.dailySpending,
  });

  MonthInsights copyWith({
    double? income,
    double? savingsReserved,
    double? committedBills,
    double? variableSpentMtd,
    double? variableSpentBeforeToday,
    double? todayVariableSpent,
    int? currentVariableTxCount,
    double? fixedSpentMtd,
    double? ignoredSpentMtd,
    double? scheduledFuture,
    double? variableForecast,
    double? forecastTotal,
    double? remaining,
    double? usualMonthAvg,
    List<CategoryInsight>? categories,
    double? typicalDailySpend,
    Map<DateTime, double>? dailySpending,
  }) {
    return MonthInsights(
      income: income ?? this.income,
      savingsReserved: savingsReserved ?? this.savingsReserved,
      committedBills: committedBills ?? this.committedBills,
      variableSpentMtd: variableSpentMtd ?? this.variableSpentMtd,
      variableSpentBeforeToday:
          variableSpentBeforeToday ?? this.variableSpentBeforeToday,
      todayVariableSpent: todayVariableSpent ?? this.todayVariableSpent,
      currentVariableTxCount:
          currentVariableTxCount ?? this.currentVariableTxCount,
      fixedSpentMtd: fixedSpentMtd ?? this.fixedSpentMtd,
      ignoredSpentMtd: ignoredSpentMtd ?? this.ignoredSpentMtd,
      scheduledFuture: scheduledFuture ?? this.scheduledFuture,
      variableForecast: variableForecast ?? this.variableForecast,
      forecastTotal: forecastTotal ?? this.forecastTotal,
      remaining: remaining ?? this.remaining,
      usualMonthAvg: usualMonthAvg ?? this.usualMonthAvg,
      categories: categories ?? this.categories,
      typicalDailySpend: typicalDailySpend ?? this.typicalDailySpend,
      dailySpending: dailySpending ?? this.dailySpending,
    );
  }

  /// Total spend recorded this month across every category (for the heatmap).
  double get spentTotalMtd =>
      variableSpentMtd + fixedSpentMtd + ignoredSpentMtd;

  /// Disposable income left after savings and committed bills.
  double get disposableBudget =>
      math.max(0.0, income - savingsReserved - committedBills);
}

/// One category's card on AI Insights.
class CategoryInsight {
  final String key;
  final String displayName;
  final double autoAmount;
  final double overrideAmount;
  final double recurringDue;
  final double spentThisMonth;
  final DailyLimitRole role;
  final double plan;
  final double committed;
  final double remaining;
  final DateTime? dueDate;
  final bool isLiability;
  final bool isPaid;
  final bool isUnpaid;
  final bool isDuplicateSuspicion;
  final double prevMonthTotal;
  final double trendPercent;
  final String message;

  const CategoryInsight({
    required this.key,
    required this.displayName,
    required this.autoAmount,
    required this.overrideAmount,
    required this.recurringDue,
    required this.spentThisMonth,
    required this.role,
    required this.plan,
    required this.committed,
    required this.remaining,
    this.dueDate,
    this.isLiability = false,
    this.isPaid = false,
    this.isUnpaid = false,
    this.isDuplicateSuspicion = false,
    required this.prevMonthTotal,
    required this.trendPercent,
    this.message = '',
  });

  CategoryInsight copyWith({
    String? key,
    String? displayName,
    double? autoAmount,
    double? overrideAmount,
    double? recurringDue,
    double? spentThisMonth,
    DailyLimitRole? role,
    double? plan,
    double? committed,
    double? remaining,
    DateTime? dueDate,
    bool? isLiability,
    bool? isPaid,
    bool? isUnpaid,
    bool? isDuplicateSuspicion,
    double? prevMonthTotal,
    double? trendPercent,
    String? message,
  }) {
    return CategoryInsight(
      key: key ?? this.key,
      displayName: displayName ?? this.displayName,
      autoAmount: autoAmount ?? this.autoAmount,
      overrideAmount: overrideAmount ?? this.overrideAmount,
      recurringDue: recurringDue ?? this.recurringDue,
      spentThisMonth: spentThisMonth ?? this.spentThisMonth,
      role: role ?? this.role,
      plan: plan ?? this.plan,
      committed: committed ?? this.committed,
      remaining: remaining ?? this.remaining,
      dueDate: dueDate ?? this.dueDate,
      isLiability: isLiability ?? this.isLiability,
      isPaid: isPaid ?? this.isPaid,
      isUnpaid: isUnpaid ?? this.isUnpaid,
      isDuplicateSuspicion:
          isDuplicateSuspicion ?? this.isDuplicateSuspicion,
      prevMonthTotal: prevMonthTotal ?? this.prevMonthTotal,
      trendPercent: trendPercent ?? this.trendPercent,
      message: message ?? this.message,
    );
  }
}

/// Aggregate two or more active recurring payments that look identical so the
/// bills sheet can surface them without deleting anything financial.
class DuplicateRecurringSuspicion {
  /// Category key the duplicate belongs to.
  final String categoryKey;

  /// Human-readable category name for the notice.
  final String categoryDisplayName;

  /// Number of payments that participate in the duplicate group.
  final int count;

  /// Total monthly-equivalent amount across the group.
  final double totalMonthlyEquivalent;

  const DuplicateRecurringSuspicion({
    required this.categoryKey,
    required this.categoryDisplayName,
    required this.count,
    required this.totalMonthlyEquivalent,
  });
}

/// Reads transactions, categories, recurring payments and income settings and
/// returns the complete model every AI Insights surface renders from.
///
/// [now] is injectable so tests can freeze "today"; it defaults to the wall
/// clock. [incomeMode] and [manualIncome] come from [IncomeSettings]; [savingsRate]
/// from [SavingsSettings].
MonthInsights buildMonthInsights({
  required List<TransactionModel> transactions,
  required List<CategoryModel> categories,
  required List<RecurringPayment> recurring,
  required String uid,
  required IncomeMode incomeMode,
  required double manualIncome,
  double savingsRate = 0.2,
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final currentKey = ref.year * 100 + ref.month;
  final daysInMonth = DateTime(ref.year, ref.month + 1, 0).day;
  final daysPassed = ref.day;

  final treatmentOverrides = buildTreatmentOverrides(categories);
  final fixedAmountOverrides = buildFixedAmountOverrides(categories);

  // ------------------------------------------------------
  // 1. Income — derived once, shared by every card.
  // ------------------------------------------------------
  final incomeResult = computeExpectedIncome(
    allTx: transactions.cast<dynamic>(),
    uid: uid,
    mode: incomeMode,
    manualMonthly: manualIncome,
    now: ref,
  );
  final income = incomeResult.expectedIncome;
  final rate = savingsRate.clamp(0.0, 1.0);
  final savingsReserved = income > 0 ? income * rate : 0.0;

  // ------------------------------------------------------
  // 2. Organise transactions by category key.
  // ------------------------------------------------------
  // categoryMonthly: categoryKey -> monthKey -> total
  final categoryMonthly = <String, Map<int, double>>{};
  final monthlyTotal = <int, double>{}; // ignored excluded
  final monthlyVariable = <int, double>{};

  double currentVar = 0;
  double currentVarBeforeToday = 0;
  double currentVarToday = 0;
  int currentVariableTxCount = 0;
  double currentFixed = 0;
  double currentIgnored = 0;
  double scheduledFuture = 0;
  final dailySpending = <DateTime, double>{};

  final historyFloor = monthKeyFloor(ref);
  final todayKey = DateTime(ref.year, ref.month, ref.day);

  for (final tx in transactions) {
    final d = tx.date;
    if (d.isBefore(historyFloor)) continue;

    final monthKey = d.year * 100 + d.month;
    final key = categoryKey(tx.category);
    final role = resolveDailyLimitRole(
      key,
      treatmentOverrides: treatmentOverrides,
    );
    final absAmt = tx.amount.abs();

    // Future-dated rows are scheduled spending, not history.
    final isFuture = d.isAfter(ref) || d.isAtSameMomentAs(ref);
    if (monthKey == currentKey && isFuture) {
      scheduledFuture += absAmt;
      continue;
    }

    categoryMonthly.putIfAbsent(key, () => {});
    categoryMonthly[key]![monthKey] =
        (categoryMonthly[key]![monthKey] ?? 0) + absAmt;

    if (role != DailyLimitRole.ignored) {
      monthlyTotal[monthKey] = (monthlyTotal[monthKey] ?? 0) + absAmt;
    }
    if (role == DailyLimitRole.variable) {
      monthlyVariable[monthKey] = (monthlyVariable[monthKey] ?? 0) + absAmt;
    }

    if (monthKey == currentKey) {
      final dayKey = DateTime(d.year, d.month, d.day);
      dailySpending[dayKey] = (dailySpending[dayKey] ?? 0) + absAmt;

      switch (role) {
        case DailyLimitRole.variable:
          currentVar += absAmt;
          currentVariableTxCount++;
          if (d.isBefore(todayKey)) {
            currentVarBeforeToday += absAmt;
          } else {
            currentVarToday += absAmt;
          }
        case DailyLimitRole.fixed:
          currentFixed += absAmt;
        case DailyLimitRole.ignored:
          currentIgnored += absAmt;
      }
    }
  }

  // ------------------------------------------------------
  // 3. Historical months (excluding current).
  // ------------------------------------------------------
  final pastMonthKeys = monthlyTotal.keys
      .where((k) => k != currentKey)
      .toList()
    ..sort((a, b) => b.compareTo(a));

  double historicalVarMonthly = 0;
  if (pastMonthKeys.isNotEmpty) {
    double wSum = 0, wTotal = 0;
    for (var i = 0; i < pastMonthKeys.length; i++) {
      final w = (pastMonthKeys.length - i).toDouble();
      wSum += (monthlyVariable[pastMonthKeys[i]] ?? 0) * w;
      wTotal += w;
    }
    historicalVarMonthly = wTotal > 0 ? wSum / wTotal : 0;
  }

  // ------------------------------------------------------
  // 4. Variable forecast (progress-based blend).
  // ------------------------------------------------------
  final varProgress = daysPassed / daysInMonth;
  final varHistWeight = (1.0 - varProgress * 0.8).clamp(0.2, 1.0);
  final varCurrWeight = 1.0 - varHistWeight;

  final double currentVarPaced =
      daysPassed > 0 ? (currentVar / daysPassed) * daysInMonth : currentVar;

  double variableForecast;
  if (historicalVarMonthly > 0) {
    variableForecast =
        historicalVarMonthly * varHistWeight + currentVarPaced * varCurrWeight;
  } else {
    variableForecast = currentVarPaced > 0 ? currentVarPaced : currentVar;
  }
  // Never forecast less than what has already been spent — built in.
  variableForecast = math.max(variableForecast, currentVar);

  // ------------------------------------------------------
  // 5. Bills — one row per canonical category key.
  // ------------------------------------------------------
  final recurringPayments = recurring.where((p) => p.isActive).toList();
  final dueByCategory = recurringDueByCategory(recurringPayments, now: ref);

  // Preferred display name per key: category doc name wins, then recurring
  // payment name, then the raw transaction key.
  final preferredName = <String, String>{};
  for (final c in categories) {
    final k = c.name.trim().toLowerCase();
    if (k.isNotEmpty) preferredName.putIfAbsent(k, () => c.name.trim());
  }
  for (final p in recurringPayments) {
    final k = p.category.trim().toLowerCase();
    if (k.isNotEmpty) preferredName.putIfAbsent(k, () => p.category.trim());
  }
  for (final key in categoryMonthly.keys) {
    preferredName.putIfAbsent(key, () => key);
  }

  final allKeys = <String>{...categoryMonthly.keys};
  for (final p in recurringPayments) {
    final k = p.category.trim().toLowerCase();
    if (k.isNotEmpty) allKeys.add(k);
  }

  final billInsights = <CategoryInsight>[];
  for (final key in allKeys.toList()) {
    final months = categoryMonthly[key] ?? const <int, double>{};
    final history = <double>[];
    final floorKey = historyFloor.year * 100 + historyFloor.month;
    for (final entry in months.entries) {
      if (entry.key >= floorKey && entry.key < currentKey) {
        history.add(entry.value);
      }
    }
    final auto = billMonthlyAverage(history);
    final spent = months[currentKey] ?? 0;
    final override = fixedAmountOverrides[key] ?? 0;
    final role = resolveDailyLimitRole(
      key,
      treatmentOverrides: treatmentOverrides,
    );
    final due = dueByCategory[key];
    final recurringDue = due?.amount ?? 0;
    final plan = override > 0
        ? override
        : math.max(auto, math.max(recurringDue, spent));
    final committed = role == DailyLimitRole.ignored
        ? 0.0
        : role == DailyLimitRole.fixed
            ? math.max(plan, spent)
            : math.max(0.0, recurringDue - spent);
    final isPaid = plan > 0 && spent >= plan * kBillPaidFraction;
    final isUnpaid = plan > 0 && !isPaid;

    billInsights.add(
      CategoryInsight(
        key: key,
        displayName: categoryDisplay(key),
        autoAmount: auto,
        overrideAmount: override,
        recurringDue: recurringDue,
        spentThisMonth: spent,
        role: role,
        plan: plan,
        committed: committed,
        remaining: math.max(0.0, plan - spent),
        dueDate: due?.date,
        isLiability: due?.isLiability ?? false,
        isPaid: isPaid,
        isUnpaid: isUnpaid,
        prevMonthTotal: 0,
        trendPercent: 0,
      ),
    );
  }

  // Sort by plan desc, then name asc.
  billInsights.sort(
    (a, b) => b.plan.compareTo(a.plan) != 0
        ? b.plan.compareTo(a.plan)
        : a.displayName.compareTo(b.displayName),
  );

  // Previous month + trend per category.
  for (final insight in billInsights) {
    final months = categoryMonthly[insight.key] ?? const <int, double>{};
    double lastMonth = 0;
    for (final k in pastMonthKeys) {
      final v = months[k] ?? 0;
      if (v > 0) {
        lastMonth = v;
        break;
      }
    }
    final trend = lastMonth > 0
        ? ((insight.plan - lastMonth) / lastMonth * 100)
        : 0.0;
    final idx = billInsights.indexOf(insight);
    billInsights[idx] = insight.copyWith(
      prevMonthTotal: lastMonth,
      trendPercent: trend,
    );
  }

  final committedBills = billInsights.fold<double>(
      0, (sum, b) => sum + b.committed);

  final forecastTotal = committedBills + variableForecast;
  final remaining = math.max(
      0.0, forecastTotal - (currentVar + currentFixed));

  // ------------------------------------------------------
  // 6. Usual month average.
  // ------------------------------------------------------
  double usualMonthAvg = 0;
  if (pastMonthKeys.isNotEmpty) {
    double wSum = 0, wTotal = 0;
    for (var i = 0; i < pastMonthKeys.length; i++) {
      final w = (pastMonthKeys.length - i).toDouble();
      wSum += (monthlyTotal[pastMonthKeys[i]] ?? 0) * w;
      wTotal += w;
    }
    usualMonthAvg = wTotal > 0 ? wSum / wTotal : 0;
  }
  if (usualMonthAvg == 0 && daysPassed > 0) {
    usualMonthAvg = (currentVar / daysPassed) * daysInMonth;
  }

  // ------------------------------------------------------
  // 7. Typical daily spend.
  // ------------------------------------------------------
  final typicalDailySpend = historicalVarMonthly > 0
      ? historicalVarMonthly / daysInMonth
      : (daysPassed > 0 ? currentVar / daysPassed : 0.0);

  return MonthInsights(
    income: income,
    savingsReserved: savingsReserved,
    committedBills: committedBills,
    variableSpentMtd: currentVar,
    variableSpentBeforeToday: currentVarBeforeToday,
    todayVariableSpent: currentVarToday,
    currentVariableTxCount: currentVariableTxCount,
    fixedSpentMtd: currentFixed,
    ignoredSpentMtd: currentIgnored,
    scheduledFuture: scheduledFuture,
    variableForecast: variableForecast,
    forecastTotal: forecastTotal,
    remaining: remaining,
    usualMonthAvg: usualMonthAvg,
    categories: billInsights,
    typicalDailySpend: typicalDailySpend,
    dailySpending: dailySpending,
  );
}

/// Duplicate recurring payments that look identical: same category key,
/// same amount, same frequency, same due date.
List<DuplicateRecurringSuspicion> duplicateRecurringPayments(
  Iterable<RecurringPayment> payments,
) {
  final groups = <String, List<RecurringPayment>>{};
  for (final p in payments) {
    if (!p.isActive) continue;
    final key = '${p.category.trim().toLowerCase()}|'
        '${p.amount.toStringAsFixed(2)}|'
        '${p.frequency.index}|'
        '${DateTime(p.nextDueDate.year, p.nextDueDate.month, p.nextDueDate.day)}';
    groups.putIfAbsent(key, () => []).add(p);
  }

  final suspicions = <DuplicateRecurringSuspicion>[];
  for (final entry in groups.entries) {
    final list = entry.value;
    if (list.length < 2) continue;
    final categoryKey = list.first.category.trim().toLowerCase();
    suspicions.add(
      DuplicateRecurringSuspicion(
        categoryKey: categoryKey,
        categoryDisplayName: categoryDisplay(categoryKey),
        count: list.length,
        totalMonthlyEquivalent:
            list.fold<double>(0, (s, p) => s + p.monthlyEquivalent),
      ),
    );
  }
  suspicions.sort((a, b) => a.categoryDisplayName.compareTo(b.categoryDisplayName));
  return suspicions;
}
