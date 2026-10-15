import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/tx_tile.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Utils/responsive.dart';
import 'package:money_control/Utils/spending_filter.dart';

/// Lists the transactions that make up the AI daily limit's "spent … on other
/// items" figure — this month's discretionary expenses (everything that is not
/// classified as a fixed bill/EMI/rent/subscription). The fixed expenses are
/// shown separately (collapsed) so it is explicit which transactions count
/// toward the daily limit and which do not.
class OtherItemsScreen extends StatefulWidget {
  const OtherItemsScreen({super.key});

  @override
  State<OtherItemsScreen> createState() => _OtherItemsScreenState();
}

class _OtherItemsScreenState extends State<OtherItemsScreen> {
  late final TransactionController _controller;
  bool _showExcluded = false;

  @override
  void initState() {
    super.initState();
    // Controllers are not registered when a field initializer runs.
    if (!Get.isRegistered<TransactionController>()) {
      Get.put(TransactionController());
    }
    _controller = Get.find<TransactionController>();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          "Other items · ${DateFormat('MMMM yyyy').format(now)}",
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
      ),
      body: SafeArea(
          child: user == null
              ? const Center(child: Text("User not logged in"))
              : Obx(() {
                  final split = splitMonthlyExpenses(
                    _controller.transactions,
                    uid: user.uid,
                    month: now,
                  );
                  final sym = CurrencyController.to.currencySymbol.value;
                  final discretionary = split.discretionary;
                  final fixed = split.fixed;

                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: Responsive.contentMaxWidth(context),
                      ),
                      child: ListView(
                        padding:
                            EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 30.h),
                        children: [
                          _summaryCard(
                            isDark: isDark,
                            sym: sym,
                            total: split.discretionaryTotal,
                            count: split.discretionaryCount,
                          ),
                          SizedBox(height: 20.h),
                          _sectionTitle(
                            "Counted as other items",
                            isDark: isDark,
                          ),
                          SizedBox(height: 10.h),
                          if (discretionary.isEmpty)
                            _emptyCard(
                              isDark: isDark,
                              message:
                                  "No other items this month. Every expense so "
                                  "far is a fixed bill or EMI.",
                            )
                          else
                            ...discretionary.map(
                              (tx) => _txCard(tx, isDark: isDark, dimmed: false),
                            ),
                          SizedBox(height: 12.h),
                          _excludedToggle(
                            isDark: isDark,
                            sym: sym,
                            count: fixed.length,
                            total: split.fixedTotal,
                          ),
                          if (_showExcluded) ...[
                            SizedBox(height: 6.h),
                            _sectionTitle(
                              "Excluded (bills & fixed)",
                              isDark: isDark,
                            ),
                            SizedBox(height: 10.h),
                            if (fixed.isEmpty)
                              _emptyCard(
                                isDark: isDark,
                                message:
                                    "No fixed bills recorded this month yet.",
                              )
                            else
                              ...fixed.map(
                                (tx) =>
                                    _txCard(tx, isDark: isDark, dimmed: true),
                              ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
      ),
    );
  }

  Widget _summaryCard({
    required bool isDark,
    required String sym,
    required double total,
    required int count,
  }) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Spent on other items",
            style: TextStyle(
              fontSize: 13.sp,
              color: isDark ? Colors.white70 : AppColors.lightTextTertiary,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            "$sym${total.toStringAsFixed(0)}",
            style: TextStyle(
              fontSize: 28.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            "$count transaction${count == 1 ? '' : 's'} this month",
            style: TextStyle(
              fontSize: 12.sp,
              color: isDark ? Colors.white54 : AppColors.lightTextTertiary,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            "These are your non-bill expenses. Rent, EMIs, bills, "
            "subscriptions and other fixed payments are excluded — open the "
            "excluded list below to see them.",
            style: TextStyle(
              fontSize: 12.sp,
              height: 1.35,
              color: isDark ? Colors.white70 : AppColors.lightTextTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, {required bool isDark}) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15.sp,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : AppColors.lightTextPrimary,
      ),
    );
  }

  Widget _excludedToggle({
    required bool isDark,
    required String sym,
    required int count,
    required double total,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16.r),
      onTap: () => setState(() => _showExcluded = !_showExcluded),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : AppColors.lightSurfaceCard,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 20.sp,
              color: isDark ? Colors.white60 : AppColors.lightTextTertiary,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                "Excluded: bills & fixed ($count)",
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
            ),
            Text(
              "$sym${total.toStringAsFixed(0)}",
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : AppColors.lightTextTertiary,
              ),
            ),
            SizedBox(width: 6.w),
            Icon(
              _showExcluded ? Icons.expand_less : Icons.expand_more,
              size: 20.sp,
              color: isDark ? Colors.white60 : AppColors.lightTextTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard({required bool isDark, required String message}) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.lightBorder,
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 13.sp,
          color: isDark ? Colors.white60 : AppColors.lightTextTertiary,
        ),
      ),
    );
  }

  Widget _txCard(
    TransactionModel tx, {
    required bool isDark,
    required bool dimmed,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    final received = tx.recipientId == user?.uid;
    return Opacity(
      opacity: dimmed ? 0.65 : 1.0,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : AppColors.lightSurfaceCard,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : AppColors.lightBorder,
          ),
        ),
        child: TxTile(
          tx: tx,
          received: received,
          textColor: isDark ? Colors.white : AppColors.lightTextPrimary,
          receivedColor: AppColors.success,
          sentColor: AppColors.error,
        ),
      ),
    );
  }
}
