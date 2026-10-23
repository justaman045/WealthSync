import 'package:money_control/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Controllers/audit_controller.dart';
import 'package:money_control/Models/audit_models.dart';
import 'package:money_control/Services/audit_service.dart';
import 'package:money_control/Components/feature_gate.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Utils/responsive.dart';
import 'package:money_control/Screens/edit_transaction.dart';
import 'package:money_control/Models/transaction.dart';

class TransactionAuditScreen extends StatefulWidget {
  const TransactionAuditScreen({super.key});

  @override
  State<TransactionAuditScreen> createState() => _TransactionAuditScreenState();
}

class _TransactionAuditScreenState extends State<TransactionAuditScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final AuditController _controller;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    if (!Get.isRegistered<AuditController>()) {
      Get.put(AuditController());
    }
    _controller = Get.find<AuditController>();
    _controller.runFullAudit();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.transactionAudit,
          style: AppType.titleMedium(isDark ? Colors.white : AppColors.lightTextPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: isDark ? Colors.white : AppColors.lightTextPrimary, size: 20.sp),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, size: 20.sp),
            onPressed: () => _controller.runFullAudit(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextTertiary,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Issues'),
            Tab(text: 'Bank Compare'),
            Tab(text: 'Ledger'),
            Tab(text: 'Summary'),
          ],
        ),
      ),
      body: Obx(() {
        if (_controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return TabBarView(
          controller: _tabController,
          children: [
            _IssuesTab(controller: _controller, isDark: isDark),
            _BankCompareTab(controller: _controller, isDark: isDark),
            _LedgerTab(controller: _controller, isDark: isDark),
            _SummaryTab(controller: _controller, isDark: isDark),
          ],
        );
      }),
    );
  }
}

class _IssuesTab extends StatelessWidget {
  final AuditController controller;
  final bool isDark;

