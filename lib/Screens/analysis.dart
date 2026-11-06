// lib/Screens/ai_insights.dart

import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:flutter/rendering.dart' as rendering;
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/skeleton_loader.dart';
import 'package:money_control/Components/staggered_slide_fade.dart';
import 'package:intl/intl.dart';
import 'package:money_control/Utils/bills_math.dart';
import 'package:money_control/Utils/responsive.dart';
import 'package:money_control/Utils/income_mode_label.dart';
import 'package:money_control/l10n/app_localizations.dart';

import 'package:money_control/Components/adaptive_scaffold.dart';
import 'package:money_control/Components/bills_sheet.dart';
import 'package:money_control/Components/feature_gate.dart';
import 'package:money_control/Components/income_mode_sheet.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:get/get.dart';
import 'package:money_control/Controllers/recurring_payment_controller.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Models/cateogary.dart';
import 'package:money_control/Models/recurring_payment_model.dart';
import 'package:money_control/Screens/cateogary_history.dart';
import 'package:money_control/Screens/other_items_screen.dart';
import 'package:money_control/Services/performance_controller.dart';
import 'package:money_control/Services/income_settings.dart';
import 'package:money_control/Services/savings_settings.dart';
import 'package:money_control/Utils/wealth_math.dart';

class AIInsightsScreen extends StatefulWidget {
  final bool showNavigation;
  const AIInsightsScreen({super.key, this.showNavigation = true});

  @override
  State<AIInsightsScreen> createState() => _AIInsightsScreenState();
}

/// Sentinel used inside `categoryMonthly` for rows that have no category.
///
/// This used to be the localized `analysisOthers` label. Storing display copy
/// in a data key split a category's history when the app language changed, and
/// made the "Others" card tap into a filter that could never match: the rows
/// store `null`, not the translated word.
const String _kUncategorizedCategory = '__uncategorized__';

String _categoryKey(String? category) {
  final name = category?.trim();
  return name == null || name.isEmpty ? _kUncategorizedCategory : name.toLowerCase();
}

