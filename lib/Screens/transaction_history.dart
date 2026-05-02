import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart'; // Haptic Feedback
import 'package:flutter_animate/flutter_animate.dart'; // Animations
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Components/methods.dart';
import 'package:money_control/Screens/transaction_details.dart';
import 'package:money_control/Screens/sms_import_screen.dart';
import 'package:money_control/Components/empty_state.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/l10n/app_localizations.dart';
import 'package:money_control/Components/shimmer_loading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:money_control/Screens/edit_transaction.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:intl/intl.dart';

class TransactionHistoryScreen extends StatefulWidget {
  /// 0 = all, 1 = income, 2 = expense
  final int initialTab;
  /// When set, only transactions in this month/year are shown.
  final DateTime? filterMonth;
  const TransactionHistoryScreen({super.key, this.initialTab = 0, this.filterMonth});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  late int selectedTab;
  List<TransactionModel> _filteredTxs = [];
  Map<DateTime, List<TransactionModel>> _grouped = {};
  List<DateTime> _sections = [];
  Worker? _txWorker;

  @override
  void initState() {
    super.initState();
    selectedTab = widget.initialTab;
    final controller = Get.find<TransactionController>();
    _txWorker = ever(controller.transactions, (_) => _regroup());
    _regroup();
  }

  @override
  void dispose() {
    _txWorker?.dispose();
    super.dispose();
  }

