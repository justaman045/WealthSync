import 'package:money_control/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/feature_gate.dart';
import 'package:money_control/Components/tx_tile.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Models/cateogary.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Screens/category_management.dart';
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
  bool _showIgnored = false;

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
          style: AppType.titleMedium(isDark ? Colors.white : AppColors.lightTextPrimary),
        ),
      ),
      body: SafeArea(
          child: user == null
              ? Center(child: Text(AppLocalizations.of(context)!.userLogged))
              : Obx(() {
                  final split = splitMonthlyExpenses(
                    _controller.transactions,
                    uid: user.uid,
                    month: now,
                    treatmentOverrides:
                        buildTreatmentOverrides(_controller.categories),
                  );
                  final sym = CurrencyController.to.currencySymbol.value;
                  final discretionary = split.discretionary;
                  final fixed = split.fixed;
                  final ignored = split.ignored;

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
                          SizedBox(height: 12.h),
                          _customizeLink(context, isDark: isDark),
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
                          SizedBox(height: 12.h),
                          _ignoredToggle(
                            isDark: isDark,
                            sym: sym,
                            count: ignored.length,
                            total: split.ignoredTotal,
                          ),
                          if (_showIgnored) ...[
                            SizedBox(height: 6.h),
                            _sectionTitle(
                              "Ignored (not counted in limit)",
                              isDark: isDark,
                            ),
                            SizedBox(height: 10.h),
                            if (ignored.isEmpty)
                              _emptyCard(
                                isDark: isDark,
                                message:
                                    "No ignored categories this month. Mark a "
                                    "category as \"Ignore in limit\" to keep "
                                    "investments/SIPs out of your daily limit.",
                              )
                            else
                              ...ignored.map(
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
            AppLocalizations.of(context)!.spentOtherItems,
            style: AppType.bodySmall(isDark ? Colors.white70 : AppColors.lightTextTertiary),
          ),
          SizedBox(height: 4.h),
          Text(
            "$sym${total.toStringAsFixed(0)}",
            style: AppType.headlineMedium(isDark ? Colors.white : AppColors.lightTextPrimary),
          ),
          SizedBox(height: 2.h),
          Text(
            "$count transaction${count == 1 ? '' : 's'} this month",
            style: AppType.bodySmall(isDark ? Colors.white54 : AppColors.lightTextTertiary),
          ),
          SizedBox(height: 12.h),
          Text(
            AppLocalizations.of(context)!.theseNonBillExpensesRent,
            style: AppType.bodySmall(isDark ? Colors.white70 : AppColors.lightTextTertiary),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, {required bool isDark}) {
    return Text(
      text,
      style: AppType.labelLarge(isDark ? Colors.white : AppColors.lightTextPrimary),
    );
  }

  Widget _bucketToggle({
    required bool isDark,
    required String sym,
    required int count,
    required double total,
    required String label,
    required IconData icon,
    required bool expanded,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16.r),
      onTap: onTap,
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
              icon,
              size: 20.sp,
              color: isDark ? Colors.white60 : AppColors.lightTextTertiary,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                "$label ($count)",
                style: AppType.labelMedium(isDark ? Colors.white : AppColors.lightTextPrimary),
              ),
            ),
            Text(
              "$sym${total.toStringAsFixed(0)}",
              style: AppType.labelMedium(isDark ? Colors.white70 : AppColors.lightTextTertiary),
            ),
            SizedBox(width: 6.w),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 20.sp,
              color: isDark ? Colors.white60 : AppColors.lightTextTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _excludedToggle({
    required bool isDark,
    required String sym,
    required int count,
    required double total,
  }) {
    return _bucketToggle(
      isDark: isDark,
      sym: sym,
      count: count,
      total: total,
      label: "Excluded: bills & fixed",
      icon: Icons.receipt_long_rounded,
      expanded: _showExcluded,
      onTap: () => setState(() => _showExcluded = !_showExcluded),
    );
  }

  Widget _ignoredToggle({
    required bool isDark,
    required String sym,
    required int count,
    required double total,
  }) {
    return _bucketToggle(
      isDark: isDark,
      sym: sym,
      count: count,
      total: total,
      label: "Ignored: not counted in limit",
      icon: Icons.visibility_off_rounded,
      expanded: _showIgnored,
      onTap: () => setState(() => _showIgnored = !_showIgnored),
    );
  }

  Widget _customizeLink(BuildContext context, {required bool isDark}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () {
          if (!ensureFeatureVisible(context, 'category')) return;
          Get.to(() => const CategoryManagementScreen());
        },
        icon: Icon(
          Icons.tune,
          size: 18.sp,
          color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
        ),
        label: Text(
          AppLocalizations.of(context)!.customizeWhichCategoriesCount,
          style: AppType.bodySmall(isDark ? Colors.white70 : AppColors.lightTextSecondary),
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
        style: AppType.bodySmall(isDark ? Colors.white60 : AppColors.lightTextTertiary),
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
