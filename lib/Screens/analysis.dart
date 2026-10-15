// lib/Screens/ai_insights.dart

import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:flutter/rendering.dart' as rendering;
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/skeleton_loader.dart';
import 'package:money_control/Components/staggered_slide_fade.dart';
import 'package:money_control/Utils/responsive.dart';

import 'package:money_control/Components/adaptive_scaffold.dart';
import 'package:money_control/Components/feature_gate.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:get/get.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Models/cateogary.dart';
import 'package:money_control/Repositories/transaction_repository.dart';
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

class _AIInsightsScreenState extends State<AIInsightsScreen> {
  final TransactionRepository _repository = TransactionRepository();
  bool loading = true;
  String? error;
  final ValueNotifier<bool> _isBottomBarVisible = ValueNotifier(true);

  double forecastTotal = 0;
  double currentMonthSpent = 0;
  double todaySpent = 0;
  double todayVariableSpent = 0;

  /// UI treats this as MONTH TARGET
  double usualMonthAvg = 0;

  double overshootPercent = 0;

  List<CategoryInsight> insights = [];
  Map<DateTime, double> dailySpending = {};

  @override
  void initState() {
    super.initState();
    _runInsights();
  }

  @override
  void dispose() {
    _isBottomBarVisible.dispose();
    super.dispose();
  }

  // Class Level State for UI
  double forecastFixed = 0;
  double forecastVariable = 0;
  double currentVariableSpent = 0;
  int currentVariableTxCount = 0;

  // Income-aware daily limit inputs (see _runInsights). The limit itself is
  // derived in _buildDailyLimitCard so it tracks live settings.
  double expectedMonthlyIncome = 0;
  ExpectedIncomeResult? incomeResult;