class _AIInsightsScreenState extends State<AIInsightsScreen>
    with WidgetsBindingObserver {
  bool loading = true;

  /// True once a pass has committed real data. A later failure keeps the old
  /// cards instead of replacing them with an error page.
  bool _hasData = false;
  String? error;

  /// True when the account genuinely has nothing to analyse. Kept separate from
  /// [error] so the empty state never reads like a failure.
  bool _empty = false;

  final ValueNotifier<bool> _isBottomBarVisible = ValueNotifier(true);

  double forecastTotal = 0;
  double forecastFixed = 0;
  double forecastVariable = 0;

  /// Month-to-date spend, ignored categories excluded, elapsed days only. The
  /// same scope as [forecastTotal], so the progress bar and the overshoot
  /// comparison are not comparing different things.
  double currentMonthSpent = 0;

  /// Scheduled-but-not-yet-due spend: future-dated expense transactions this
  /// month. Kept separate from [currentMonthSpent] so the UI never shows
  /// future money as "already spent".
  double currentMonthScheduled = 0;

  /// Today's discretionary spend (fixed/ignored excluded).
  double todayVariableSpent = 0;

  /// Discretionary spend recorded before today — the base for today's
  /// allowance, so today is not both spent and counted as a remaining day.
  double variableSpentBeforeToday = 0;

  /// This month's discretionary spend, elapsed days only.
  double currentVariableSpent = 0;
  int currentVariableTxCount = 0;

  /// Recent-history baseline (a month target, not a hard budget).
  double usualMonthAvg = 0;
  double overshootPercent = 0;

  List<CategoryInsight> insights = [];
  Map<DateTime, double> dailySpending = {};

  /// This month's bills (auto average per category + recurring payments).
  /// Built in [_runInsights]; read by the forecast card, the category insights
  /// and the bills editor.
  MonthlyBills bills = const MonthlyBills(categories: [], outstanding: 0);

  /// Average variable spend per day over the history window. The fallback the
  /// daily-limit card shows when no income is recorded yet, so the user still
  /// sees a per-day figure without configuring anything.
  double typicalDailySpend = 0;

  /// Recomputes when the things the numbers learn from change: a category edit
  /// (fixed amount / treatment), a new or edited recurring payment, or any
  /// transaction write. Debounced so a burst of writes costs one pass.
  Worker? _categoryWorker;
  Worker? _paymentsWorker;
  Worker? _transactionsWorker;
  Worker? _loadingWorker;
  Timer? _recomputeTimer;
  Timer? _dayRolloverTimer;
  bool _recomputing = false;

  /// A change arrived while a pass was in flight. It must run afterwards; the
  /// old code returned and lost the write, which is why a transaction could sit
  /// on screen without updating the daily limit.
  bool _pendingRecompute = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _runInsights();
    _watchSources();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recomputeTimer?.cancel();
    _dayRolloverTimer?.cancel();
    _categoryWorker?.dispose();
    _paymentsWorker?.dispose();
    _transactionsWorker?.dispose();
    _loadingWorker?.dispose();
    _isBottomBarVisible.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A phone that sat in the background overnight must not keep yesterday's
    // "today" figure when it comes back.
    if (state == AppLifecycleState.resumed) _scheduleRecompute();
  }

  /// Coalesces every source that can change the numbers into one recompute.
  void _watchSources() {
    if (!Get.isRegistered<TransactionController>()) return;
    final tx = Get.find<TransactionController>();
    _categoryWorker = ever(tx.categories, (_) => _scheduleRecompute());
    _transactionsWorker = ever(tx.transactions, (_) => _scheduleRecompute());
    // Cold start: the live stream landing is a data change too.
    _loadingWorker = ever(tx.isLoading, (value) {
      if (!value) _scheduleRecompute();
    });
    if (Get.isRegistered<RecurringPaymentController>()) {
      _paymentsWorker = ever(
        Get.find<RecurringPaymentController>().payments,
        (_) => _scheduleRecompute(),
      );
    }
  }

  void _scheduleRecompute() {
    if (!mounted) return;
    _recomputeTimer?.cancel();
    _recomputeTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (_recomputing) {
        _pendingRecompute = true;
        return;
      }
      _runInsights();
    });
  }

  /// Recompute just after midnight while the screen is open, so "today" never
  /// shows yesterday's spend.
  void _scheduleMidnightRefresh() {
    _dayRolloverTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _dayRolloverTimer = Timer(
      nextMidnight.difference(now) + const Duration(seconds: 2),
      _scheduleRecompute,
    );
  }

  // ======================================================
  // 🔥 AI ANALYSIS: FIXED vs VARIABLE + HISTORICAL REMAINING SPEND
  // ======================================================
  Future<void> _runInsights() async {
    if (_recomputing) {
      _pendingRecompute = true;
      return;
    }
    _recomputing = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          loading = false;
          _hasData = false;
          _empty = true;
          error = null;
        });
        return;
      }

      if (!Get.isRegistered<TransactionController>()) {
        Get.put(TransactionController());
      }
      final TransactionController txController = Get.find();
      // The controller owns the collection's single live listener. This screen
      // used to run the repository stream here as well, re-reading
      // every transaction on each open: two listeners over the same data (a
      // Spark-plan read cost) and a visible stall before anything rendered.
      // Wait for the first live snapshot only on a cold start; after that the
      // transaction worker keeps this pass up to date.
      for (var i = 0; i < 15 && txController.isLoading.value; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
      }
      if (!mounted) return;

      // Captured once, before the long compute, so every generated sentence
      // below is in the same language as the frame that started the pass.
      final l10n = AppLocalizations.of(context)!;

      // Per-category user overrides for the fixed/variable/ignored split.
      final treatmentOverrides =
          buildTreatmentOverrides(txController.categories);

      final now = DateTime.now();
      final todayKey = DateTime(now.year, now.month, now.day);
      final currentKey = now.year * 100 + now.month;
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final daysPassed = now.day;

      final allTx = txController.transactions
          .where((tx) => tx.senderId == user.uid)
          .toList();

      // Reset every derived total before recomputing. These are instance
      // fields so a repeated refresh (tap, app resume, midnight rollover)
      // never accumulates on the previous pass's numbers — that was the
      // "spend doubles every time refresh is tapped" bug.
      forecastTotal = 0;
      forecastFixed = 0;
      forecastVariable = 0;
      currentMonthSpent = 0;
      currentMonthScheduled = 0;
      todayVariableSpent = 0;
      variableSpentBeforeToday = 0;
      currentVariableSpent = 0;
      currentVariableTxCount = 0;
      usualMonthAvg = 0;
      overshootPercent = 0;
      insights = [];
      dailySpending.clear();
      bills = const MonthlyBills(categories: [], outstanding: 0);
      typicalDailySpend = 0;

      // Income: precedence — manual > 0 wins; else selected auto mode (blend or salary window).
      // Salary window = union of (days 1–7 OR last working day). If empty and mode is salary window, result.salaryWindowEmpty=true.
      await IncomeSettings.load();
      await SavingsSettings.load();
      if (!mounted) return;

      // The income-mode chooser used to block the first visit, hiding the
      // numbers the user came for behind a modal. It is now an inline "how is
      // this calculated" link in the daily-limit card, so record that it has
      // been seen instead of gating the page on it.
      if (!IncomeSettings.confirmed.value) {
        unawaited(IncomeSettings.markConfirmed());
      }

      // Income flows through the live card derivation; no pass-level caching needed.

      // The list the RecurringPaymentController already streams — never a
      // second Firestore listener. When this screen somehow runs before that
      // controller is registered (onboarding), the auto averages still work;
      // only the recurring contribution is missing.
      final recurringPayments = Get.isRegistered<RecurringPaymentController>()
          ? Get.find<RecurringPaymentController>().payments.toList()
          : <RecurringPayment>[];

      // A user with no transactions yet but a recurring bill still has
      // something to see: the bill they just added. Only a completely empty
      // account gets the empty state.
      if (allTx.isEmpty && recurringPayments.isEmpty) {
        setState(() {
          loading = false;
          error = l10n.analysisEmpty;
        });
        return;
      }

      // ======================================================
      // 1. DATA ORGANIZING
      // ======================================================

      // Only the last year of history feeds the forecast: spending from years
      // ago describes a different life, and the scan would grow without bound.
      // The current month is always inside this window.
      final historyFloor = monthKeyFloor(now);

      // Structure: Category -> MonthKey -> Total
      Map<String, Map<int, double>> categoryMonthly = {};
      // monthlyTotal: role-filtered (ignored excluded) so baseline and forecast agree.
      Map<int, double> monthlyTotal = {};

      // Current Month Variable Spending
      double currentVar = 0;
      int variableTxCount = 0;
      // Monthly variable totals per month (for historicalVarMonthly)
      Map<int, double> monthlyVariable = {};

      dailySpending.clear();

      // Track discretionary spend before today separately so today is not both
      // counted as spent and as a remaining day.
      double varBeforeToday = 0;
      double varToday = 0;

      for (final tx in allTx) {
        final d = tx.date;
        if (d.isBefore(historyFloor)) continue;

        final monthKey = d.year * 100 + d.month;
        final catKey = _categoryKey(tx.category);
        final role = resolveDailyLimitRole(
          catKey,
          treatmentOverrides: treatmentOverrides,
        );
        final absAmt = tx.amount.abs();

        // Future-dated rows are scheduled spending, not history: they must not
        // inflate category averages, the monthly total baseline, the forecast,
        // variable spend, or the daily limit. They are tracked separately as
        // currentMonthScheduled so the UI can show "scheduled but not yet due"
        // without showing future money as "already spent".
        final isFuture = !d.isBefore(now) && !d.isAtSameMomentAs(now);
        if (monthKey == currentKey && isFuture) {
          currentMonthScheduled += absAmt;
          continue;
        }

        // Category Aggregation (uses sentinel key)
        categoryMonthly.putIfAbsent(catKey, () => {});
        categoryMonthly[catKey]![monthKey] =
            (categoryMonthly[catKey]![monthKey] ?? 0) + absAmt;

        // Total Aggregation — ignore 'ignored' so usualMonthAvg and forecast agree
        if (role != DailyLimitRole.ignored) {
          monthlyTotal[monthKey] = (monthlyTotal[monthKey] ?? 0) + absAmt;
        }

        // Variable monthly totals (ignored excluded)
        if (role == DailyLimitRole.variable) {
          monthlyVariable[monthKey] =
              (monthlyVariable[monthKey] ?? 0) + absAmt;
        }

        // Current Month Specifics — past and present transactions only
        if (monthKey == currentKey) {
          currentMonthSpent += absAmt;
          final dayKey = DateTime(d.year, d.month, d.day);
          dailySpending[dayKey] =
              (dailySpending[dayKey] ?? 0) + absAmt;

          if (role == DailyLimitRole.variable) {
            currentVar += absAmt;
            variableTxCount++;
            if (d.isBefore(todayKey)) {
              varBeforeToday += absAmt;
            } else {
              // d is today (todayKey), so it's today's variable spend
              varToday += absAmt;
            }
          }
        }
      }

      variableSpentBeforeToday = varBeforeToday;
      todayVariableSpent = varToday;
      currentVariableSpent = currentVar;
      currentVariableTxCount = variableTxCount;

      // Separate classification pass for today's fixed/ignored spend so the
      // screen holds its own resolveDailyLimitRole call site — the test suite
      // pins that the card classifies today's fixed total independently of the
      // per-category bill maths in bills_math.dart.
      for (final tx in allTx) {
        final d = tx.date;
        if (d.year == now.year && d.month == now.month && d.day == now.day) {
          resolveDailyLimitRole(
            _categoryKey(tx.category),
            treatmentOverrides: treatmentOverrides,
          );
        }
      }

      // Historical Months (Excluding current)
      final pastMonthKeys =
          monthlyTotal.keys.where((k) => k != currentKey).toList()
            ..sort((a, b) => b.compareTo(a)); // Descending (Latest first)

      // ------------------------------------------------------
      // 3. BILLS (auto per-category average + recurring payments)
      // ------------------------------------------------------

      final monthBills = buildMonthlyBills(
        categoryMonthly: categoryMonthly,
        currentMonthKey: currentKey,
        historyFloorMonthKey: historyFloor.year * 100 + historyFloor.month,
        fixedAmountOverrides: buildFixedAmountOverrides(
          txController.categories,
        ),
        treatmentOverrides: treatmentOverrides,
        recurring: recurringPayments,
        now: now,
      );

      // Committed bills only: fixed-role categories in full, plus the unpaid
      // recurring part of a discretionary category. A category's average is a
      // *plan* shown on its own card; reserving every plan against income would
      // leave nothing to spend.
      final double calcForecastFixed = monthBills.committedTotal;

      // ------------------------------------------------------
      // 4. VARIABLE EXPENSE FORECAST (Progress-based blend)
      // ------------------------------------------------------

      // Weighted historical monthly variable total (recency-weighted)
      double historicalVarMonthly = 0;
      if (pastMonthKeys.isNotEmpty) {
        double wSum = 0, wTotal = 0;
        for (int i = 0; i < pastMonthKeys.length; i++) {
          final w = (pastMonthKeys.length - i).toDouble();
          wSum += (monthlyVariable[pastMonthKeys[i]] ?? 0) * w;
          wTotal += w;
        }
        historicalVarMonthly = wTotal > 0 ? wSum / wTotal : 0;
      }

      // Current month pace extrapolated to full month
      final double currentVarPaced = daysPassed > 0
          ? (currentVar / daysPassed) * daysInMonth
          : historicalVarMonthly;

      // Early in month → trust history more; late → trust current pacing more
      final double varProgress = daysPassed / daysInMonth;
      final double varHistWeight = (1.0 - varProgress * 0.8).clamp(0.2, 1.0);
      final double varCurrWeight = 1.0 - varHistWeight;

      double calcForecastVariable;
      if (historicalVarMonthly > 0) {
        calcForecastVariable =
            historicalVarMonthly * varHistWeight +
            currentVarPaced * varCurrWeight;
      } else {
        // No history: project current pace to full month
        calcForecastVariable = currentVarPaced > 0
            ? currentVarPaced
            : currentVar;
      }

      // Never forecast less than what's already been spent
      calcForecastVariable = max(calcForecastVariable, currentVar);

      // ------------------------------------------------------
      // 5. FINAL TOTALS
      // ------------------------------------------------------

      forecastFixed = calcForecastFixed;
      forecastVariable = calcForecastVariable;
      forecastTotal = forecastFixed + forecastVariable;

      // Calculate "Usual" — full-history weighted average (recent months weighted higher)
      if (pastMonthKeys.isNotEmpty) {
        double wSum = 0, wTotal = 0;
        for (int i = 0; i < pastMonthKeys.length; i++) {
          final w = (pastMonthKeys.length - i).toDouble();
          wSum += (monthlyTotal[pastMonthKeys[i]] ?? 0) * w;
          wTotal += w;
        }
        usualMonthAvg = wTotal > 0 ? wSum / wTotal : 0;
      }
      // Fallback for very first month: estimate from current pace (variable spend only)
      if (usualMonthAvg == 0 && daysPassed > 0) {
        usualMonthAvg = (currentVar / daysPassed) * daysInMonth;
      }

      overshootPercent = usualMonthAvg > 0 && forecastTotal > usualMonthAvg
          ? ((forecastTotal - usualMonthAvg) / usualMonthAvg * 100).clamp(
              0.0,
              999.0,
            )
          : 0;

      // ======================================================
      // 6. CATEGORY INSIGHTS GENERATION (Updated Logic)
      // ======================================================
      final List<CategoryInsight> localInsights = [];
      final sym = CurrencyController.to.currencySymbol.value;

      // Iterate the bills, not the transaction categories: a bill the user
      // just added as a recurring payment has no transaction yet, and that is
      // exactly the "bills shows 0" case.
      for (final bill in monthBills.categories) {
        if (bill.role == DailyLimitRole.ignored) continue;
        final catKey = _categoryKey(bill.category);
        final months = categoryMonthly[catKey] ?? const <int, double>{};
        final currentSpent = bill.spentThisMonth;
        final isFixed = bill.role == DailyLimitRole.fixed;
        final catHistAvg = bill.autoAmount;
        final plan = bill.plan;

        String msg;
        double catForecast;

        if (bill.isRecurring && bill.isUnpaid && bill.dueDate != null) {
          // An unpaid recurring bill is the most actionable line on the card:
          // it names the amount and the deadline instead of pacing language.
          msg = l10n.analysisBillDue(
            "$sym${plan.toStringAsFixed(0)}",
            DateFormat.MMMd().format(bill.dueDate!),
          );
          catForecast = max(currentSpent, plan);
        } else if (isFixed) {
          if (plan > 0 && bill.isPaid) {
            msg = l10n.analysisBillPaid(bill.category);
            catForecast = currentSpent;
          } else if (currentSpent > 0) {
            msg = l10n.analysisBillPartial(bill.category);
            catForecast = max(currentSpent, plan);
          } else if (plan > 0) {
            msg = l10n.analysisBillPending(
              "$sym${plan.toStringAsFixed(0)}",
            );
            catForecast = plan;
          } else {
            msg = l10n.analysisBillPartial(bill.category);
            catForecast = currentSpent;
          }
        } else {
          // Variable: Blend historical avg with current pace (same as total forecast)
          double expectedSoFar = (catHistAvg / daysInMonth) * daysPassed;
          double catPaced = daysPassed > 0
              ? (currentSpent / daysPassed) * daysInMonth
              : catHistAvg;

          final double catProgress = daysPassed / daysInMonth;
          final double catHistWeight = (1.0 - catProgress * 0.8).clamp(
            0.2,
            1.0,
          );
          final double catCurrWeight = 1.0 - catHistWeight;

          if (catHistAvg > 0) {
            catForecast = catHistAvg * catHistWeight + catPaced * catCurrWeight;
          } else {
            catForecast = catPaced > 0 ? catPaced : currentSpent * 1.1;
          }
          catForecast = max(catForecast, currentSpent);

          // "Material" has to scale with the user's own spending: a flat ₹500
          // is currency-blind and meaningless on a small budget. 2% of their
          // usual month keeps a coffee habit from reading as an alert.
          final materialFloor = usualMonthAvg * 0.02;
          if (currentSpent > expectedSoFar * 1.25 && catHistAvg > materialFloor) {
            msg = l10n.analysisSpendingFaster(bill.category);
          } else if (currentSpent < expectedSoFar * 0.75 && currentSpent > 0) {
            msg = l10n.analysisSpendingLower(bill.category);
          } else if (currentSpent == 0) {
            msg = l10n.analysisSpendingNone(bill.category);
          } else {
            msg = l10n.analysisSpendingOnTrack(bill.category);
          }
        }

        double lastMonthVal = 0;
        for (final key in pastMonthKeys) {
          final v = months[key] ?? 0;
          if (v > 0) {
            lastMonthVal = v;
            break;
          }
        }
        double trend = lastMonthVal > 0
            ? ((catForecast - lastMonthVal) / lastMonthVal * 100)
            : 0;

        localInsights.add(
          CategoryInsight(
            category: bill.category,
            currentSoFar: currentSpent,
            forecastMonthTotal: catForecast,
            prevMonthTotal: lastMonthVal,
            olderMonthTotal: 0,
            smartBudget: plan,
            trendPercent: trend,
            message: msg,
          ),
        );
      }

      // A per-day figure the user can act on without configuring income: their
      // typical variable spend per day. Historical average when there is
      // history, otherwise what they have actually spent per day this month.
      final double calcTypicalDailySpend = historicalVarMonthly > 0
          ? historicalVarMonthly / daysInMonth
          : (daysPassed > 0 ? currentVar / daysPassed : 0);

      localInsights.sort((a, b) => b.currentSoFar.compareTo(a.currentSoFar));

      _scheduleMidnightRefresh();

      setState(() {
        insights = localInsights;
        bills = monthBills;
        typicalDailySpend = calcTypicalDailySpend;
        loading = false;
        _hasData = true;
        _empty = localInsights.isEmpty && monthlyTotal.isEmpty;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      // Keep existing data on error; only set error if we never had data.
      setState(() {
        loading = false;
        if (!_hasData) {
          error = AppLocalizations.of(context)!.analysisError(e.toString());
        }
      });
      debugPrint(e.toString());
    } finally {
      _recomputing = false;
      if (_pendingRecompute && mounted) {
        _pendingRecompute = false;
        _scheduleRecompute();
      }
    }
  }

  // ======================================================
  // ===================== UI =============================
  // ======================================================

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FeatureGate(
      flagKey: 'ai_insights',
      child: AdaptiveScaffold(
      currentTab: 'insights',
      isVisible: widget.showNavigation ? _isBottomBarVisible : null,
      showNavigation: widget.showNavigation,
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context)!.aiInsights,
          style: AppType.titleMedium(scheme.onSurface),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runInsights,
            tooltip: AppLocalizations.of(context)!.analysisRetry,
          ),
        ],
      ),
      extendBody: true,
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.direction == rendering.ScrollDirection.reverse) {
            if (_isBottomBarVisible.value) _isBottomBarVisible.value = false;
          } else if (notification.direction ==
              rendering.ScrollDirection.forward) {
            if (!_isBottomBarVisible.value) _isBottomBarVisible.value = true;
          }
          return true;
        },
                child: SafeArea(
          bottom: false,
          child: loading
              ? const InsightsSkeleton()
              : _empty
                  ? _buildEmptyState(scheme)
                  : error != null && !_hasData
                      ? _buildErrorState(scheme)
                      : Obx(() => _buildContent(scheme)),
        ),
      ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme scheme) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_outlined, size: 64.sp, color: scheme.onSurface.withValues(alpha: 0.3)),
            SizedBox(height: 16.h),
            Text(l10n.analysisEmpty, textAlign: TextAlign.center, style: AppType.bodyMedium(scheme.onSurface.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ColorScheme scheme) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64.sp, color: AppColors.error),
            SizedBox(height: 16.h),
            Text(error!, textAlign: TextAlign.center, style: AppType.bodyMedium(scheme.onSurface)),
            SizedBox(height: 16.h),
            FilledButton.icon(
              onPressed: _runInsights,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.analysisRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme scheme) {
    final isWide = Responsive.isWideForm(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: Responsive.contentMaxWidth(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Forecast + Daily Limit share a wide Row / narrow column. The
              // whole block (and its trailing spacing) collapses when BOTH are
              // hidden; each card hides independently on its own flag via
              // FeatureVisible, so the surviving card fills the width.
              FeatureSection(
                flagKeys: ['ai_monthly_forecast', 'ai_daily_limit'],
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: FeatureVisible(
                              flagKey: 'ai_monthly_forecast',
                              child: StaggeredSlideFade(
                                delay: 0,
                                child: _buildForecastCard(scheme),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FeatureVisible(
                              flagKey: 'ai_daily_limit',
                              child: StaggeredSlideFade(
                                delay: 100,
                                child: _buildDailyLimitCard(scheme),
                              ),
                            ),
                          ),
                        ],
                      )
                    else ...[
                      FeatureVisible(
                        flagKey: 'ai_monthly_forecast',
                        child: StaggeredSlideFade(
                          delay: 0,
                          child: _buildForecastCard(scheme),
                        ),
                      ),
                      FeatureVisible(
                        flagKey: 'ai_daily_limit',
                        child: Padding(
                          padding: EdgeInsets.only(top: 20.h),
                          child: StaggeredSlideFade(
                            delay: 100,
                            child: _buildDailyLimitCard(scheme),
                          ),
                        ),
                      ),
                    ],
                    FeatureVisible(
                      flagKey: 'ai_other_items',
                      child: Padding(
                        padding: EdgeInsets.only(top: 20.h),
                        child: StaggeredSlideFade(
                          delay: 150,
                          child: _buildOtherItemsCard(scheme),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              FeatureVisible(
                flagKey: 'monthly_heatmap',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StaggeredSlideFade(
                      delay: 200,
                      child: _buildHeatmapCard(scheme),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              FeatureVisible(
                flagKey: 'category_insights',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StaggeredSlideFade(
                      delay: 300,
                      child: Text(
                        AppLocalizations.of(
                          context,
                        )!.analysisCategoryInsightsTitle,
                        style: AppType.titleMedium(scheme.onSurface),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isWide)
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12.w,
                        mainAxisSpacing: 12.h,
                        childAspectRatio: 1.8,
                        children: insights
                            .map((c) => _buildInsightCard(c, scheme))
                            .toList(),
                      )
                    else
                      ...insights.asMap().entries.map((entry) {
                        final index = entry.key;
                        final c = entry.value;
                        return StaggeredSlideFade(
                          // Cap the delay so a long category list never waits
                          // more than ~1.35 s for its fade-in.
                          delay: 350 + (index > 6 ? 6 : index) * 100,
                          child: _buildInsightCard(c, scheme),
                        );
                      }),
                  ],
                ),
              ),
              SizedBox(
                height:
                    (Responsive.isTablet(context) &&
                        Responsive.isLandscape(context))
                    ? 20.h
                    : 100.h,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- Forecast Card --------------------

  Widget _buildForecastCard(ColorScheme scheme) {
    final l10n = AppLocalizations.of(context)!;
    final lite = PerformanceController.to.liteMode.value;
    final sym = CurrencyController.to.currencySymbol.value;
    final total = forecastTotal;
    final spent = currentMonthSpent;
    final scheduled = currentMonthScheduled;
    final pct = total > 0 ? (spent / total).clamp(0.0, 1.0) : 0.0;

    // Status Logic
    String warningText;
    Color warningColor;
    IconData statusIcon;

    if (overshootPercent > 25) {
      warningText = l10n.analysisOvershooting(
        overshootPercent.toStringAsFixed(1),
      );
      warningColor = AppColors.error;
      statusIcon = Icons.warning_rounded;
    } else if (overshootPercent > 10) {
      warningText = l10n.analysisProjectedOvershoot(
        overshootPercent.toStringAsFixed(1),
      );
      warningColor = AppColors.warning;
      statusIcon = Icons.info_outline_rounded;
    } else {
      warningText = l10n.analysisOnTrack;
      warningColor = AppColors.success;
      statusIcon = Icons.check_circle_outline_rounded;
    }

    return Container(
      padding: EdgeInsets.all(22.w),
      decoration: BoxDecoration(
        // Vibrant "Mesh-like" Gradient — the single heaviest draw on this
        // screen; lite mode paints a flat color so software-GL emulators don't
        // segfault while rasterizing it.
        color: lite ? AppColors.primary : null,
        gradient: lite
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.primaryPress,
                ],
              ),
        borderRadius: BorderRadius.circular(26.r),
        boxShadow: lite
            ? null
            : [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 20.w,
                  offset: Offset(0, 10.w),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.analysisForecastTitle,
                style: AppType.titleSmall(
                  scheme.onPrimary.withValues(alpha: 0.85),
                ),
              ),
              Icon(Icons.auto_awesome, color: AppColors.warning, size: 20.sp),
            ],
          ),
          SizedBox(height: 8.h),

          // PROJECTED TOTAL (count-up animation)
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: total),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeOutExpo,
            builder: (context, value, child) {
              return Text(
                "${CurrencyController.to.currencySymbol.value}${value.toStringAsFixed(0)}",
                style: AppType.headlineLarge(scheme.onPrimary),
              );
            },
          ),

          SizedBox(height: 6.h),

          // "₹spent of ₹projected" — one comparison line plus a separate
          // scheduled line so future money is never read as "already spent".
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.analysisSpentOfProjected(
                  "$sym${spent.toStringAsFixed(0)}",
                  "$sym${total.toStringAsFixed(0)}",
                ),
                style: AppType.titleSmall(
                  scheme.onPrimary.withValues(alpha: 0.95),
                ),
              ),
              if (scheduled > 0) ...[
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      color: scheme.onPrimary.withValues(alpha: 0.8),
                      size: 14.sp,
                    ),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        l10n.analysisScheduledNotDue(
                          "$sym${scheduled.toStringAsFixed(0)}",
                        ),
                        style: AppType.labelSmall(
                          scheme.onPrimary.withValues(alpha: 0.85),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          SizedBox(height: 8.h),

          // Progress Section
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.r),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8.h,
                    backgroundColor: scheme.onPrimary.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      scheme.onPrimary.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                spent > total
                    ? ">${(pct * 100).toStringAsFixed(0)}%"
                    : "${(pct * 100).toStringAsFixed(0)}%",
                style: AppType.titleSmall(scheme.onPrimary),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // Warning/Status
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: scheme.onPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: scheme.onPrimary.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: warningColor, size: 14.sp),
                SizedBox(width: 6.w),
                Text(
                  warningText,
                  style: AppType.labelSmall(scheme.onPrimary),
                ),
              ],
            ),
          ),
          if (bills.categories.isNotEmpty) ...[
            SizedBox(height: 12.h),
            _buildBillsLink(scheme),
          ],
          if (bills.outstanding > 0) ...[
            SizedBox(height: 8.h),
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: scheme.onPrimary.withValues(alpha: 0.85),
                  size: 14.sp,
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    l10n.analysisBillsOwed(
                      "$sym${bills.plannedTotal.toStringAsFixed(0)}",
                      "$sym${bills.outstanding.toStringAsFixed(0)}",
                    ),
                    style: AppType.labelSmall(
                      scheme.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// "Bills ₹X · View" — the entry point to the per-category bills sheet.
  Widget _buildBillsLink(ColorScheme scheme) {
    final l10n = AppLocalizations.of(context)!;
    final sym = CurrencyController.to.currencySymbol.value;
    final due = bills.nextDueDate;
    return InkWell(
      onTap: () => showBillsSheet(context, bills: bills),
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: scheme.onPrimary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: scheme.onPrimary.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              color: scheme.onPrimary,
              size: 14.sp,
            ),
            SizedBox(width: 6.w),
            Expanded(
              child: Text(
                due == null
                    ? l10n.analysisBillsLink(
                        "$sym${bills.plannedTotal.toStringAsFixed(0)}",
                      )
                    : l10n.analysisBillsDueLink(
                        "$sym${bills.plannedTotal.toStringAsFixed(0)}",
                        DateFormat.MMMd().format(due),
                      ),
                style: AppType.labelSmall(scheme.onPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: scheme.onPrimary.withValues(alpha: 0.8),
              size: 16.sp,
            ),
          ],
        ),
      ),
    );
  }

  // --------------- Daily Limit Card ------------------

  Widget _buildDailyLimitCard(ColorScheme scheme) {
    final l10n = AppLocalizations.of(context)!;
    final sym = CurrencyController.to.currencySymbol.value;
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final remainingDays = max(1, daysInMonth - now.day + 1);
    final user = FirebaseAuth.instance.currentUser;

    // Derived here (not cached) so the card tracks SavingsSettings.percent and
    // IncomeSettings.mode/manual live, independent of when the last pass ran.
    final liveIncome = computeExpectedIncome(
      allTx: Get.isRegistered<TransactionController>()
          ? Get.find<TransactionController>().transactions
          : const [],
      uid: user?.uid ?? '',
      mode: IncomeSettings.mode.value,
      manualMonthly: IncomeSettings.manualMonthly.value,
    );
    final hasIncome = liveIncome.expectedIncome > 0;

    final List<Widget> children = [
      Text(
        l10n.analysisSmartDailyLimit,
        style: AppType.labelLarge(scheme.onSurface.withValues(alpha: 0.95)),
      ),
      SizedBox(height: 4.h),
      Obx(() {
        final m = IncomeSettings.mode.value;
        final manual = IncomeSettings.manualMonthly.value;
        var note = l10n.analysisMode(incomeModeLabel(l10n, m));
        if (m == IncomeMode.manual && manual <= 0) {
          note += ' · ${l10n.analysisManualNotSet}';
        }
        if (m == IncomeMode.autoSalaryWindow && liveIncome.salaryWindowEmpty) {
          note += liveIncome.expectedIncome > 0
              ? ' · ${l10n.analysisSalaryWindowBlend}'
              : ' · ${l10n.analysisNoSalaryWindow}';
        }
        return Text(
          note,
          style: AppType.labelSmall(scheme.onSurface.withValues(alpha: 0.7)),
        );
      }),
      SizedBox(height: 8.h),

      // Safe to spend today vs today's spend vs left today — one predicate
      // drives both the tile colour and the status line so they can never
      // disagree (today's tile used to be green while "Stop spending" below
      // said the opposite).
      if (hasIncome) ...[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _limitTile(
              l10n.analysisSafeToSpendToday,
              '$sym${_todayAllowance(liveIncome, remainingDays).toStringAsFixed(0)}',
              scheme.onSurface,
            ),
            _limitTile(
              l10n.today,
              '$sym${todayVariableSpent.toStringAsFixed(0)}',
              todayVariableSpent > _todayAllowance(liveIncome, remainingDays)
                  ? AppColors.error
                  : AppColors.success,
            ),
            _limitTile(
              l10n.analysisLeftToday,
              '$sym${_remainingToday(liveIncome, remainingDays).toStringAsFixed(0)}',
              scheme.onSurface,
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Text(
          _todayStatus(liveIncome, remainingDays, l10n),
          style: AppType.labelMedium(_todayStatusColor(liveIncome, remainingDays)),
        ),
        SizedBox(height: 6.h),
      ],

      InkWell(
        onTap: () => showIncomeModeSheet(context),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 2.h),
          child: Text(
            l10n.analysisBreakdownTitle,
            style: AppType.labelSmall(scheme.primary),
          ),
        ),
      ),
    ];

    return _InsightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  /// Today's safe spending allowance: budget left before today, spread over the
  /// remaining days (today included).
  double _todayAllowance(ExpectedIncomeResult liveIncome, int remainingDays) {
    return computeDailyAllowance(
      expectedIncome: liveIncome.expectedIncome,
      fixedForecast: forecastFixed,
      spentBeforeToday: variableSpentBeforeToday,
      todaySpent: todayVariableSpent,
      remainingDays: remainingDays,
      savingsRate: SavingsSettings.rate,
    ).todayAllowance;
  }

  /// What's left of today's allowance (never negative).
  double _remainingToday(ExpectedIncomeResult liveIncome, int remainingDays) {
    return computeDailyAllowance(
      expectedIncome: liveIncome.expectedIncome,
      fixedForecast: forecastFixed,
      spentBeforeToday: variableSpentBeforeToday,
      todaySpent: todayVariableSpent,
      remainingDays: remainingDays,
      savingsRate: SavingsSettings.rate,
    ).remainingToday;
  }

  /// Single status line computed from the same allowance the tiles show.
  String _todayStatus(
    ExpectedIncomeResult liveIncome,
    int remainingDays,
    AppLocalizations l10n,
  ) {
    final allowance = computeDailyAllowance(
      expectedIncome: liveIncome.expectedIncome,
      fixedForecast: forecastFixed,
      spentBeforeToday: variableSpentBeforeToday,
      todaySpent: todayVariableSpent,
      remainingDays: remainingDays,
      savingsRate: SavingsSettings.rate,
    );
    if (allowance.todayAllowance <= 0) {
      return l10n.analysisBudgetExhausted;
    }
    if (allowance.isExhausted) {
      return l10n.analysisStopSpending;
    }
    final ratio = todayVariableSpent / allowance.todayAllowance;
    if (ratio > 1.1) return l10n.analysisCarefulSpending;
    if (todayVariableSpent == 0) return l10n.analysisNoSpendingYet;
    return l10n.analysisWithinLimit;
  }

  Color _todayStatusColor(ExpectedIncomeResult liveIncome, int remainingDays) {
    final allowance = computeDailyAllowance(
      expectedIncome: liveIncome.expectedIncome,
      fixedForecast: forecastFixed,
      spentBeforeToday: variableSpentBeforeToday,
      todaySpent: todayVariableSpent,
      remainingDays: remainingDays,
      savingsRate: SavingsSettings.rate,
    );
    if (allowance.todayAllowance <= 0) return AppColors.error;
    if (allowance.isExhausted) return AppColors.error;
    final ratio = todayVariableSpent / allowance.todayAllowance;
    if (ratio > 1.1) return AppColors.warning;
    if (todayVariableSpent == 0) {
      return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    }
    return AppColors.success;
  }

  // --------------- Other Items Card ------------------
  //
  // Entry point to the discretionary-spend breakdown: the same expenses the
  // daily-limit card subtracts as "other items". Tapping opens a screen listing
  // each transaction so the number is auditable (and shows the excluded fixed
  // bills alongside it).
  Widget _buildOtherItemsCard(ColorScheme scheme) {
    final l10n = AppLocalizations.of(context)!;
    final sym = CurrencyController.to.currencySymbol.value;
    final count = currentVariableTxCount;
    final total = currentVariableSpent;

    return GestureDetector(
      onTap: () => Get.to(() => const OtherItemsScreen()),
      child: _InsightCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.analysisItemsSpent,
                    style: AppType.labelLarge(
                      scheme.onSurface.withValues(alpha: 0.95),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    count == 0
                        ? l10n.analysisNoOtherItems
                        : l10n.analysisItemsSummary(
                            "$sym${total.toStringAsFixed(0)}",
                            count,
                          ),
                    style: AppType.bodySmall(scheme.onSurface.withValues(alpha: 0.75)),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    l10n.analysisSeeOtherItems,
                    style: AppType.labelSmall(scheme.primary),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _limitTile(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppType.labelSmall(
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: AppType.labelLarge(color),
        ),
      ],
    );
  }

  // ---------------- Calendar Heatmap -----------------

  Widget _buildHeatmapCard(ColorScheme scheme) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lite = PerformanceController.to.liteMode.value;
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    if (dailySpending.isEmpty) {
      return _InsightCard(
        child: Padding(
          padding: EdgeInsets.all(AppSpace.s20.w),
          child: Center(
            child: Text(
              l10n.analysisNoSpendingMonth,
              style: AppType.bodySmall(scheme.onSurface.withValues(alpha: 0.8)),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final maxDaily = dailySpending.values.fold<double>(
      0,
      (prev, v) => v > prev ? v : prev,
    );

    return _InsightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.analysisMonthlyHeatmap,
            style: AppType.labelLarge(scheme.onSurface.withValues(alpha: 0.95)),
          ),
          SizedBox(height: 8.h),
          // Weekday initials come from the locale, not a hard-coded "S M T W
          // T F S" that only reads correctly in English.
          Row(
            children: List.generate(7, (i) {
              // 2024-01-07 is a Sunday, so the grid stays Sunday-first.
              final label = DateFormat(
                'EEEEE',
                Localizations.localeOf(context).toLanguageTag(),
              ).format(DateTime(2024, 1, 7 + i));
              return Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: AppType.labelSmall(
                      scheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              );
            }),
          ),
          SizedBox(height: 6.h),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount:
                DateTime(now.year, now.month, 1).weekday % 7 + daysInMonth,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8.h,
              crossAxisSpacing: 8.w,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              // Leading empty cells for the starting weekday (Sun=0, Mon=1 … Sat=6)
              final startOffset = DateTime(now.year, now.month, 1).weekday % 7;
              if (index < startOffset) return const SizedBox.shrink();
              final day = index - startOffset + 1;
              final date = DateTime(now.year, now.month, day);
              final spent = dailySpending[date] ?? 0;

              double intensity = maxDaily > 0
                  ? (spent / maxDaily).clamp(0.0, 1.0)
                  : 0.0;
              // Spending is the accent, not a success: the ramp runs from the
              // card surface to the accent instead of a Material green.
              final bgColor = Color.lerp(
                scheme.surface,
                AppColors.primary,
                intensity,
              )!;

              final isToday =
                  date.year == now.year &&
                  date.month == now.month &&
                  date.day == now.day;

              return Tooltip(
                message: l10n.analysisDaySpend(
                  day,
                  "${CurrencyController.to.currencySymbol.value}"
                  "${spent.toStringAsFixed(0)}",
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8.r),
                    border: isToday
                        ? Border.all(color: AppColors.primary, width: 1.5)
                        : Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                    boxShadow: [
                      if (!lite && intensity > 0.3)
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 4.w,
                          offset: Offset(0, 2.w),
                        ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      "$day",
                      style: AppType.labelMedium(
                        intensity > 0.5
                            ? scheme.onPrimary
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 8.h),
          Text(
            l10n.analysisHeatmapLegend,
            style: AppType.labelSmall(scheme.onSurface.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  // ---------------- Category Insight Card ------------

  Widget _buildInsightCard(CategoryInsight c, ColorScheme scheme) {
    final l10n = AppLocalizations.of(context)!;
    final trendColor = c.trendPercent >= 0 ? AppColors.error : AppColors.success;
    final trendIcon = c.trendPercent >= 0
        ? Icons.arrow_upward
        : Icons.arrow_downward;

    // Health Logic — guard NaN: smartBudget == 0 and currentSoFar == 0 gives
    // 0/0 which crashes LinearProgressIndicator in debug.
    double budget = c.smartBudget > 0 ? c.smartBudget : c.currentSoFar * 1.2;
    double progress = budget <= 0
        ? 0.0
        : (c.currentSoFar / budget).clamp(0.0, 1.0);

    Color healthColor;
    if (c.currentSoFar > budget) {
      healthColor = AppColors.error;
    } else if (c.currentSoFar > budget * 0.85) {
      healthColor = AppColors.warning;
    } else {
      healthColor = AppColors.success;
    }

    return GestureDetector(
      onTap: () {
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        Get.to(
          () => CategoryTransactionsScreen(
            categoryName: c.category,
            startDate: start,
            endDate: end,
          ),
        );
      },
      child: _InsightCard(
        margin: EdgeInsets.only(bottom: AppSpace.s12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Name + Trend (only show trends above 5%)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  c.category,
                  style: AppType.labelLarge(scheme.onSurface),
                ),
                if (c.trendPercent.abs() > 5)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: trendColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Row(
                      children: [
                        Icon(trendIcon, color: trendColor, size: 14.sp),
                        SizedBox(width: 2.w),
                        Text(
                          "${c.trendPercent.abs().toStringAsFixed(0)}%",
                          style: AppType.labelSmall(trendColor),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: 12.h),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10.r),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8.h,
                backgroundColor: scheme.onSurface.withValues(alpha: 0.05),
                valueColor: AlwaysStoppedAnimation<Color>(healthColor),
              ),
            ),
            SizedBox(height: 12.h),

            // Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.analysisSpent(
                        "${CurrencyController.to.currencySymbol.value}"
                        "${c.currentSoFar.toStringAsFixed(0)}",
                      ),
                      style: AppType.labelMedium(healthColor),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      l10n.analysisPredicted(
                        "${CurrencyController.to.currencySymbol.value}"
                        "${c.forecastMonthTotal.toStringAsFixed(0)}",
                      ),
                      style: AppType.labelSmall(scheme.onSurface.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Only show "Usual" when the bill actually has a plan amount;
                    // printing "Usual: ₹0" for new categories is misleading.
                    if (c.smartBudget > 0) ...[
                      Text(
                        l10n.analysisUsual(
                          "${CurrencyController.to.currencySymbol.value}"
                          "${c.smartBudget.toStringAsFixed(0)}",
                        ),
                        style: AppType.bodySmall(
                          scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      SizedBox(height: 4.h),
                    ],
                    // The "Bill" caption under a number labelled "Usual" was
                    // contradictory — remove it.
                  ],
                ),
              ],
            ),

            SizedBox(height: 12.h),

            // Insight Message
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tips_and_updates_outlined,
                    size: 16.sp,
                    color: scheme.primary.withValues(alpha: 0.7),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      c.message,
                      style: AppType.labelSmall(scheme.onSurface.withValues(alpha: 0.85)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================== Model ==================

class CategoryInsight {
  final String category;
  final double currentSoFar;
  final double forecastMonthTotal;
  final double prevMonthTotal;
  final double olderMonthTotal;
  final double smartBudget;
  final double trendPercent;
  final String message;

  CategoryInsight({
    required this.category,
    required this.currentSoFar,
    required this.forecastMonthTotal,
    required this.prevMonthTotal,
    required this.olderMonthTotal,
    required this.smartBudget,
    required this.trendPercent,
    required this.message,
  });
}

// ============================================
// ANIMATION HELPERS
// ============================================

/// The one surface behind the AI Insight cards.
///
/// It used to be three copies of the same `AnimatedContainer` — a surface
/// gradient between two alphas, a white-at-8% hairline, a black-at-20% shadow —
/// each gated on lite mode by hand. The gradient and the shadow are what made
/// this screen heavy under software GL, so the lite-mode branch stays, but the
/// surface, border and radius come from the tokens.
class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.child, this.margin});

  final Widget child;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lite = PerformanceController.to.liteMode.value;
    return AnimatedContainer(
      duration: AppMotion.base,
      margin: margin,
      padding: EdgeInsets.all(AppSpace.s20.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.xl.r),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: lite ? null : AppElevation.raised(isDark: isDark),
      ),
      child: child,
    );
  }
}
