import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/lent_money_controller.dart';
import 'package:money_control/Models/lent_money_model.dart';
import 'package:money_control/Screens/add_lent_money_screen.dart';
import 'package:money_control/Screens/split_bill_screen.dart';

class LentMoneyScreen extends StatefulWidget {
  const LentMoneyScreen({super.key});

  @override
  State<LentMoneyScreen> createState() => _LentMoneyScreenState();
}

class _LentMoneyScreenState extends State<LentMoneyScreen> {
  late final LentMoneyController _controller;
  late final CurrencyController _currencyController;

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
          title: const Text("Lent Money Tracker"),
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
          backgroundColor: const Color(0xFF6C63FF),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            "Add",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: Column(
          children: [
            _buildSummaryCard(theme),
            _buildNetBalanceIndicator(theme),
            Expanded(child: _buildList(theme)),
          ],
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
    final title = isReceivable ? "Owed to You" : "You Owe";
    final icon = isReceivable ? Icons.arrow_downward : Icons.arrow_upward;
    final color = isReceivable ? Colors.greenAccent : Colors.orangeAccent;

    return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: GlassContainer(
            padding: EdgeInsets.all(16.w),
            borderRadius: BorderRadius.circular(20.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 20.sp, color: color),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.8,
                          ),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Obx(() {
                  final total = isReceivable
                      ? _controller.totalPendingReceivables
                      : _controller.totalPendingPayables;
                  final currency = _currencyController.currencyCode.value;
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: total),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeOutExpo,
                      builder: (context, value, child) {
                        return Text(
                          NumberFormat.simpleCurrency(
                            name: currency,
                          ).format(value),
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 24.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: -0.1, end: 0, curve: Curves.easeOut);
  }

  Widget _buildNetBalanceIndicator(ThemeData theme) {
    return Obx(() {
      final netBalance = _controller.netBalance;
      if (netBalance == 0 && _controller.entries.isEmpty) {
        return const SizedBox.shrink();
      }

      final isPositive = netBalance >= 0;
      final color = isPositive ? Colors.greenAccent : Colors.orangeAccent;
      final label = isPositive ? "Net Owed to You" : "Net You Owe";
      final icon = isPositive ? Icons.trending_up : Icons.trending_down;
      final currency = _currencyController.currencyCode.value;

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w).copyWith(bottom: 16.h),
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20.sp),
                  SizedBox(width: 8.w),
                  Text(
                    "Grand Sum ($label)",
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: netBalance.abs()),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutExpo,
                builder: (context, value, child) {
                  return Text(
                    NumberFormat.simpleCurrency(name: currency).format(value),
                    style: TextStyle(
                      color: color,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.sentiment_satisfied_rounded,
                size: 60.sp,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              ),
              SizedBox(height: 16.h),
              Text(
                "No active lent money records.",
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 16.sp,
                ),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () async {
          // The stream inherently stays up to date, but we simulate a
          // realistic network delay to offer tactile user feedback.
          await Future.delayed(const Duration(milliseconds: 800));
        },
        color: const Color(0xFF6C63FF),
        backgroundColor: theme.colorScheme.surface,
        child: ListView.builder(
          padding: EdgeInsets.symmetric(
            horizontal: 20.w,
            vertical: 10.h,
          ).copyWith(bottom: 100.h),
          itemCount: _controller.entries.length,
          itemBuilder: (context, index) {
            final entry = _controller.entries[index];
            return _buildEntryItem(entry, theme)
                .animate()
                .fadeIn(duration: 400.ms, delay: (index * 50).ms)
                .slideX(begin: 0.1, end: 0, curve: Curves.easeOutExpo);
          },
        ),
      );
    });
  }

  Widget _buildEntryItem(LentMoneyModel entry, ThemeData theme) {
    final currency = _currencyController.currencyCode.value;
    final isReceivable = entry.type == 'lent';

    // Status visual traits
    final activeColor = isReceivable ? Colors.greenAccent : Colors.orangeAccent;
    final iconData = isReceivable ? Icons.arrow_downward : Icons.arrow_upward;
    final typeLabel = isReceivable ? "Lent to" : "Borrowed from";

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: GestureDetector(
        onTap: () {
          Get.to(() => AddLentMoneyScreen(existingEntry: entry));
        },
        child: Slidable(
          key: ValueKey(entry.id),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            children: [
              SlidableAction(
                onPressed: (context) {
                  if (!entry.isSettled) {
                    _controller.markAsSettled(entry);
                  }
                },
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                icon: Icons.check_circle_outline,
                label: entry.isSettled ? 'Already Settled' : 'Settle',
              ),
              SlidableAction(
                onPressed: (context) {
                  _controller.deleteEntry(entry.id);
                },
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                icon: Icons.delete_outline,
                label: 'Delete',
              ),
            ],
          ),
          child: GlassContainer(
            padding: EdgeInsets.all(16.w),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: entry.isSettled
                  ? Colors.green.withValues(alpha: 0.3)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.1),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: entry.isSettled
                        ? Colors.green.withValues(alpha: 0.1)
                        : activeColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    entry.isSettled ? Icons.check : iconData,
                    color: entry.isSettled ? Colors.green : activeColor,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.friendName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp,
                          decoration: entry.isSettled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Text(
                            typeLabel,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: activeColor,
                            ),
                          ),
                          Text(
                            " • ${DateFormat('MMM dd, yyyy').format(entry.dateLent)}",
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (entry.note.isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        Text(
                          entry.note,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.sp,
                        color: entry.isSettled
                            ? Colors.grey
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      entry.isSettled ? "Settled" : "Pending",
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: entry.isSettled ? Colors.green : activeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.1, end: 0, curve: Curves.easeOut);
  }
}