  const _IssuesTab({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final dupes = controller.duplicateGroups;
      final signs = controller.signErrors;
      final orphans = controller.orphanedRecurring;
      if (dupes.isEmpty && signs.isEmpty && orphans.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline,
                  color: AppColors.success, size: 48.sp),
              SizedBox(height: 12.h),
              Text(
                AppLocalizations.of(context)!.issuesFound,
                style: AppType.bodyMedium(isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ],
          ),
        );
      }
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
          child: ListView(
            padding: EdgeInsets.all(16.w),
        children: [
          if (dupes.isNotEmpty) ...[
            _sectionHeader('Duplicate Transactions (${dupes.length})', isDark),
            SizedBox(height: 8.h),
            ...dupes.map((g) => _duplicateCard(context, g, isDark)),
            SizedBox(height: 16.h),
          ],
          if (signs.isNotEmpty) ...[
            _sectionHeader('Sign Errors (${signs.length})', isDark),
            SizedBox(height: 8.h),
            ...signs.map((s) => _signErrorCard(context, s, isDark)),
          ],
          if (orphans.isNotEmpty) ...[
            _sectionHeader('Orphaned Recurring (${orphans.length})', isDark),
            SizedBox(height: 8.h),
            ...orphans.map((o) => _orphanCard(context, o, isDark)),
          ],
            ],
          ),
        ),
      );
    });
  }

  Widget _duplicateCard(BuildContext context, DuplicateGroup group, bool isDark) {
    return GestureDetector(
      onTap: () => _showDuplicateResolutionSheet(context, group, isDark),
      child: Card(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        margin: EdgeInsets.only(bottom: 8.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
          side: BorderSide(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.content_copy, color: AppColors.warning, size: 16.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      '${group.merchant} — ${group.amount.toStringAsFixed(2)}',
                      style: AppType.labelMedium(isDark ? Colors.white : AppColors.lightTextPrimary),
                    ),
                  ),
                  Text(
                    '${group.transactions.length}×',
                    style: AppType.labelMedium(AppColors.warning),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              ...group.transactions.map((tx) => Padding(
                    padding: EdgeInsets.only(left: 24.w, top: 2.h),
                    child: Text(
                      '${tx.date.toIso8601String().substring(0, 16)} — ${tx.amount.toStringAsFixed(2)}',
                      style: AppType.labelSmall(isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    ),
                  )),
              SizedBox(height: 6.h),
              Row(
                children: [
                  Icon(Icons.touch_app, size: 12.sp, color: AppColors.warning.withValues(alpha: 0.6)),
                  SizedBox(width: 4.w),
                  Text(
                    AppLocalizations.of(context)!.tapResolve,
                    style: TextStyle(
                      color: AppColors.warning.withValues(alpha: 0.6),
                      fontSize: 10.sp,
                      fontStyle: FontStyle.italic,
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

  Widget _signErrorCard(BuildContext context, SignError error, bool isDark) {
    return GestureDetector(
      onTap: () => _showSignErrorResolutionSheet(context, error, isDark),
      child: Card(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        margin: EdgeInsets.only(bottom: 8.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
          side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: AppColors.error, size: 16.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      error.transaction.recipientName.isNotEmpty
                          ? error.transaction.recipientName
                          : 'Unknown',
                      style: AppType.labelMedium(isDark ? Colors.white : AppColors.lightTextPrimary),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              Padding(
                padding: EdgeInsets.only(left: 24.w),
                child: Text(
                  'Expected: ${error.expected} | Got: ${error.actual}',
                  style: AppType.labelSmall(AppColors.error),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: 24.w, top: 2.h),
                child: Text(
                  '${error.transaction.date.toIso8601String().substring(0, 10)} — ${error.transaction.amount.toStringAsFixed(2)}',
                  style: AppType.labelSmall(isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
              ),
              SizedBox(height: 6.h),
              Row(
                children: [
                  Icon(Icons.touch_app, size: 12.sp, color: AppColors.error.withValues(alpha: 0.6)),
                  SizedBox(width: 4.w),
                  Text(
                    AppLocalizations.of(context)!.tapResolve,
                    style: TextStyle(
                      color: AppColors.error.withValues(alpha: 0.6),
                      fontSize: 10.sp,
                      fontStyle: FontStyle.italic,
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

  Widget _orphanCard(BuildContext context, OrphanedRecurring orphan, bool isDark) {
    return GestureDetector(
      onTap: () => _showOrphanResolutionSheet(context, orphan, isDark),
      child: Card(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        margin: EdgeInsets.only(bottom: 8.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
          side: BorderSide(color: AppColors.accent.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.replay_circle_filled, color: AppColors.accent, size: 16.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      orphan.payment.title,
                      style: AppType.labelMedium(isDark ? Colors.white : AppColors.lightTextPrimary),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              Padding(
                padding: EdgeInsets.only(left: 24.w),
                child: Text(
                  orphan.reason,
                  style: AppType.labelSmall(AppColors.accent),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: 24.w, top: 2.h),
                child: Text(
                  'Amount: ${orphan.payment.amount.toStringAsFixed(2)}',
                  style: AppType.labelSmall(isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
              ),
              SizedBox(height: 6.h),
              Row(
                children: [
                  Icon(Icons.touch_app, size: 12.sp, color: AppColors.accent.withValues(alpha: 0.6)),
                  SizedBox(width: 4.w),
                  Text(
                    AppLocalizations.of(context)!.tapResolve,
                    style: TextStyle(
                      color: AppColors.accent.withValues(alpha: 0.6),
                      fontSize: 10.sp,
                      fontStyle: FontStyle.italic,
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

  // ---------------------------------------------------------------------------
  // Resolution Bottom Sheets
  // ---------------------------------------------------------------------------

  void _showDuplicateResolutionSheet(BuildContext context, DuplicateGroup group, bool isDark) {
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.lightTextPrimary;
    final subtextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    showModalBottomSheet(
      context: context,
      constraints: BoxConstraints(maxWidth: Responsive.sheetMaxWidth(context)),
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Icon(Icons.content_copy, color: AppColors.warning, size: 20.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.duplicateTransaction,
                      style: AppType.titleMedium(textColor),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                '${group.transactions.length} transactions for "${group.merchant}" on the same day, each ${group.amount.toStringAsFixed(2)}.',
                style: AppType.bodySmall(subtextColor),
              ),
              SizedBox(height: 6.h),
              ...group.transactions.asMap().entries.map((entry) {
                final tx = entry.value;
                return Padding(
                  padding: EdgeInsets.only(left: 8.w, top: 4.h),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 6.sp, color: AppColors.warning),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          '${tx.date.toIso8601String().substring(0, 16)} — ${tx.amount.toStringAsFixed(2)}',
                          style: AppType.labelSmall(subtextColor),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              SizedBox(height: 16.h),
              _resolutionButton(
                context: sheetContext,
                icon: Icons.check_circle_outline,
                label: 'Keep newest, delete others',
                color: AppColors.primary,
                isDark: isDark,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final newestIdx = 0;
                  final deleted = await controller.resolveDuplicate(group, keepIndex: newestIdx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Removed $deleted duplicate(s)'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                      ),
                    );
                  }
                },
              ),
              SizedBox(height: 8.h),
              _resolutionButton(
                context: sheetContext,
                icon: Icons.history,
                label: 'Keep oldest, delete others',
                color: AppColors.warning,
                isDark: isDark,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final oldestIdx = group.transactions.length - 1;
                  final deleted = await controller.resolveDuplicate(group, keepIndex: oldestIdx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Removed $deleted duplicate(s)'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                      ),
                    );
                  }
                },
              ),
              SizedBox(height: 8.h),
              _resolutionButton(
                context: sheetContext,
                icon: Icons.delete_sweep_outlined,
                label: 'Delete all in this group',
                color: AppColors.error,
                isDark: isDark,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final confirmed = await _confirmDestructive(
                    context,
                    title: 'Delete all duplicates?',
                    message: 'This will delete all ${group.transactions.length} transactions for "${group.merchant}". This action cannot be undone.',
                    isDark: isDark,
                  );
                  if (confirmed && context.mounted) {
                    final deleted = await controller.resolveDuplicate(group, keepIndex: -1);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Deleted $deleted transaction(s)'),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                        ),
                      );
                    }
                  }
                },
              ),
              SizedBox(height: 8.h),
              _resolutionButton(
                context: sheetContext,
                icon: Icons.close,
                label: 'Dismiss',
                color: subtextColor,
                isDark: isDark,
                onTap: () {
                  Navigator.pop(sheetContext);
                  controller.dismissIssue(group.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSignErrorResolutionSheet(BuildContext context, SignError error, bool isDark) {
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.lightTextPrimary;
    final subtextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final tx = error.transaction;

    showModalBottomSheet(
      context: context,
      constraints: BoxConstraints(maxWidth: Responsive.sheetMaxWidth(context)),
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.signConventionError,
                      style: AppType.titleMedium(textColor),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                '${tx.recipientName.isNotEmpty ? tx.recipientName : "Unknown"} — ${tx.amount.toStringAsFixed(2)} on ${tx.date.toIso8601String().substring(0, 10)}',
                style: AppType.bodySmall(subtextColor),
              ),
              SizedBox(height: 4.h),
              Text(
                'Expected: ${error.expected}  •  Got: ${error.actual}',
                style: AppType.labelSmall(AppColors.error),
              ),
              SizedBox(height: 16.h),
              _resolutionButton(
                context: sheetContext,
                icon: Icons.auto_fix_high,
                label: 'Auto-correct sign (flip to ${error.expected})',
                color: AppColors.primary,
                isDark: isDark,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final ok = await controller.resolveSignError(error);
                  if (context.mounted && ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context)!.signCorrected),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                      ),
                    );
                  }
                },
              ),
              SizedBox(height: 8.h),
              _resolutionButton(
                context: sheetContext,
                icon: Icons.edit_outlined,
                label: 'Edit transaction manually',
                color: AppColors.warning,
                isDark: isDark,
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (!ensureFeatureVisible(sheetContext, 'transactions')) {
                    return;
                  }
                  Get.to(() => _EditTransactionProxy(transaction: tx));
                },
              ),
              SizedBox(height: 8.h),
              _resolutionButton(
                context: sheetContext,
                icon: Icons.close,
                label: 'Dismiss',
                color: subtextColor,
                isDark: isDark,
                onTap: () {
                  Navigator.pop(sheetContext);
                  controller.dismissIssue(error.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showOrphanResolutionSheet(BuildContext context, OrphanedRecurring orphan, bool isDark) {
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.lightTextPrimary;
    final subtextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final pmt = orphan.payment;

    showModalBottomSheet(
      context: context,
      constraints: BoxConstraints(maxWidth: Responsive.sheetMaxWidth(context)),
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Icon(Icons.replay_circle_filled, color: AppColors.accent, size: 20.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.missingRecurringPayment,
                      style: AppType.titleMedium(textColor),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                '"${pmt.title}" was due on ${pmt.nextDueDate.toIso8601String().substring(0, 10)}, but no transaction was found.',
                style: AppType.bodySmall(subtextColor),
              ),
              SizedBox(height: 4.h),
              Text(
                'Amount: ${pmt.amount.toStringAsFixed(2)}  •  Category: ${pmt.category}',
                style: AppType.labelSmall(subtextColor),
              ),
              SizedBox(height: 16.h),
              _resolutionButton(
                context: sheetContext,
                icon: Icons.add_circle_outline,
                label: 'Create missing transaction & advance due date',
                color: AppColors.primary,
                isDark: isDark,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final ok = await controller.resolveOrphan(orphan);
                  if (context.mounted && ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Created transaction for "${pmt.title}"'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                      ),
                    );
                  }
                },
              ),
              SizedBox(height: 8.h),
              _resolutionButton(
                context: sheetContext,
                icon: Icons.skip_next,
                label: 'Skip this cycle (advance due date only)',
                color: AppColors.warning,
                isDark: isDark,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final ok = await controller.skipOrphan(orphan);
                  if (context.mounted && ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Skipped cycle for "${pmt.title}"'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                      ),
                    );
                  }
                },
              ),
              SizedBox(height: 8.h),
              _resolutionButton(
                context: sheetContext,
                icon: Icons.close,
                label: 'Dismiss',
                color: subtextColor,
                isDark: isDark,
                onTap: () {
                  Navigator.pop(sheetContext);
                  controller.dismissIssue(orphan.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Shared resolution helpers
// ---------------------------------------------------------------------------

Widget _resolutionButton({
  required BuildContext context,
  required IconData icon,
  required String label,
  required Color color,
  required bool isDark,
  required VoidCallback onTap,
}) {
  return SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 18.sp),
      label: Text(
        label,
        style: AppType.labelMedium(color),
      ),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
      ),
    ),
  );
}

Future<bool> _confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required bool isDark,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      title: Text(title, style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary)),
      content: Text(message, style: AppType.bodySmall(isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(false),
          child: Text(AppLocalizations.of(context)!.cancel, style: TextStyle(color: Colors.grey[500])),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
          child: const Text('Delete', style: TextStyle(color: AppColors.error)),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _BankCompareTab extends StatelessWidget {
  final AuditController controller;
  final bool isDark;

  const _BankCompareTab({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final matched = controller.bankMatched;
      final bankOnly = controller.bankOnlyRows;
      if (matched.isEmpty && bankOnly.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_balance,
                  color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                  size: 48.sp),
              SizedBox(height: 12.h),
              Text(
                AppLocalizations.of(context)!.bankDataImported,
                style: AppType.bodySmall(isDark ? AppColors.darkTextSecondary : AppColors.lightTextTertiary),
              ),
              SizedBox(height: 16.h),
              ElevatedButton.icon(
                onPressed: () => controller.importBankCsv(),
                icon: Icon(Icons.upload_file, size: 16.sp),
                label: Text(AppLocalizations.of(context)!.importBankCSV,
                    style: TextStyle(fontSize: 13.sp)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Row(
              children: [
                _pill('Matched: ${matched.length}', AppColors.success, isDark),
                SizedBox(width: 8.w),
                _pill('Bank-only: ${bankOnly.length}', AppColors.warning, isDark),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => controller.importBankCsv(),
                  icon: Icon(Icons.upload_file,
                      size: 14.sp,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  label: Text(AppLocalizations.of(context)!.reImport,
                      style: AppType.labelSmall(isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
                child: ListView(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
              children: [
                ...bankOnly.map((row) => _bankOnlyCard(row, isDark)),
              ],
            ),
          ),
        ),
      ),
    ],
  );
    });
  }

  Widget _pill(String label, Color color, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(label,
          style: AppType.labelSmall(color)),
    );
  }

  Widget _bankOnlyCard(BankComparisonRow row, bool isDark) {
    return Card(
      color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
      margin: EdgeInsets.only(bottom: 6.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(10.w),
        child: Text(
          row.bankRow.map((e) => e.toString()).join(' | '),
          style: AppType.labelSmall(isDark ? AppColors.darkTextPrimary : AppColors.lightTextSecondary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _LedgerTab extends StatelessWidget {
  final AuditController controller;
  final bool isDark;

  const _LedgerTab({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final entries = controller.ledgerEntries;
      if (entries.isEmpty) {
        return Center(
          child: Text(
            AppLocalizations.of(context)!.ledgerEntries,
            style: AppType.bodySmall(isDark ? AppColors.darkTextSecondary : AppColors.lightTextTertiary),
          ),
        );
      }
      return Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Row(
              children: [
                Text(
                  AppLocalizations.of(context)!.opening,
                  style: AppType.bodySmall(isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
                SizedBox(
                  width: 100.w,
                  height: 32.h,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    style: AppType.bodySmall(isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: AppType.bodySmall(isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(
                            color: isDark ? Colors.white24 : Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(
                            color: isDark ? Colors.white24 : Colors.grey[300]!),
                      ),
                    ),
                    onChanged: (v) {
                      final val = double.tryParse(v) ?? 0;
                      controller.updateOpeningBalance(val);
                    },
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    final csv = AuditService.exportLedgerCsv(entries);
                    Clipboard.setData(ClipboardData(text: csv));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.of(context)!.ledgerCopiedClipboard)),
                    );
                  },
                  icon: Icon(Icons.copy,
                      size: 14.sp,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  label: Text(AppLocalizations.of(context)!.exportCSV,
                      style: AppType.labelSmall(isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final e = entries[i];
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                          color: (isDark ? Colors.white10 : Colors.grey[200])!),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 70.w,
                        child: Text(
                          e.date.toIso8601String().substring(5, 10),
                          style: AppType.labelSmall(isDark ? AppColors.darkTextSecondary : AppColors.lightTextTertiary),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          e.description,
                          style: AppType.labelSmall(isDark ? Colors.white : AppColors.lightTextPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          e.debit != null ? '-${e.debit!.toStringAsFixed(0)}' : '',
                          style: AppType.labelSmall(AppColors.error),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          e.credit != null ? '+${e.credit!.toStringAsFixed(0)}' : '',
                          style: AppType.labelSmall(AppColors.success),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          e.runningBalance.toStringAsFixed(0),
                          style: AppType.labelSmall(isDark ? AppColors.darkTextPrimary : AppColors.lightTextSecondary),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ],
  );
    });
  }
}

class _SummaryTab extends StatelessWidget {
  final AuditController controller;
  final bool isDark;

  const _SummaryTab({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final totalTx = controller.ledgerEntries.length;
      final dupes = controller.duplicateGroups.length;
      final signs = controller.signErrors.length;
      final totalDebit = controller.ledgerEntries
          .where((e) => e.debit != null)
          .fold(0.0, (sum, e) => sum + e.debit!);
      final totalCredit = controller.ledgerEntries
          .where((e) => e.credit != null)
          .fold(0.0, (sum, e) => sum + e.credit!);
      final finalBalance = controller.ledgerEntries.isNotEmpty
          ? controller.ledgerEntries.last.runningBalance
          : 0.0;

      return Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            _summaryCard('Total Transactions', '$totalTx',
                Icons.receipt_long, isDark),
            SizedBox(height: 8.h),
            _summaryCard('Duplicate Groups', '$dupes',
                Icons.content_copy, isDark,
                color: dupes > 0 ? AppColors.warning : null),
            SizedBox(height: 8.h),
            _summaryCard('Sign Errors', '$signs',
                Icons.warning_amber_rounded, isDark,
                color: signs > 0 ? AppColors.error : null),
            SizedBox(height: 8.h),
            _summaryCard(
                'Total Debits', '-${totalDebit.toStringAsFixed(2)}',
                Icons.arrow_downward, isDark,
                color: AppColors.error),
            SizedBox(height: 8.h),
            _summaryCard(
                'Total Credits', '+${totalCredit.toStringAsFixed(2)}',
                Icons.arrow_upward, isDark,
                color: AppColors.success),
            SizedBox(height: 16.h),
            _summaryCard(
                'Final Balance', finalBalance.toStringAsFixed(2),
                Icons.account_balance_wallet, isDark,
                color: AppColors.primary),
          ],
        ),
      );
    });
  }

  Widget _summaryCard(String label, String value, IconData icon, bool isDark,
      {Color? color}) {
    final effectiveColor =
        color ??
        (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);
    return Card(
      color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Icon(icon, color: effectiveColor, size: 20.sp),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                label,
                style: AppType.bodySmall(isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ),
            Text(
              value,
              style: AppType.labelLarge(effectiveColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditTransactionProxy extends StatelessWidget {
  final TransactionModel transaction;
  const _EditTransactionProxy({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return TransactionEditScreen(transaction: transaction);
  }
}

Widget _sectionHeader(String text, bool isDark) {
  return Text(
    text,
    style: AppType.labelLarge(isDark ? Colors.white : AppColors.lightTextPrimary),
  );
}
