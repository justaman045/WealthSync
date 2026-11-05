import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:money_control/Components/colors.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/privacy_controller.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Utils/wealth_math.dart';
import 'package:money_control/l10n/app_localizations.dart';

/// "This month" strip: money in, money out, and what is left.
///
/// Reads the cached aggregates on [TransactionController] rather than scanning
/// the transaction list in `build()`. Hides itself until the stream has emitted
/// (no zero-row flash on a cold start) and when the month has no activity.
class HomeMonthSummaryCard extends StatelessWidget {
  const HomeMonthSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<TransactionController>()) {
      return const SizedBox.shrink();
    }
    final controller = Get.find<TransactionController>();
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    // Same surface as the quick-send strip: two adjacent rows must not differ
    // by a fill alpha or a border. A plain Container is the established
    // pattern for the home strips.
    final containerColor = isDark
        ? scheme.surface.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.8);

    return Obx(() {
      if (!controller.hasLoadedOnce.value) return const SizedBox.shrink();
      final income = controller.monthIncomeRx.value;
      final spend = controller.monthSpendRx.value;
      if (income <= 0 && spend <= 0) return const SizedBox.shrink();

      final symbol = CurrencyController.to.currencySymbol.value;
      final net = income - spend;
      final netColor = net < 0 ? AppColors.error : scheme.onSurface;

      return Padding(
        // Bottom margin lives here (not next to the widget) so a month with no
        // activity leaves no gap at all.
        padding: EdgeInsets.only(bottom: AppSpace.s12.h),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpace.s16.w,
            vertical: AppSpace.s16.h,
          ),
          decoration: BoxDecoration(
            color: containerColor,
            borderRadius: BorderRadius.circular(AppRadius.xxl.r),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.withValues(alpha: 0.1),
            ),
            boxShadow: isDark
                ? const []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10.w,
                      offset: Offset(0.w, 5.w),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.homeThisMonth,
                style: AppType.labelSmall(
                  scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              SizedBox(height: AppSpace.s12.h),
              Row(
                children: [
                  Expanded(
                    child: _metric(
                      label: l10n.homeMoneyIn,
                      text: '$symbol${compact(income)}',
                      color: AppColors.success,
                      scheme: scheme,
                    ),
                  ),
                  _divider(scheme),
                  Expanded(
                    child: _metric(
                      label: l10n.homeMoneyOut,
                      text: '$symbol${compact(spend)}',
                      color: AppColors.error,
                      scheme: scheme,
                    ),
                  ),
                  _divider(scheme),
                  Expanded(
                    child: _metric(
                      label: l10n.homeLeftOver,
                      // Signed on purpose: a month that spent more than it
                      // earned is not "left over", it is a deficit.
                      text: '${net < 0 ? '-' : ''}$symbol${compact(net.abs())}',
                      color: netColor,
                      scheme: scheme,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _metric({
    required String label,
    required String text,
    required Color color,
    required ColorScheme scheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppType.labelSmall(
            scheme.onSurface.withValues(alpha: 0.6),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: AppSpace.s4.h),
        // PrivacyText is the only way an amount may render on this screen.
        PrivacyText(
          text,
          style: AppType.titleMedium(color),
        ),
      ],
    );
  }

  Widget _divider(ColorScheme scheme) {
    return Container(
      width: 1,
      height: 32.h,
      margin: EdgeInsets.symmetric(horizontal: AppSpace.s8.w),
      color: scheme.onSurface.withValues(alpha: 0.08),
    );
  }
}
