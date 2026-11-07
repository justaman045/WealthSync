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
import 'package:money_control/Utils/insights_math.dart';
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

  /// Single source of truth for every number on this screen. Built by
  /// [buildMonthInsights] in [_runInsights]; every card renders from it so no
  /// two surfaces can disagree about spend, forecast or remaining.
  MonthInsights? insights;

  /// Recomputes when the things the numbers learn from change: a category edit
  /// (fixed amount / treatment), a new or edited recurring payment, or any
  /// transaction write. Debounced so a burst of writes costs one pass.
  Worker? _categoryWorker;
  Worker? _paymentsWorker;
  Worker? _transactionsWorker;
  Worker? _loadingWorker;
  Worker? _incomeWorker;
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
    _incomeWorker?.dispose();
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
    // Income and savings settings change the daily limit and forecast; watch
    // them so the cards stay in sync without a manual refresh.
    _incomeWorker = ever(IncomeSettings.mode, (_) => _scheduleRecompute());
    ever(IncomeSettings.manualMonthly, (_) => _scheduleRecompute());
    ever(SavingsSettings.percent, (_) => _scheduleRecompute());
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

  /// Force-refresh: re-fetch transactions from Firestore, then recompute
  /// all insights with the fresh data. This is what the refresh button uses
  /// so it never recomputes from a stale cache.
  Future<void> _forceRefresh() async {
    if (!mounted) return;
    if (Get.isRegistered<TransactionController>()) {
      await Get.find<TransactionController>().forceRefreshTransactions();
    }
    if (!mounted) return;
    _runInsights();
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

      final now = DateTime.now();
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final daysPassed = now.day;

      final allTx = txController.transactions
          .where((tx) => tx.senderId == user.uid)
          .toList();

      // Build the single source of truth for every number on this screen.
      // buildMonthInsights owns all category aggregation, role classification,
      // bill building, forecast and daily-limit maths — no surface recomputes
      // anything inline, so no two cards can disagree.
      final recurringPayments = Get.isRegistered<RecurringPaymentController>()
          ? Get.find<RecurringPaymentController>().payments.toList()
          : <RecurringPayment>[];
      final month = buildMonthInsights(
        transactions: allTx,
        categories: txController.categories,
        recurring: recurringPayments,
        uid: user.uid,
        incomeMode: IncomeSettings.mode.value,
        manualIncome: IncomeSettings.manualMonthly.value,
        savingsRate: SavingsSettings.rate,
        now: now,
      );

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

      // Empty-account check is the last gate before rendering: buildMonthInsights
      // already computed everything from the model.
      final sym = CurrencyController.to.currencySymbol.value;

      // Build per-category insight messages from the model.
      final materialFloor = month.usualMonthAvg * 0.02;

      final categorized = month.categories.map<CategoryInsight>((c) {
        final currentSpent = c.spentThisMonth;
        final expectedSoFar = (c.autoAmount / daysInMonth) * daysPassed;
        String msg;
        if (c.role == DailyLimitRole.ignored) {
          msg = '';
        } else if (c.recurringDue > 0 && c.isUnpaid && c.dueDate != null) {
          msg = l10n.analysisBillDue(
            "$sym${c.plan.toStringAsFixed(0)}",
            DateFormat.MMMd().format(c.dueDate!),
          );
        } else if (c.role == DailyLimitRole.fixed) {
          if (c.plan > 0 && c.isPaid) {
            msg = l10n.analysisBillPaid(c.displayName);
          } else if (currentSpent > 0) {
            msg = l10n.analysisBillPartial(c.displayName);
          } else if (c.plan > 0) {
            msg = l10n.analysisBillPending(
              "$sym${c.plan.toStringAsFixed(0)}",
            );
          } else {
            msg = l10n.analysisBillPartial(c.displayName);
          }
        } else {
          if (currentSpent > expectedSoFar * 1.25 &&
              c.autoAmount > materialFloor) {
            msg = l10n.analysisSpendingFaster(c.displayName);
          } else if (currentSpent < expectedSoFar * 0.75 &&
              currentSpent > 0) {
            msg = l10n.analysisSpendingLower(c.displayName);
          } else if (currentSpent == 0) {
            msg = l10n.analysisSpendingNone(c.displayName);
          } else {
            msg = l10n.analysisSpendingOnTrack(c.displayName);
          }
        }
        return c.copyWith(message: msg);
      }).toList();

      _scheduleMidnightRefresh();

      setState(() {
        insights = month.copyWith(categories: categorized);
        loading = false;
        _hasData = true;
        _empty = categorized.isEmpty && month.spentTotalMtd == 0;
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
            onPressed: _forceRefresh,
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
                        children: insights!.categories
                            .map((c) => _buildInsightCard(c, scheme))
                            .toList(),
                      )
                    else
                      ...insights!.categories.asMap().entries.map((entry) {
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
    final m = insights!;
    final l10n = AppLocalizations.of(context)!;
    final lite = PerformanceController.to.liteMode.value;
    final sym = CurrencyController.to.currencySymbol.value;

    // forecastTotal == committedBills + variableForecast by construction, and
    // is always >= variableSpentMtd + fixedSpentMtd, so "spent of forecast" is
    // never confusing. "Remaining" is forecastTotal − spend so far.
    final projectedTotal = m.forecastTotal;
    final spent = m.variableSpentMtd + m.fixedSpentMtd;
    final scheduled = m.scheduledFuture;
    final remaining = m.remaining;
    final pct = projectedTotal > 0 ? (spent / projectedTotal).clamp(0.0, 1.0) : 0.0;

    // Overshoot vs the user's usual monthly average.
    final overshootPercent = m.usualMonthAvg > 0 && m.forecastTotal > m.usualMonthAvg
        ? ((m.forecastTotal - m.usualMonthAvg) / m.usualMonthAvg * 100).clamp(0.0, 999.0)
        : 0.0;

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

          // PROJECTED TOTAL (count-up animation — starts from the previous
          // value on recompute instead of restarting from zero).
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: projectedTotal),
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

          // "₹spent of ₹projected" — projectedTotal is always >= spent so the
          // comparison is never confusing. A separate "remaining" line shows
          // what's left of the forecast.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.analysisSpentOfProjected(
                  "$sym${spent.toStringAsFixed(0)}",
                  "$sym${projectedTotal.toStringAsFixed(0)}",
                ),
                style: AppType.titleSmall(
                  scheme.onPrimary.withValues(alpha: 0.95),
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                l10n.analysisForecastRemaining(
                  "$sym${remaining.toStringAsFixed(0)}",
                ),
                style: AppType.labelSmall(
                  scheme.onPrimary.withValues(alpha: 0.8),
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
              // Ignored spend (investments, SIPs, transfers) is excluded from
              // the forecast but surfaced here so the month reconciles:
              // income − savings − bills − other items − excluded = 0.
              if (m.ignoredSpentMtd > 0) ...[
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Icon(
                      Icons.remove_from_queue,
                      color: scheme.onPrimary.withValues(alpha: 0.6),
                      size: 14.sp,
                    ),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        l10n.analysisExcluded(
                          "$sym${m.ignoredSpentMtd.toStringAsFixed(0)}",
                        ),
                        style: AppType.labelSmall(
                          scheme.onPrimary.withValues(alpha: 0.6),
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
                spent > projectedTotal
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
          if (m.committedBills > 0) ...[
            SizedBox(height: 12.h),
            _buildBillsLink(scheme, m),
          ],
        ],
      ),
    );
  }

  /// "Bills ₹X · View" — the entry point to the per-category bills sheet.
  Widget _buildBillsLink(ColorScheme scheme, MonthInsights m) {
    final l10n = AppLocalizations.of(context)!;
    final sym = CurrencyController.to.currencySymbol.value;
    final due = m.categories
        .where((c) => c.dueDate != null)
        .map((c) => c.dueDate!)
        .fold<DateTime?>(null, (earliest, date) =>
            earliest == null || date.isBefore(earliest) ? date : earliest);
    final plannedTotal = m.categories.fold<double>(
        0, (sum, c) => sum + c.plan);
    return InkWell(
      onTap: () => showBillsSheet(context, bills: _billsForSheet(m)),
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
                        "$sym${plannedTotal.toStringAsFixed(0)}",
                      )
                    : l10n.analysisBillsDueLink(
                        "$sym${plannedTotal.toStringAsFixed(0)}",
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

  /// Builds a MonthlyBills (fixed + recurring only) from the model for the
  /// bills sheet. Variable-category plans are excluded — they appear as
  /// "projected other items" on the forecast card instead.
  ///
  /// Ignored categories with a recurring due still appear (so the user sees
  /// the bill), but their committed/reserved is 0 — the "Excluded" chip in
  /// the row explains the planned-vs-reserved gap.
  MonthlyBills _billsForSheet(MonthInsights m) {
    final billCats = m.categories.where((c) =>
        c.role == DailyLimitRole.fixed || c.recurringDue > 0).toList();
    final outstanding = m.categories
        .where((c) => c.isLiability)
        .fold<double>(0, (sum, c) => sum + c.recurringDue);
    return MonthlyBills(
      categories: billCats.map((c) => MonthlyBill(
        category: c.displayName,
        autoAmount: c.autoAmount,
        overrideAmount: c.overrideAmount,
        recurringDue: c.recurringDue,
        spentThisMonth: c.spentThisMonth,
        role: c.role,
        dueDate: c.dueDate,
        isLiability: c.isLiability,
        // Flag that this bill is excluded from the daily limit (ignored role)
        // so the sheet can show an "Excluded from limit" chip.
        isExcludedFromLimit: c.role == DailyLimitRole.ignored,
        autoCalculated: false,
      )).toList(),
      outstanding: outstanding,
    );
  }

  // --------------- Daily Limit Card ------------------

  Widget _buildDailyLimitCard(ColorScheme scheme) {
    final m = insights!;
    final l10n = AppLocalizations.of(context)!;
    final sym = CurrencyController.to.currencySymbol.value;
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final remainingDays = max(1, daysInMonth - now.day + 1);
    final user = FirebaseAuth.instance.currentUser;

    // Income is derived once in the model; recompute here only for the mode
    // note (salary-window-empty flag, manual-not-set flag) which the model
    // doesn't carry. The dollar value always comes from liveIncome so the card
    // can never disagree with the forecast card.
    final liveIncome = computeExpectedIncome(
      allTx: Get.isRegistered<TransactionController>()
          ? Get.find<TransactionController>().transactions
          : const [],
      uid: user?.uid ?? '',
      mode: IncomeSettings.mode.value,
      manualMonthly: IncomeSettings.manualMonthly.value,
      now: now,
    );
    final hasIncome = liveIncome.expectedIncome > 0;

    // Savings is always income × rate — never gated on a positive disposable
    // budget, so the line never drops to ₹0 mid-month.
    final saved = m.savingsReserved;

    // Compute the allowance ONCE so the tiles, status line and colour can never
    // disagree.
    final allowance = computeDailyAllowance(
      expectedIncome: m.income,
      fixedForecast: m.committedBills,
      spentBeforeToday: m.variableSpentBeforeToday,
      todaySpent: m.todayVariableSpent,
      remainingDays: remainingDays,
      savingsRate: SavingsSettings.rate,
    );

    final disposable = allowance.disposableBudget;
    final fixed = m.committedBills;

    final List<Widget> children = [
      Text(
        l10n.analysisSmartDailyLimit,
        style: AppType.labelLarge(scheme.onSurface.withValues(alpha: 0.95)),
      ),
      SizedBox(height: 4.h),
      Obx(() {
        final mode = IncomeSettings.mode.value;
        final manual = IncomeSettings.manualMonthly.value;
        var note = l10n.analysisMode(incomeModeLabel(l10n, mode));
        if (mode == IncomeMode.manual && manual <= 0) {
          note += ' · ${l10n.analysisManualNotSet}';
        }
        if (mode == IncomeMode.autoSalaryWindow &&
            liveIncome.salaryWindowEmpty) {
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

      // Breakdown: Income → −Savings → −Fixed Bills = Disposable → −Spent = Remaining
      if (hasIncome) ...[
        _breakdownRow(
          l10n.analysisIncomeLabel,
          '$sym${liveIncome.expectedIncome.toStringAsFixed(0)}',
          scheme.onSurface,
        ),
        _breakdownRow(
          l10n.analysisSavingsReserved,
          '-$sym${saved.toStringAsFixed(0)}',
          AppColors.success,
        ),
        _breakdownRow(
          l10n.analysisFixedBills,
          '-$sym${fixed.toStringAsFixed(0)}',
          AppColors.warning,
        ),
        _breakdownRow(
          l10n.analysisDisposableBudget,
          '$sym${disposable.toStringAsFixed(0)}',
          scheme.primary,
          isBold: true,
        ),
        Divider(
          height: 16.h,
          color: scheme.onSurface.withValues(alpha: 0.08),
        ),
        _breakdownRow(
          l10n.analysisAlreadySpent,
          '-$sym${m.todayVariableSpent.toStringAsFixed(0)}',
          m.todayVariableSpent > allowance.todayAllowance
              ? AppColors.error
              : AppColors.success,
        ),
        _breakdownRow(
          l10n.analysisRemainingToday,
          '$sym${allowance.remainingToday.toStringAsFixed(0)}',
          allowance.remainingToday <= 0 ? AppColors.error : AppColors.success,
          isBold: true,
        ),
        // Ignored spend (investments, SIPs, transfers) is excluded from the
        // daily limit — shown separately so the month reconciles.
        if (m.ignoredSpentMtd > 0) ...[
          _breakdownRow(
            l10n.analysisExcluded(m.ignoredSpentMtd.toStringAsFixed(0)),
            '-$sym${m.ignoredSpentMtd.toStringAsFixed(0)}',
            scheme.onSurface.withValues(alpha: 0.6),
          ),
        ],
        SizedBox(height: 8.h),
      ],

      // Safe to spend today vs today's spend vs left today — one predicate
      // drives both the tile colour and the status line so they can never
      // disagree.
      if (hasIncome) ...[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _limitTile(
              l10n.analysisSafeToSpendToday,
              '$sym${allowance.todayAllowance.toStringAsFixed(0)}',
              scheme.onSurface,
            ),
            _limitTile(
              l10n.today,
              '$sym${m.todayVariableSpent.toStringAsFixed(0)}',
              m.todayVariableSpent > allowance.todayAllowance
                  ? AppColors.error
                  : AppColors.success,
            ),
            _limitTile(
              l10n.analysisLeftToday,
              '$sym${allowance.remainingToday.toStringAsFixed(0)}',
              scheme.onSurface,
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Text(
          _todayStatus(allowance, m.todayVariableSpent, l10n),
          style: AppType.labelMedium(_todayStatusColor(
              allowance, m.todayVariableSpent)),
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

  /// One row of the daily-limit breakdown: label, value, colour.
  Widget _breakdownRow(String label, String value, Color color,
      {bool isBold = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppType.labelSmall(scheme.onSurface.withValues(alpha: 0.7)),
          ),
          Text(
            value,
            style: AppType.labelMedium(color).merge(
              TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Single status line computed from the same allowance the tiles show.
  String _todayStatus(DailyAllowance allowance, double todaySpent,
      AppLocalizations l10n) {
    if (allowance.todayAllowance <= 0) {
      return l10n.analysisBudgetExhausted;
    }
    if (allowance.isExhausted) {
      return l10n.analysisStopSpending;
    }
    final ratio = todaySpent / allowance.todayAllowance;
    if (ratio > 1.1) return l10n.analysisCarefulSpending;
    if (todaySpent == 0) return l10n.analysisNoSpendingYet;
    return l10n.analysisWithinLimit;
  }

  Color _todayStatusColor(DailyAllowance allowance, double todaySpent) {
    if (allowance.todayAllowance <= 0) return AppColors.error;
    if (allowance.isExhausted) return AppColors.error;
    final ratio = todaySpent / allowance.todayAllowance;
    if (ratio > 1.1) return AppColors.warning;
    if (todaySpent == 0) {
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
    final m = insights!;
    final l10n = AppLocalizations.of(context)!;
    final sym = CurrencyController.to.currencySymbol.value;
    final count = m.currentVariableTxCount;
    final total = m.variableSpentMtd;

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
    final m = insights!;
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lite = PerformanceController.to.liteMode.value;
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    if (m.dailySpending.isEmpty) {
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

    final maxDaily = m.dailySpending.values.fold<double>(
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
              final spent = m.dailySpending[date] ?? 0;

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

    // Health Logic — guard NaN: plan == 0 and spentThisMonth == 0 gives
    // 0/0 which crashes LinearProgressIndicator in debug.
    double budget = c.plan > 0 ? c.plan : c.spentThisMonth * 1.2;
    double progress = budget <= 0
        ? 0.0
        : (c.spentThisMonth / budget).clamp(0.0, 1.0);

    Color healthColor;
    if (c.spentThisMonth > budget) {
      healthColor = AppColors.error;
    } else if (c.spentThisMonth > budget * 0.85) {
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
            categoryName: c.key,
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
                  c.displayName,
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
                        "${c.spentThisMonth.toStringAsFixed(0)}",
                      ),
                      style: AppType.labelMedium(healthColor),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      l10n.analysisPredicted(
                        "${CurrencyController.to.currencySymbol.value}"
                        "${c.plan.toStringAsFixed(0)}",
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
                    if (c.plan > 0) ...[
                      Text(
                        l10n.analysisUsual(
                          "${CurrencyController.to.currencySymbol.value}"
                          "${c.plan.toStringAsFixed(0)}",
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
