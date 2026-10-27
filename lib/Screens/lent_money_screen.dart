import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:money_control/Utils/animation.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Config/app_strings.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/lent_money_controller.dart';
import 'package:money_control/Models/lent_money_model.dart';
import 'package:money_control/Screens/add_lent_money_screen.dart';
import 'package:money_control/Screens/repayment_screen.dart';
import 'package:money_control/Screens/split_bill_screen.dart';
import 'package:money_control/Utils/responsive.dart';
import 'package:money_control/Components/adaptive_panel.dart';
import 'package:money_control/l10n/app_localizations.dart';
import 'package:money_control/Services/performance_controller.dart';
import 'package:money_control/Components/empty_state.dart';

class LentMoneyScreen extends StatefulWidget {
  const LentMoneyScreen({super.key});

  @override
  State<LentMoneyScreen> createState() => _LentMoneyScreenState();
}

class _LentMoneyScreenState extends State<LentMoneyScreen> {
  late final LentMoneyController _controller;
  late final CurrencyController _currencyController;
  LentMoneyModel? _selectedEntry;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<LentMoneyController>()) Get.put(LentMoneyController());
    _controller = Get.find<LentMoneyController>();
    if (!Get.isRegistered<CurrencyController>()) Get.put(CurrencyController());
    _currencyController = Get.find<CurrencyController>();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark ? AppColors.darkGradient : AppColors.lightGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(AppStrings.lentMoneyTracker),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.call_split_rounded),
              tooltip: "Split a Bill",
              onPressed: () => Get.to(() => const SplitBillScreen()),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Get.to(() => const AddLentMoneyScreen()),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            AppStrings.add,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: AdaptivePanel(master: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
            child: Column(
              children: [
                _buildSummaryCard(theme),
                _buildNetBalanceIndicator(theme),
                Expanded(child: _buildList(theme)),
              ],
            ),
          ),
        ),
            detail: _selectedEntry != null
                // Key by id so selecting a different entry rebuilds a fresh
                // State instead of reusing the previous entry's field values.
                ? AddLentMoneyScreen(
                    key: ValueKey(_selectedEntry!.id),
                    existingEntry: _selectedEntry!,
                  )
                : _buildDetailPlaceholder(),
            showDetail: _selectedEntry != null,
        ),
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: Row(
        children: [
          Expanded(child: _buildSummaryMetric(theme, isReceivable: true)),
          SizedBox(width: 12.w),
          Expanded(child: _buildSummaryMetric(theme, isReceivable: false)),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(ThemeData theme, {required bool isReceivable}) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final title = isReceivable ? l10n.lentOwedToYou : l10n.lentYouOwe;
    final icon = isReceivable ? Icons.arrow_downward : Icons.arrow_upward;
    final color = isReceivable ? AppColors.success : AppColors.warning;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return GlassContainer(
      padding: EdgeInsets.all(AppSpace.s16.w),
      borderRadius: BorderRadius.circular(AppRadius.lg.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpace.s8.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20.sp, color: color),
              ),
              SizedBox(width: AppSpace.s8.w),
              Expanded(
                child: Text(
                  title,
                  style: AppType.bodySmall(
                    isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpace.s12.h),
          Obx(() {
            final total = isReceivable
                ? _controller.totalPendingReceivables
                : _controller.totalPendingPayables;
            final currency = _currencyController.currencyCode.value;
            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              // Lite mode renders the figure instead of counting to it.
              child: PerformanceController.to.liteMode.value
                  ? Text(
                      NumberFormat.simpleCurrency(
                        name: currency,
                      ).format(total),
                      style: AppType.headlineSmall(textColor),
                    )
                  : TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: total),
                      duration: AppMotion.countUp,
                      curve: AppMotion.emphasized,
                      builder: (context, value, child) {
                        return Text(
                          NumberFormat.simpleCurrency(
                            name: currency,
                          ).format(value),
                          style: AppType.headlineSmall(textColor),
                        );
                      },
                    ),
            );
          }),
        ],
      ),
    ).animate().fadeIn(duration: AppMotion.slow).slideY(
      begin: -0.1,
      end: 0,
      curve: AppMotion.standard,
    );
  }

  Widget _buildNetBalanceIndicator(ThemeData theme) {
    return Obx(() {
      final netBalance = _controller.netBalance;
      if (netBalance == 0 && _controller.entries.isEmpty) {
        return const SizedBox.shrink();
      }

      final isPositive = netBalance >= 0;
      final color = isPositive ? AppColors.success : AppColors.warning;
      final isDark = theme.brightness == Brightness.dark;
      final l10n = AppLocalizations.of(context)!;
      final label =
          isPositive ? l10n.lentNetOwedToYou : l10n.lentNetYouOwe;
      final icon = isPositive ? Icons.trending_up : Icons.trending_down;
      final currency = _currencyController.currencyCode.value;

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w).copyWith(bottom: 16.h),
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpace.s20.w,
            vertical: AppSpace.s12.h,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // The label is unbounded text next to an amount: without a
              // Flexible the pair overflows a narrow (320dp) card, which is a
              // hard failure in widget tests and clipped text on a phone.
              Expanded(
                child: Row(
                  children: [
                    Icon(icon, color: color, size: 20.sp),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: Text(
                        l10n.lentGrandSum(label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.bodyMedium(
                          isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                NumberFormat.simpleCurrency(
                  name: currency,
                ).format(netBalance.abs()),
                maxLines: 1,
                style: AppType.titleMedium(color),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
    });
  }

  Widget _buildList(ThemeData theme) {
    return Obx(() {
      if (_controller.entries.isEmpty) {
        return Center(
          child: EmptyStateWidget(
            icon: Icons.handshake_outlined,
            title: AppLocalizations.of(context)!.lentNoActiveRecords,
            subtitle: AppLocalizations.of(context)!.lentEmptySubtitle,
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () => _controller.fetchEntries(),
        color: AppColors.primary,
        backgroundColor: theme.colorScheme.surface,
        child: ListView.builder(
          padding: EdgeInsets.symmetric(
            horizontal: 20.w,
            vertical: 10.h,
          ).copyWith(bottom: 100.h),
          itemCount: _controller.entries.length,
          itemBuilder: (context, index) {
            final entry = _controller.entries[index];
            return animatedItem(
              _buildEntryItem(entry, theme),
              index,
              slide: true,
            );
          },
        ),
      );
    });
  }

  Widget _buildEntryItem(LentMoneyModel entry, ThemeData theme) {
    final currency = _currencyController.currencyCode.value;
    final isReceivable = entry.type == 'lent';
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final tertiaryColor =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    // Status visual traits
    final activeColor = isReceivable ? AppColors.success : AppColors.warning;
    final iconData = isReceivable ? Icons.arrow_downward : Icons.arrow_upward;
    final typeLabel = isReceivable ? l10n.lentLentTo : l10n.lentBorrowedFrom;
    final actionLabel = isReceivable ? l10n.receive : l10n.lentRepay;
    final actionIcon = isReceivable ? Icons.call_received : Icons.currency_rupee;

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: GestureDetector(
        onTap: () {
          final isSplit = Responsive.isTablet(context) && Responsive.isLandscape(context);
          if (isSplit) {
            setState(() => _selectedEntry = entry);
          } else {
            Get.to(() => AddLentMoneyScreen(existingEntry: entry));
          }
        },
        child: Slidable(
          key: ValueKey(entry.id),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            children: [
              SlidableAction(
                onPressed: (context) =>
                    Get.to(() => RepaymentScreen(entry: entry)),
                backgroundColor: activeColor,
                foregroundColor: Colors.white,
                icon: actionIcon,
                label: actionLabel,
              ),
              SlidableAction(
                onPressed: (context) {
                  if (!entry.isSettled) {
                    _controller.markAsSettled(entry);
                  }
                },
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                icon: Icons.check_circle_outline,
                label: entry.isSettled ? l10n.lentAlreadySettled : l10n.lentSettle,
              ),
              SlidableAction(
                onPressed: (context) {
                  _controller.deleteEntry(entry.id);
                },
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                icon: Icons.delete_outline,
                label: AppStrings.delete,
              ),
            ],
          ),
          child: GlassContainer(
            padding: EdgeInsets.all(AppSpace.s16.w),
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            border: Border.all(
              color: entry.isSettled
                  ? AppColors.success.withValues(alpha: 0.3)
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: entry.isSettled
                        ? AppColors.success.withValues(alpha: 0.1)
                        : activeColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    entry.isSettled ? Icons.check : iconData,
                    color: entry.isSettled ? AppColors.success : activeColor,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.friendName,
                        style: AppType.titleMedium(textColor).copyWith(
                          decoration: entry.isSettled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      SizedBox(height: AppSpace.s4.h),
                      Row(
                        children: [
                          // Type label + date share one line in a narrow card
                          // (the amount sits beside it): both must yield, or
                          // the row overflows by ~11px at 320dp.
                          Flexible(
                            child: Text(
                              typeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.labelMedium(activeColor),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              " \u2022 ${DateFormat('MMM dd, yyyy').format(entry.dateLent)}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.bodySmall(tertiaryColor),
                            ),
                          ),
                        ],
                      ),
                      if (entry.note.isNotEmpty) ...[
                        SizedBox(height: AppSpace.s4.h),
                        Text(
                          entry.note,
                          style: AppType.bodySmall(secondaryColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (entry.repaidAmount > 0) ...[
                        SizedBox(height: AppSpace.s4.h),
                        Text(
                          l10n.lentRepaid(
                            NumberFormat.simpleCurrency(
                              name: currency,
                            ).format(entry.repaidAmount),
                          ),
                          style: AppType.labelMedium(AppColors.success),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      NumberFormat.simpleCurrency(
                        name: currency,
                      ).format(entry.amount),
                      style: AppType.titleMedium(
                        entry.isSettled ? tertiaryColor : textColor,
                      ),
                    ),
                    SizedBox(height: AppSpace.s4.h),
                    Text(
                      entry.isSettled
                          ? l10n.lentSettled
                          : entry.repaidAmount > 0
                          ? l10n.lentAmountLeft(
                              "${_currencyController.currencySymbol.value}${entry.remainingAmount.toStringAsFixed(0)}",
                            )
                          : l10n.lentPending,
                      style: AppType.labelMedium(
                        entry.isSettled ? AppColors.success : activeColor,
                      ),
                    ),
                    if (!entry.isSettled) ...[
                      SizedBox(height: AppSpace.s4.h),
                      // A 26 dp tap target with no ripple: it is the primary
                      // action on the row, so it is a real button.
                      TextButton.icon(
                        onPressed: () =>
                            Get.to(() => RepaymentScreen(entry: entry)),
                        style: TextButton.styleFrom(
                          foregroundColor: activeColor,
                          backgroundColor: activeColor.withValues(alpha: 0.12),
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpace.s12.w,
                            vertical: AppSpace.s4.h,
                          ),
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.xs.r),
                          ),
                          textStyle: AppType.labelSmall(activeColor),
                        ),
                        icon: Icon(actionIcon, size: 14.sp),
                        label: Text(actionLabel),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.1, end: 0, curve: Curves.easeOut);
  }

  Widget _buildDetailPlaceholder() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64.sp,
            color: isDark
                ? AppColors.darkTextTertiary
                : AppColors.lightTextTertiary,
          ),
          SizedBox(height: AppSpace.s16.h),
          Text(
            AppLocalizations.of(context)!.lentSelectEntryDetails,
            textAlign: TextAlign.center,
            style: AppType.bodyLarge(
              isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