  // ======================================================
  // 🔥 AI ANALYSIS: FIXED vs VARIABLE + HISTORICAL REMAINING SPEND
  // ======================================================
  Future<void> _runInsights() async {
    try {
      setState(() {
        loading = true;
        error = null;
        forecastTotal = 0;
        forecastFixed = 0;
        forecastVariable = 0;
        currentMonthSpent = 0;
        currentVariableSpent = 0;
        currentVariableTxCount = 0;
        todaySpent = 0;
        todayVariableSpent = 0;
        usualMonthAvg = 0;
        overshootPercent = 0;
        expectedMonthlyIncome = 0;
        incomeResult = null;
        dailySpending.clear();
        insights.clear();
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => loading = false);
        return;
      }

      if (!Get.isRegistered<TransactionController>()) {
        Get.put(TransactionController());
      }
      final TransactionController txController = Get.find();
      if (!txController.isLoading.value) {
        final freshTx = await _repository.getTransactionsStream().first;
        txController.transactions.assignAll(freshTx);
      } else {
        await Future.delayed(const Duration(milliseconds: 800));
      }
      if (!mounted) return;

      // Per-category user overrides for the fixed/variable/ignored split.
      final treatmentOverrides =
          buildTreatmentOverrides(txController.categories);

      final now = DateTime.now();
      final currentKey = now.year * 100 + now.month;
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final daysPassed = now.day;

      final allTx = txController.transactions
          .where((tx) => tx.senderId == user.uid)
          .toList();

      // Income: precedence — manual > 0 wins; else selected auto mode (blend or salary window).
      // Salary window = union of (days 1–7 OR last working day). If empty and mode is salary window, result.salaryWindowEmpty=true.
      await IncomeSettings.load();
      await SavingsSettings.load();
      if (!mounted) return;

      incomeResult = computeExpectedIncome(
        allTx: txController.transactions,
        uid: user.uid,
        mode: IncomeSettings.mode.value,
        manualMonthly: IncomeSettings.manualMonthly.value,
      );
      expectedMonthlyIncome = incomeResult?.expectedIncome ?? 0;

      if (allTx.isEmpty) {
        setState(() {
          loading = false;
          error =
              "No expense transactions yet.\nAdd a 'Send' transaction to see AI insights.";
        });
        return;
      }

      // ======================================================
      // 1. DATA ORGANIZING
      // ======================================================

      // Structure: Category -> MonthKey -> Total
      Map<String, Map<int, double>> categoryMonthly = {};
      Map<int, double> monthlyTotal = {};

      // Current Month Variable Spending
      double currentVar = 0;
      int variableTxCount = 0;
      // Monthly variable totals per month
      Map<int, double> monthlyVariable = {};

      dailySpending.clear();

      for (final tx in allTx) {
        final d = tx.date;
        final monthKey = d.year * 100 + d.month;
        final cat = tx.category ?? "Others";
        final role = resolveDailyLimitRole(
          cat,
          treatmentOverrides: treatmentOverrides,
        );

        // Category Aggregation
        categoryMonthly.putIfAbsent(cat, () => {});
        categoryMonthly[cat]![monthKey] =
            (categoryMonthly[cat]![monthKey] ?? 0) + tx.amount.abs();

        // Total Aggregation
        monthlyTotal[monthKey] =
            (monthlyTotal[monthKey] ?? 0) + tx.amount.abs();

        // Variable monthly totals (ignored categories excluded)
        if (role == DailyLimitRole.variable) {
          monthlyVariable[monthKey] =
              (monthlyVariable[monthKey] ?? 0) + tx.amount.abs();
        }

        // Current Month Specifics
        if (monthKey == currentKey) {
          currentMonthSpent += tx.amount.abs();
          final dayKey = DateTime(d.year, d.month, d.day);
          dailySpending[dayKey] =
              (dailySpending[dayKey] ?? 0) + tx.amount.abs();

          if (role == DailyLimitRole.variable) {
            currentVar += tx.amount.abs();
            variableTxCount++;
          }
        }
      }
      final todayKey = DateTime(now.year, now.month, now.day);
      todaySpent = dailySpending[todayKey] ?? 0;

      // Today's variable = today's total minus today's fixed AND ignored spend
      double todayFixed = 0;
      double todayIgnored = 0;
      for (final tx in allTx) {
        final d = tx.date;
        if (d.year == now.year && d.month == now.month && d.day == now.day) {
          final role = resolveDailyLimitRole(
            tx.category,
            treatmentOverrides: treatmentOverrides,
          );
          if (role == DailyLimitRole.fixed) {
            todayFixed += tx.amount.abs();
          } else if (role == DailyLimitRole.ignored) {
            todayIgnored += tx.amount.abs();
          }
        }
      }
      todayVariableSpent = max(0, todaySpent - todayFixed - todayIgnored);

      currentVariableSpent = currentVar;
      currentVariableTxCount = variableTxCount;

      // Historical Months (Excluding current)
      final pastMonthKeys =
          monthlyTotal.keys.where((k) => k != currentKey).toList()
            ..sort((a, b) => b.compareTo(a)); // Descending (Latest first)

      // ------------------------------------------------------
      // 3. FIXED EXPENSE FORECAST (Status Based)
      // ------------------------------------------------------
      double calcForecastFixed = 0;

      // Use actual category names from the user's data, classified by the same
      // whole-word helper the current-month variable total uses, so a bill is
      // never counted as discretionary while its forecast is still reserved.
      final fixedCatNames = categoryMonthly.keys
          .where((k) =>
              resolveDailyLimitRole(
                k,
                treatmentOverrides: treatmentOverrides,
              ) ==
              DailyLimitRole.fixed)
          .toSet();

      for (var cat in fixedCatNames) {
        final spentThisMonth = categoryMonthly[cat]?[currentKey] ?? 0;

        double typicalAmount = 0;
        if (pastMonthKeys.isNotEmpty) {
          double wSum = 0, wTotal = 0;
          for (int i = 0; i < pastMonthKeys.length; i++) {
            final v = categoryMonthly[cat]?[pastMonthKeys[i]];
            if (v != null && v > 0) {
              final w = (pastMonthKeys.length - i).toDouble();
              wSum += v * w;
              wTotal += w;
            }
          }
          if (wTotal > 0) typicalAmount = wSum / wTotal;
        }

        // If already paid ≥95% of typical → assume done; else forecast the full amount.
        if (typicalAmount > 0 && spentThisMonth >= typicalAmount * 0.95) {
          calcForecastFixed += spentThisMonth;
        } else {
          calcForecastFixed += max(spentThisMonth, typicalAmount);
        }
      }

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
      // Fallback for very first month: estimate from current pace
      if (usualMonthAvg == 0 && daysPassed > 0) {
        usualMonthAvg = (currentMonthSpent / daysPassed) * daysInMonth;
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

      categoryMonthly.forEach((cat, months) {
        final role = resolveDailyLimitRole(
          cat,
          treatmentOverrides: treatmentOverrides,
        );
        // Categories the user excluded from the limit get no limit-framed
        // insight — they would misleadingly read "on track"/"pending".
        if (role == DailyLimitRole.ignored) return;
        final currentSpent = months[currentKey] ?? 0;
        final isFixed = role == DailyLimitRole.fixed;

        // Full-history weighted average for this category
        double catHistAvg = 0;
        if (pastMonthKeys.isNotEmpty) {
          double wSum = 0, wTotal = 0;
          for (int i = 0; i < pastMonthKeys.length; i++) {
            final k = pastMonthKeys[i];
            if (months.containsKey(k)) {
              final w = (pastMonthKeys.length - i).toDouble();
              wSum += months[k]! * w;
              wTotal += w;
            }
          }
          if (wTotal > 0) catHistAvg = wSum / wTotal;
        }

        String msg;
        double catForecast = 0;
        double smartBudget = 0;

        if (isFixed) {
          smartBudget = catHistAvg;
          if (currentSpent >= catHistAvg * 0.9 && catHistAvg > 0) {
            msg = "✅ You have paid your usual $cat bill.";
            catForecast = currentSpent;
          } else if (currentSpent > 0) {
            msg = "⚠ $cat payment seems partial.";
            catForecast = max(currentSpent, catHistAvg);
          } else {
            msg =
                "📅 Pending: You usually pay ~${CurrencyController.to.currencySymbol.value}${catHistAvg.toStringAsFixed(0)}.";
            catForecast = catHistAvg;
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

          smartBudget = catHistAvg > 0 ? catHistAvg : currentSpent * 1.1;

          if (currentSpent > expectedSoFar * 1.25 && catHistAvg > 500) {
            msg = "🚨 Spending on $cat is faster than usual.";
          } else if (currentSpent < expectedSoFar * 0.75 && currentSpent > 0) {
            msg = "✨ Good job! $cat spending is lower than usual.";
          } else if (currentSpent == 0) {
            msg = "zzz No spending on $cat yet.";
          } else {
            msg = "⚖️ $cat spending is on track.";
          }
        }

        double lastMonthVal = months[pastMonthKeys.firstOrNull ?? 0] ?? 0;
        double trend = lastMonthVal > 0
            ? ((catForecast - lastMonthVal) / lastMonthVal * 100)
            : 0;

        localInsights.add(
          CategoryInsight(
            category: cat,
            currentSoFar: currentSpent,
            forecastMonthTotal: catForecast,
            prevMonthTotal: lastMonthVal,
            olderMonthTotal: 0,
            smartBudget: smartBudget,
            trendPercent: trend,
            message: msg,
          ),
        );
      });

      localInsights.sort((a, b) => b.currentSoFar.compareTo(a.currentSoFar));

      setState(() {
        insights = localInsights;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = "AI Analysis Error: $e";
      });
      debugPrint(e.toString());
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
          "AI Insights",
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 18.sp,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _runInsights),
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
          : error != null
          ? Center(child: Text(error!))
          : Obx(() => _buildContent(scheme)),
        ),
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
                      flagKey: 'ai_daily_limit',
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
                        "🔮 Category Insights (This Month)",
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                          letterSpacing: 0.5,
                        ),
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
                          delay: 350 + (index * 100),
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
    final lite = PerformanceController.to.liteMode.value;
    final total = forecastTotal;
    final spent = currentMonthSpent;
    final pct = total > 0 ? (spent / total).clamp(0.0, 1.0) : 0.0;

    // Status Logic
    String warningText;
    Color warningColor;
    IconData statusIcon;

    if (overshootPercent > 25) {
      warningText = "Overshooting by ~${overshootPercent.toStringAsFixed(1)}%";
      warningColor = Colors.redAccent.shade100;
      statusIcon = Icons.warning_rounded;
    } else if (overshootPercent > 10) {
      warningText =
          "Projected +${overshootPercent.toStringAsFixed(1)}% vs usual.";
      warningColor = Colors.orangeAccent.shade100;
      statusIcon = Icons.info_outline_rounded;
    } else {
      warningText = "On track with usual spending.";
      warningColor = Colors.greenAccent.shade100;
      statusIcon = Icons.check_circle_outline_rounded;
    }

    return Container(
      padding: EdgeInsets.all(22.w),
      decoration: BoxDecoration(
        // Vibrant "Mesh-like" Gradient — the 3-color per-pixel interpolation is
        // the single heaviest draw on this screen; the software-GL emulator
        // segfaults while rasterizing it, so lite mode paints a flat color.
        color: lite ? AppColors.primary : null,
        gradient: lite
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary, // Blurple
                  AppColors.primaryPress, // Deep Purple
                  Colors.deepPurple.shade900,
                ],
              ),
        borderRadius: BorderRadius.circular(26.r),
        // The glow shadow is multi-pass blur under software rendering and
        // crashed the CI emulator's GL stack after ~2m of this screen — skip it
        // in lite mode (the emulator auto-detects lite mode on ≤4 cores).
        boxShadow: lite
            ? null
            : [
                // "Glow" Effect
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
                "This Month Forecast",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 20.sp),
            ],
          ),
          SizedBox(height: 8.h),

          // COUNT-UP ANIMATION
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: total),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeOutExpo,
            builder: (context, value, child) {
              return Text(
                "${CurrencyController.to.currencySymbol.value}${value.toStringAsFixed(0)}",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              );
            },
          ),

          SizedBox(height: 12.h),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Spent: ${CurrencyController.to.currencySymbol.value}${spent.toStringAsFixed(0)}",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                "Target: ${CurrencyController.to.currencySymbol.value}${total.toStringAsFixed(0)}",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12.sp,
                ),
              ),
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
                    backgroundColor: Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                "${(pct * 100).toStringAsFixed(0)}%",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // Warning/Status
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: warningColor, size: 14.sp),
                SizedBox(width: 6.w),
                Text(
                  warningText,
                  style: TextStyle(
                    color: warningColor,
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------- Daily Limit Card ------------------

  Widget _buildDailyLimitCard(ColorScheme scheme) {
    final lite = PerformanceController.to.liteMode.value;
    final sym = CurrencyController.to.currencySymbol.value;
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final user = FirebaseAuth.instance.currentUser;

    // Derived here (not cached) so the card tracks SavingsSettings.percent and
    // IncomeSettings.mode/manual.
    final liveIncome = computeExpectedIncome(
      allTx: Get.isRegistered<TransactionController>()
          ? Get.find<TransactionController>().transactions
          : const [],
      uid: user?.uid ?? '',
      mode: IncomeSettings.mode.value,
      manualMonthly: IncomeSettings.manualMonthly.value,
    );
    final limit = computeDailyLimit(
      expectedIncome: liveIncome.expectedIncome,
      fixedForecast: forecastFixed,
      variableSpent: currentVariableSpent,
      remainingDays: max(1, daysInMonth - now.day + 1),
      savingsRate: SavingsSettings.rate,
    );

    final List<Widget> children = [
      Text(
        "Smart Daily Limit",
        style: TextStyle(
          fontSize: 15.sp,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface.withValues(alpha: 0.95),
          letterSpacing: 0.3,
        ),
      ),
      SizedBox(height: 4.h),
      Obx(() {
        final m = IncomeSettings.mode.value;
        final manual = IncomeSettings.manualMonthly.value;
        String note = "Mode: ${IncomeSettings.modeLabel(m)}";
        if (m == IncomeMode.manual && manual <= 0) {
          note += " · Manual not set — using Auto – Blend";
        }
        // reflect liveIncome if salary window empty
        if (m == IncomeMode.autoSalaryWindow) {
          if (liveIncome.salaryWindowEmpty) {
            note += " · No salary credits found in window (current month first week or previous month last working day)";
          }
        }
        return Text(
          note,
          style: TextStyle(
            fontSize: 11.sp,
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
        );
      }),
    ];

    if (liveIncome.expectedIncome <= 0) {
      // No income logged yet — an income-less "limit" would be meaningless, so
      // prompt the user instead of showing a number.
      children.addAll([
        SizedBox(height: 8.h),
        Text(
          "Add your income (a received Salary/Income entry) to see how much you can safely spend per day.",
          style: TextStyle(
            fontSize: 12.sp,
            color: scheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
      ]);
    } else {
      final daily = limit.dailyLimit;
      final today = todayVariableSpent;
      final ratePct = SavingsSettings.percent.value;

      String statusText;
      Color statusColor;
      if (today > daily * 1.5) {
        statusText = "Stop! You're well above today's safe limit.";
        statusColor = Colors.redAccent;
      } else if (today > daily * 1.1) {
        statusText = "Careful, you're slightly above today's safe limit.";
        statusColor = Colors.orange.shade700;
      } else if (today == 0) {
        statusText = "No spending yet. Great start to saving!";
        statusColor = Colors.blueGrey;
      } else {
        statusText = "You're within today's safe limit.";
        statusColor = Colors.green.shade700;
      }

      children.addAll([
        SizedBox(height: 6.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _limitTile(
              "Spend per day",
              "$sym${daily.toStringAsFixed(0)}",
              scheme.onSurface,
            ),
            _limitTile(
              "Today",
              "$sym${today.toStringAsFixed(0)}",
              today > daily ? Colors.redAccent : Colors.green.shade700,
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Text(
          "From ~$sym${limit.expectedIncome.toStringAsFixed(0)} income: saving "
          "$sym${limit.savingsReserved.toStringAsFixed(0)} ($ratePct%) and "
          "$sym${limit.fixedForecast.toStringAsFixed(0)} for bills. Already "
          "spent $sym${limit.variableSpent.toStringAsFixed(0)} on other items, "
          "leaving $sym${limit.remainingVariable.toStringAsFixed(0)} over "
          "${limit.remainingDays} day${limit.remainingDays == 1 ? '' : 's'}.",
          style: TextStyle(
            fontSize: 12.sp,
            color: scheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          statusText,
          style: TextStyle(
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w600,
            color: statusColor,
          ),
        ),
      ]);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.8), // Glass-like base
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
            color: scheme.brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.08)
                : AppColors.lightBorder),
        gradient: lite
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.surface.withValues(alpha: 0.9),
                  scheme.surface.withValues(alpha: 0.6),
                ],
              ),
        boxShadow: lite
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 15.w,
                  offset: Offset(0, 8.w),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  // --------------- Other Items Card ------------------
  //
  // Entry point to the discretionary-spend breakdown: the same expenses the
  // daily-limit card subtracts as "other items". Tapping opens a screen listing
  // each transaction so the number is auditable (and shows the excluded fixed
  // bills alongside it).
  Widget _buildOtherItemsCard(ColorScheme scheme) {
    final lite = PerformanceController.to.liteMode.value;
    final sym = CurrencyController.to.currencySymbol.value;
    final count = currentVariableTxCount;
    final total = currentVariableSpent;

    return GestureDetector(
      onTap: () => Get.to(() => const OtherItemsScreen()),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(
            color: scheme.brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.08)
                : AppColors.lightBorder,
          ),
          gradient: lite
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.surface.withValues(alpha: 0.9),
                    scheme.surface.withValues(alpha: 0.6),
                  ],
                ),
          boxShadow: lite
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 15.w,
                    offset: Offset(0, 8.w),
                  ),
                ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Items spent this month",
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface.withValues(alpha: 0.95),
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    count == 0
                        ? "No other items yet — every expense is a bill"
                        : "$sym${total.toStringAsFixed(0)} · "
                            "$count transaction${count == 1 ? '' : 's'}",
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: scheme.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    "See which transactions count as other items",
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
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
          style: TextStyle(
            fontSize: 11.sp,
            color: Colors.grey.withValues(alpha: 0.9),
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  // ---------------- Calendar Heatmap -----------------

  Widget _buildHeatmapCard(ColorScheme scheme) {
    final lite = PerformanceController.to.liteMode.value;
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    if (dailySpending.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18.r),
        ),
        child: Text(
          "No spending recorded this month yet.\nAs you spend, this calendar will light up day by day.",
          style: TextStyle(
            color: scheme.onSurface.withValues(alpha: 0.8),
            fontSize: 12.5.sp,
          ),
        ),
      );
    }

    final maxDaily = dailySpending.values.fold<double>(
      0,
      (prev, v) => v > prev ? v : prev,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.8), // Glass-like base
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
            color: scheme.brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.08)
                : AppColors.lightBorder),
        gradient: lite
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.surface.withValues(alpha: 0.95),
                  scheme.surface.withValues(alpha: 0.8),
                ],
              ),
        boxShadow: lite
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 15.w,
                  offset: Offset(0, 8.w),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Monthly Spend Heatmap",
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withValues(alpha: 0.95),
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: 8.h),
          // Weekday header row
          Row(
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((label) {
              return Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              );
            }).toList(),
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
              final bgColor = Color.lerp(
                scheme.surface,
                Colors.green.shade600,
                intensity,
              )!;

              final isToday =
                  date.year == now.year &&
                  date.month == now.month &&
                  date.day == now.day;

              return Tooltip(
                message:
                    "Day $day: ${CurrencyController.to.currencySymbol.value}${spent.toStringAsFixed(0)}",
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8.r),
                    border: isToday
                        ? Border.all(color: Colors.blueAccent, width: 1.5)
                        : Border.all(
                            color: scheme.brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.05)
                                : AppColors.lightBorder,
                          ),
                    boxShadow: [
                      if (!lite && intensity > 0.3)
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.3),
                          blurRadius: 4.w,
                          offset: Offset(0, 2.w),
                        ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      "$day",
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: intensity > 0.5
                            ? Colors.white
                            : scheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 8.h),
          Text(
            "Darker boxes indicate higher spending days.",
            style: TextStyle(
              fontSize: 11.sp,
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Category Insight Card ------------

  Widget _buildInsightCard(CategoryInsight c, ColorScheme scheme) {
    final lite = PerformanceController.to.liteMode.value;
    final trendColor = c.trendPercent >= 0
        ? Colors.redAccent
        : Colors.green.shade700;
    final trendIcon = c.trendPercent >= 0
        ? Icons.arrow_upward
        : Icons.arrow_downward;

    // Health Logic
    // Smart Budget might be 0 if new.
    double budget = c.smartBudget > 0 ? c.smartBudget : c.currentSoFar * 1.2;
    double progress = (c.currentSoFar / budget).clamp(0.0, 1.0);

    Color healthColor;
    if (c.currentSoFar > budget) {
      healthColor = Colors.redAccent;
    } else if (c.currentSoFar > budget * 0.85) {
      healthColor = Colors.orange.shade700;
    } else {
      healthColor = Colors.green.shade600;
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: lite
              ? null
              : [
                  BoxShadow(
                    color: scheme.onSurface.withValues(alpha: 0.03),
                    blurRadius: 10.w,
                    offset: Offset(0, 4.w),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Name + Trend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  c.category,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                if (c.trendPercent.abs() > 1) // Only show significant trends
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
                          style: TextStyle(
                            color: trendColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11.sp,
                          ),
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
                      "Spent: ${CurrencyController.to.currencySymbol.value}${c.currentSoFar.toStringAsFixed(0)}",
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: healthColor,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      "Predicted: ${CurrencyController.to.currencySymbol.value}${c.forecastMonthTotal.toStringAsFixed(0)}",
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Usual: ${CurrencyController.to.currencySymbol.value}${c.smartBudget.toStringAsFixed(0)}",
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      "Limit",
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: scheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
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
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.85),
                        fontSize: 11.5.sp,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
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