  void _regroup() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final controller = Get.find<TransactionController>();
    final fm = widget.filterMonth;
    var txs = controller.transactions
        .where((tx) => tx.senderId == user.uid || tx.recipientId == user.uid);
    if (fm != null) {
      txs = txs.where((tx) => tx.date.year == fm.year && tx.date.month == fm.month);
    }
    final txsList = txs.toList();
    final filtered = selectedTab == 0
        ? txsList
        : selectedTab == 1
            ? txsList.where((tx) => tx.recipientId == user.uid).toList()
            : txsList.where((tx) => tx.senderId == user.uid).toList();
    final grouped = <DateTime, List<TransactionModel>>{};
    for (var tx in filtered) {
      final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      grouped.putIfAbsent(day, () => []).add(tx);
    }
    final sections = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    if (mounted) {
      setState(() {
        _filteredTxs = filtered;
        _grouped = grouped;
        _sections = sections;
      });
    }
  }

  String formatDateLabel(DateTime date, AppLocalizations l10n) {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final txDay = DateTime(date.year, date.month, date.day);

    final diff = today.difference(txDay).inDays;

    if (diff == 0) return l10n.today;
    if (diff == 1) return l10n.yesterday;

    return "${date.day} ${_monthAbbr(date.month)}";
  }

  String _monthAbbr(int month) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final colorIncome = AppColors.success;
    final colorOutcome = AppColors.error;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    final List<String> tabs = [l10n.tabAll, l10n.tabIncome, l10n.tabOutcome];

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

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
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            widget.filterMonth != null
                ? DateFormat('MMMM yyyy').format(widget.filterMonth!)
                : l10n.transactionHistoryTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 18.sp,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: theme.iconTheme.color,
              size: 20.sp,
            ),
            onPressed: () => goBack(),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.sms_rounded,
                color: theme.iconTheme.color,
                size: 24.sp,
              ),
              tooltip: l10n.importSmsTooltip,
              onPressed: () async {
                HapticFeedback.lightImpact();
                await Get.to(
                  () => const SmsImportScreen(),
                  transition: Transition.rightToLeftWithFade,
                );
              },
            ),
            SizedBox(width: 8.w),
          ],
        ),
        body: Obx(() {
          final TransactionController controller = Get.find();

          if (controller.isLoading.value && controller.transactions.isEmpty) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
              child: const TransactionListShimmer(),
            );
          }

          final filteredTxs = _filteredTxs;
          final grouped = _grouped;
          final sections = _sections;

          // Build flat list: alternating date-header items and tx items
          final flatItems = <({bool isHeader, DateTime? date, int sectionIdx, TransactionModel? tx})>[];
          for (int s = 0; s < sections.length; s++) {
            final date = sections[s];
            flatItems.add((isHeader: true, date: date, sectionIdx: s, tx: null));
            for (final tx in grouped[date]!) {
              flatItems.add((isHeader: false, date: null, sectionIdx: s, tx: tx));
            }
          }

          final tabSelector = Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: GlassContainer(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
                borderRadius: BorderRadius.circular(30.r),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(tabs.length, (i) {
                    final isSelected = i == selectedTab;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => selectedTab = i);
                        _regroup();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 10.h),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(30.r),
                        ),
                        child: Text(
                          tabs[i],
                          style: TextStyle(
                            color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                            fontWeight: FontWeight.w600,
                            fontSize: 14.sp,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          );

          return RefreshIndicator(
            color: AppColors.secondary,
            backgroundColor: theme.scaffoldBackgroundColor,
            onRefresh: () async {
              HapticFeedback.mediumImpact();
              await controller.refreshData();
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: SizedBox(height: 10.h)),
                SliverToBoxAdapter(child: tabSelector),
                SliverToBoxAdapter(child: SizedBox(height: 20.h)),
                if (filteredTxs.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: EmptyStateWidget(
                        title: l10n.noTransactions,
                        subtitle: l10n.noTransactionsSubtitle,
                        icon: Icons.receipt_long_outlined,
                        color: theme.disabledColor,
                      ),
                    ),
                  )
                else ...[
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final item = flatItems[i];
                          if (item.isHeader) {
                            final sectionDate = item.date!;
                            final label = formatDateLabel(sectionDate, l10n);
                            return Padding(
                              padding: EdgeInsets.only(bottom: 12.h, top: 10.h, left: 4.w),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    label,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16.sp,
                                    ),
                                  ),
                                  Text(
                                    "${sectionDate.day.toString().padLeft(2, '0')} "
                                    "${_monthAbbr(sectionDate.month)}, "
                                    "${sectionDate.year}",
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ).animate()
                              .fadeIn(duration: 400.ms, delay: (item.sectionIdx * 50).ms)
                              .slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
                          }
                          final tx = item.tx!;
                          final received = tx.recipientId == user.uid;
                          final amountColor = received ? colorIncome : colorOutcome;
                          return Padding(
                            padding: EdgeInsets.only(bottom: 12.h),
                            child: Slidable(
                              key: ValueKey(tx.id),
                              startActionPane: ActionPane(
                                motion: const ScrollMotion(),
                                extentRatio: 0.25,
                                children: [
                                  SlidableAction(
                                    onPressed: (context) {
                                      Get.to(() => TransactionEditScreen(transaction: tx));
                                    },
                                    backgroundColor: const Color(0xFF21B7CA),
                                    foregroundColor: Colors.white,
                                    icon: Icons.edit,
                                    label: 'Edit',
                                    borderRadius: BorderRadius.horizontal(left: Radius.circular(20.r)),
                                  ),
                                ],
                              ),
                              endActionPane: ActionPane(
                                motion: const ScrollMotion(),
                                extentRatio: 0.25,
                                children: [
                                  SlidableAction(
                                    onPressed: (context) => _confirmDelete(context, tx),
                                    backgroundColor: const Color(0xFFFE4A49),
                                    foregroundColor: Colors.white,
                                    icon: Icons.delete,
                                    label: 'Delete',
                                    borderRadius: BorderRadius.horizontal(right: Radius.circular(20.r)),
                                  ),
                                ],
                              ),
                              child: GlassContainer(
                                onTap: () {
                                  Get.to(
                                    () => TransactionResultScreen(
                                      type: getTransactionTypeFromStatus(tx.status),
                                      transaction: tx,
                                    ),
                                    curve: curve,
                                    transition: transition,
                                    duration: duration,
                                  );
                                },
                                padding: EdgeInsets.all(16.w),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(10.w),
                                      decoration: BoxDecoration(
                                        color: amountColor.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        received ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                        color: amountColor,
                                        size: 20.sp,
                                      ),
                                    ),
                                    SizedBox(width: 16.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tx.recipientName.isEmpty ? l10n.unknownRecipient : tx.recipientName,
                                            style: theme.textTheme.bodyLarge?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16.sp,
                                            ),
                                          ),
                                          SizedBox(height: 4.h),
                                          Text(
                                            tx.category ?? l10n.uncategorized,
                                            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13.sp),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${received ? '+' : '-'}${CurrencyController.to.currencySymbol.value}${tx.amount.abs().toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: amountColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17.sp,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: flatItems.length,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: 20.h)),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, TransactionModel tx) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(l10n.delete),
        content: const Text(
          "Are you sure you want to delete this transaction?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // ignore: use_build_context_synchronously
      if (!context.mounted) return;
      final ctrl = Get.find<TransactionController>();
      await ctrl.deleteTransaction(tx);
    }
  }
}
