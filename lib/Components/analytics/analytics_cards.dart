import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:money_control/Components/analytics/analytics_tokens.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/l10n/app_localizations.dart';

/// A stat card: a label, an amount and the icon that gives it its colour.
///
/// The screen's summary row renders three of these — income, expenses and
/// net balance — and the "financial summary" section renders them wide.
class AnalyticsStatCard extends StatelessWidget {
  const AnalyticsStatCard({
    super.key,
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    required this.isDark,
    this.isWide = false,
    this.onTap,
  });

  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  final bool isDark;

  /// Fills the available width instead of hugging the content.
  final bool isWide;

  /// Makes the card tappable. A card without one is announced as text, not
  /// as a button.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      // The card reads as text; only the button role is missing. `button` is
      // false when there is nothing to tap, so a plain summary card never
      // announces itself as actionable.
      child: Semantics(
        button: onTap != null,
        child: Container(
          width: isWide ? double.infinity : null,
          padding: EdgeInsets.all(18.w),
          decoration: BoxDecoration(
            color: AnalyticsTokens.glassBackground(isDark),
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: AnalyticsTokens.glassBorder(isDark)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
                blurRadius: 12.r,
                offset: Offset(0, 6.h),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: 10.r,
                      spreadRadius: 1.r,
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 22.sp),
              ),
              SizedBox(width: 16.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AnalyticsTokens.mutedText(isDark, 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '${CurrencyController.to.currencySymbol.value}'
                    '${amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: AnalyticsTokens.text(isDark),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "Quick Overview" card: today's, this week's and this month's income
/// against expense, as three in/out bar pairs.
class AnalyticsQuickOverviewCard extends StatelessWidget {
  const AnalyticsQuickOverviewCard({
    super.key,
    required this.isDark,
    required this.todayIncome,
    required this.todayExpense,
    required this.weekIncome,
    required this.weekExpense,
    required this.monthIncome,
    required this.monthExpense,
  });

  final bool isDark;
  final double todayIncome;
  final double todayExpense;
  final double weekIncome;
  final double weekExpense;
  final double monthIncome;
  final double monthExpense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final maxVal = [
      todayIncome,
      todayExpense,
      weekIncome,
      weekExpense,
      monthIncome,
      monthExpense,
    ].fold<double>(0, (p, e) => e > p ? e : p);

    return Container(
      padding: EdgeInsets.all(22.w),
      decoration: BoxDecoration(
        color: AnalyticsTokens.glassBackground(isDark),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: AnalyticsTokens.glassBorder(isDark)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 15.r,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flash_on_rounded, size: 20.sp, color: Colors.amber),
              SizedBox(width: 8.w),
              Text(
                l10n.quickOverview,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  color: AnalyticsTokens.text(isDark),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _QuickHistogramRow(
            label: l10n.today,
            income: todayIncome,
            expense: todayExpense,
            maxValue: maxVal,
            isDark: isDark,
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Divider(color: AnalyticsTokens.glassBorder(isDark)),
          ),
          _QuickHistogramRow(
            label: l10n.analyticsThisWeek,
            income: weekIncome,
            expense: weekExpense,
            maxValue: maxVal,
            isDark: isDark,
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Divider(color: AnalyticsTokens.glassBorder(isDark)),
          ),
          _QuickHistogramRow(
            label: l10n.analyticsThisMonth,
            income: monthIncome,
            expense: monthExpense,
            maxValue: maxVal,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

/// One "in / out" bar pair inside the quick overview.
class _QuickHistogramRow extends StatelessWidget {
  const _QuickHistogramRow({
    required this.label,
    required this.income,
    required this.expense,
    required this.maxValue,
    required this.isDark,
  });

  final String label;
  final double income;
  final double expense;
  final double maxValue;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final symbol = CurrencyController.to.currencySymbol.value;
    final safeMax = maxValue <= 0 ? 1 : maxValue;
    final incRatio = (income / safeMax).clamp(0.0, 1.0);
    final expRatio = (expense / safeMax).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AnalyticsTokens.text(isDark, 0.9),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            SizedBox(
              width: 40.w,
              child: Text(
                l10n.analyticsIn,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  _Track(isDark: isDark),
                  FractionallySizedBox(
                    widthFactor: incRatio > 0 ? incRatio : 0.01,
                    child: _Fill(
                      color: AppColors.primary,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            SizedBox(
              width: 60.w,
              child: Text(
                '$symbol${income.toStringAsFixed(0)}',
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AnalyticsTokens.text(isDark, 0.7),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            SizedBox(
              width: 40.w,
              child: Text(
                l10n.out2,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  _Track(isDark: isDark),
                  FractionallySizedBox(
                    widthFactor: expRatio > 0 ? expRatio : 0.01,
                    child: _Fill(
                      color: AppColors.error,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            SizedBox(
              width: 60.w,
              child: Text(
                '$symbol${expense.toStringAsFixed(0)}',
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AnalyticsTokens.text(isDark, 0.7),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The empty track a bar is drawn over.
class _Track extends StatelessWidget {
  const _Track({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6.h,
      decoration: BoxDecoration(
        color: AnalyticsTokens.glassBackground(isDark),
        borderRadius: BorderRadius.circular(10.r),
      ),
    );
  }
}

/// The filled part of a bar.
class _Fill extends StatelessWidget {
  const _Fill({required this.color, required this.isDark});

  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6.h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10.r),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 6.r,
            spreadRadius: 1.r,
          ),
        ],
      ),
    );
  }
}

/// The placeholder a chart shows when it has nothing to plot.
class AnalyticsEmptyCard extends StatelessWidget {
  const AnalyticsEmptyCard({
    super.key,
    required this.text,
    required this.isDark,
  });

  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200.h,
      decoration: BoxDecoration(
        color: AnalyticsTokens.glassBackground(isDark),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AnalyticsTokens.glassBorder(isDark)),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(color: AnalyticsTokens.mutedText(isDark, 0.7)),
        ),
      ),
    );
  }
}

/// A colour swatch in a chart legend.
class AnalyticsLegendDot extends StatelessWidget {
  const AnalyticsLegendDot({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10.w,
      height: 10.h,
      margin: EdgeInsets.only(right: 4.w),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(50.r),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 4.r,
            spreadRadius: 1.r,
          ),
        ],
      ),
    );
  }
}

/// One entry in the heatmap legend: a swatch and what it means.
class AnalyticsHeatmapLegendItem extends StatelessWidget {
  const AnalyticsHeatmapLegendItem({
    super.key,
    required this.color,
    required this.label,
    required this.textColor,
  });

  final Color color;
  final String label;

  /// The colour of the label. Passed in because the heatmap reads it from the
  /// cached theme rather than from the brightness.
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10.w,
          height: 10.w,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 4.w),
        Text(
          label,
          style: TextStyle(fontSize: 10.sp, color: textColor),
        ),
      ],
    );
  }
}

/// The spending personality: a name, a badge, and the saving rate.
class AnalyticsPersonalityCard extends StatelessWidget {
  const AnalyticsPersonalityCard({
    super.key,
    required this.personality,
    required this.income,
    required this.expense,
    required this.isDark,
  });

  final SpendingPersonality personality;
  final double income;
  final double expense;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final rawRate = income > 0 ? (income - expense) / income : 0.0;
    final isDeficit = rawRate < 0;
    final savingRate = rawRate.clamp(0.0, 1.0);
    final rateColor = isDeficit ? AppColors.error : personality.color;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: personality.color.withValues(alpha: isDark ? 0.08 : 0.1),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: personality.color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: personality.color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  personality.emoji,
                  style: TextStyle(fontSize: 20.sp),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.spendingPersonality,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: personality.color,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      personality.label,
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            personality.description,
            style: TextStyle(
              fontSize: 13.sp,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
          if (income > 0) ...[
            SizedBox(height: 14.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.savingRate,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
                Text(
                  '${(rawRate * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: rateColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(6.r),
              child: LinearProgressIndicator(
                value: savingRate,
                minHeight: 6.h,
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation(rateColor),
              ),
            ),
            if (isDeficit) ...[
              SizedBox(height: 4.h),
              Text(
                l10n.analyticsSpendingExceedsIncome(
                  ((-rawRate) * 100).toStringAsFixed(1),
                ),
                style: TextStyle(fontSize: 11.sp, color: AppColors.error),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Which spending personality the user has.
class SpendingPersonality {
  const SpendingPersonality({
    required this.label,
    required this.emoji,
    required this.description,
    required this.color,
  });

  final String label;
  final String emoji;
  final String description;
  final Color color;
}
