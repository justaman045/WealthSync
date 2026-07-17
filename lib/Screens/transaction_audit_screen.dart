import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Controllers/audit_controller.dart';
import 'package:money_control/Models/audit_models.dart';
import 'package:money_control/Services/audit_service.dart';
import 'package:money_control/Components/colors.dart';

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
      backgroundColor: isDark ? const Color(0xFF0A0E21) : Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Transaction Audit',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18.sp,
          ),
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
                color: isDark ? Colors.white70 : Colors.grey[600], size: 20.sp),
            onPressed: () => _controller.runFullAudit(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFF00E5FF),
          unselectedLabelColor: isDark ? Colors.white54 : Colors.grey[500],
          indicatorColor: const Color(0xFF00E5FF),
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
                  color: Colors.greenAccent, size: 48.sp),
              SizedBox(height: 12.h),
              Text(
                'No issues found',
                style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey[600],
                    fontSize: 14.sp),
              ),
            ],
          ),
        );
      }
      return ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          if (dupes.isNotEmpty) ...[
            _sectionHeader('Duplicate Transactions (${dupes.length})', isDark),
            SizedBox(height: 8.h),
            ...dupes.map((g) => _duplicateCard(g, isDark)),
            SizedBox(height: 16.h),
          ],
          if (signs.isNotEmpty) ...[
            _sectionHeader('Sign Errors (${signs.length})', isDark),
            SizedBox(height: 8.h),
            ...signs.map((s) => _signErrorCard(s, isDark)),
          ],
          if (orphans.isNotEmpty) ...[
            _sectionHeader('Orphaned Recurring (${orphans.length})', isDark),
            SizedBox(height: 8.h),
            ...orphans.map((o) => _orphanCard(o, isDark)),
          ],
        ],
      );
    });
  }

  Widget _duplicateCard(DuplicateGroup group, bool isDark) {
    return Card(
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      margin: EdgeInsets.only(bottom: 8.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: Colors.orangeAccent.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.content_copy, color: Colors.orangeAccent, size: 16.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    '${group.merchant} — ${group.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.sp,
                    ),
                  ),
                ),
                Text(
                  '${group.transactions.length}×',
                  style: TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.sp),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            ...group.transactions.map((tx) => Padding(
                  padding: EdgeInsets.only(left: 24.w, top: 2.h),
                  child: Text(
                    '${tx.date.toIso8601String().substring(0, 16)} — ${tx.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey[600],
                        fontSize: 11.sp),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _signErrorCard(SignError error, bool isDark) {
    return Card(
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      margin: EdgeInsets.only(bottom: 8.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.redAccent, size: 16.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    error.transaction.recipientName.isNotEmpty
                        ? error.transaction.recipientName
                        : 'Unknown',
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.sp,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Padding(
              padding: EdgeInsets.only(left: 24.w),
              child: Text(
                'Expected: ${error.expected} | Got: ${error.actual}',
                style: TextStyle(
                    color: Colors.redAccent, fontSize: 11.sp),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 24.w, top: 2.h),
              child: Text(
                '${error.transaction.date.toIso8601String().substring(0, 10)} — ${error.transaction.amount.toStringAsFixed(2)}',
                style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey[600],
                    fontSize: 11.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orphanCard(OrphanedRecurring orphan, bool isDark) {
    return Card(
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      margin: EdgeInsets.only(bottom: 8.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: Colors.purpleAccent.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.replay_circle_filled, color: Colors.purpleAccent, size: 16.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    orphan.payment.title,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.sp,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Padding(
              padding: EdgeInsets.only(left: 24.w),
              child: Text(
                orphan.reason,
                style: TextStyle(
                    color: Colors.purpleAccent, fontSize: 11.sp),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 24.w, top: 2.h),
              child: Text(
                'Amount: ${orphan.payment.amount.toStringAsFixed(2)}',
                style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey[600],
                    fontSize: 11.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
                  color: isDark ? Colors.white24 : Colors.grey[400],
                  size: 48.sp),
              SizedBox(height: 12.h),
              Text(
                'No bank data imported',
                style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey[500],
                    fontSize: 13.sp),
              ),
              SizedBox(height: 16.h),
              ElevatedButton.icon(
                onPressed: () => controller.importBankCsv(),
                icon: Icon(Icons.upload_file, size: 16.sp),
                label: Text('Import Bank CSV',
                    style: TextStyle(fontSize: 13.sp)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
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
                _pill('Matched: ${matched.length}', Colors.greenAccent, isDark),
                SizedBox(width: 8.w),
                _pill('Bank-only: ${bankOnly.length}', Colors.orangeAccent, isDark),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => controller.importBankCsv(),
                  icon: Icon(Icons.upload_file,
                      size: 14.sp,
                      color: isDark ? Colors.white70 : Colors.grey[600]),
                  label: Text('Re-import',
                      style: TextStyle(
                          fontSize: 11.sp,
                          color: isDark ? Colors.white70 : Colors.grey[600])),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              children: [
                ...bankOnly.map((row) => _bankOnlyCard(row, isDark)),
              ],
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
          style: TextStyle(
              color: color, fontSize: 11.sp, fontWeight: FontWeight.w600)),
    );
  }

  Widget _bankOnlyCard(BankComparisonRow row, bool isDark) {
    return Card(
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      margin: EdgeInsets.only(bottom: 6.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(10.w),
        child: Text(
          row.bankRow.map((e) => e.toString()).join(' | '),
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.grey[700],
            fontSize: 11.sp,
            fontFamily: 'monospace',
          ),
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
            'No ledger entries',
            style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey[500],
                fontSize: 13.sp),
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
                  'Opening: ',
                  style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.grey[600],
                      fontSize: 12.sp),
                ),
                SizedBox(
                  width: 100.w,
                  height: 32.h,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 12.sp),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: TextStyle(
                          color: isDark ? Colors.white24 : Colors.grey[400],
                          fontSize: 12.sp),
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
                      const SnackBar(content: Text('Ledger copied to clipboard')),
                    );
                  },
                  icon: Icon(Icons.copy,
                      size: 14.sp,
                      color: isDark ? Colors.white70 : Colors.grey[600]),
                  label: Text('Export CSV',
                      style: TextStyle(
                          fontSize: 11.sp,
                          color: isDark ? Colors.white70 : Colors.grey[600])),
                ),
              ],
            ),
          ),
          Expanded(
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
                          style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.grey[500],
                              fontSize: 10.sp),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          e.description,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            fontSize: 11.sp,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          e.debit != null ? '-${e.debit!.toStringAsFixed(0)}' : '',
                          style: TextStyle(
                              color: Colors.redAccent, fontSize: 11.sp),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          e.credit != null ? '+${e.credit!.toStringAsFixed(0)}' : '',
                          style: TextStyle(
                              color: Colors.greenAccent, fontSize: 11.sp),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          e.runningBalance.toStringAsFixed(0),
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.grey[700],
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              },
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
                color: dupes > 0 ? Colors.orangeAccent : null),
            SizedBox(height: 8.h),
            _summaryCard('Sign Errors', '$signs',
                Icons.warning_amber_rounded, isDark,
                color: signs > 0 ? Colors.redAccent : null),
            SizedBox(height: 8.h),
            _summaryCard(
                'Total Debits', '-${totalDebit.toStringAsFixed(2)}',
                Icons.arrow_downward, isDark,
                color: Colors.redAccent),
            SizedBox(height: 8.h),
            _summaryCard(
                'Total Credits', '+${totalCredit.toStringAsFixed(2)}',
                Icons.arrow_upward, isDark,
                color: Colors.greenAccent),
            SizedBox(height: 16.h),
            _summaryCard(
                'Final Balance', finalBalance.toStringAsFixed(2),
                Icons.account_balance_wallet, isDark,
                color: const Color(0xFF00E5FF)),
          ],
        ),
      );
    });
  }

  Widget _summaryCard(String label, String value, IconData icon, bool isDark,
      {Color? color}) {
    final effectiveColor = color ?? (isDark ? Colors.white70 : Colors.grey[700]);
    return Card(
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
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
                style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey[600],
                    fontSize: 13.sp),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: effectiveColor,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _sectionHeader(String text, bool isDark) {
  return Text(
    text,
    style: TextStyle(
      color: isDark ? Colors.white : AppColors.lightTextPrimary,
      fontSize: 15.sp,
      fontWeight: FontWeight.w700,
    ),
  );
}
