import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore, Timestamp;
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Screens/about_application.dart';
import 'package:money_control/Screens/feedback_form.dart';
import 'package:money_control/Screens/terms_and_policy.dart';
import 'package:money_control/Services/local_backup_service.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Screens/import_screen.dart';
import 'package:money_control/Screens/transaction_audit_screen.dart';

class DataSupportSettingsScreen extends StatelessWidget {
  const DataSupportSettingsScreen({super.key});

  Future<void> _handleBackup(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;

    final nav = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await LocalBackupService.backupUserTransactions(user!.email!);

      if (!context.mounted) return;
      nav.pop();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Data backed up securely"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      nav.pop();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Backup failed: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleRestore(BuildContext context) async {
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    if (userEmail == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Restore Data"),
        content: const Text(
            "This handles restoring from local cache. Overwrite current data?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Restore"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await LocalBackupService.restoreUserTransactions(userEmail);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Data restored from backup"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Restore failed: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleGdprExport(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;

    const collections = [
      'transactions', 'categories', 'budgets', 'goals', 'loans', 'challenges',
      'lent_money', 'recurring_payments', 'sms_rules', 'category_rules',
      'fd_accounts', 'ppf_accounts', 'post_office_schemes', 'bonds', 'chit_funds',
      'stock_holdings', 'sip_holdings', 'etf_holdings', 'foreign_stocks',
      'startup_investments', 'pf_accounts', 'vpf_accounts', 'nps_accounts',
      'gold_holdings', 'sgb_holdings', 'jewelry_items', 'crypto_holdings',
      'reit_holdings', 'p2p_loans', 'agri_land', 'properties', 'vehicles',
      'insurance_policies', 'business_assets', 'bnpl_entries', 'credit_cards',
    ];

    final nav = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    bool dialogClosed = false;

    try {
      final data = <String, dynamic>{};
      data['exported_at'] = DateTime.now().toUtc().toIso8601String();
      data['user_email'] = user!.email;

      // Fetch wealth portfolio document
      final wealthDoc = await FirebaseFirestore.instance
          .doc('users/${user.email}/wealth/portfolio')
          .get();
      data['wealth_portfolio'] = wealthDoc.exists ? wealthDoc.data() : null;

      // Fetch all subcollections
      for (final col in collections) {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.email)
            .collection(col)
            .get();
        data[col] = snap.docs.map((d) {
          final m = d.data();
          m['_id'] = d.id;
          return m;
        }).toList();
      }

      // Serialize with Timestamp handling
      final json = jsonEncode(data, toEncodable: (o) {
        if (o is Timestamp) return o.toDate().toIso8601String();
        return o.toString();
      });
      final bytes = Uint8List.fromList(utf8.encode(json));

      if (!context.mounted) return;
      nav.pop();
      dialogClosed = true;

      final result = await FilePicker.platform.saveFile(
        fileName: 'WealthSync_gdpr_export.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );

      if (result == null) return;

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("GDPR export saved to: $result"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      if (!dialogClosed) nav.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("GDPR Export Failed: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleExportCsv(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;

    final nav = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    bool dialogClosed = false;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.email)
          .collection('transactions')
          .orderBy('createdAt', descending: true)
          .get();

      final transactions = snap.docs.map((doc) =>
          TransactionModel.fromMap(doc.id, doc.data())).toList();

      final rows = <List<dynamic>>[
        ["ID", "Date", "Sender ID", "Recipient ID", "Recipient Name", "Amount", "Tax", "Total", "Currency", "Category", "Status", "Note", "Attachment URL", "Created At"],
        ...transactions.map((tx) => [
          tx.id,
          tx.date.toIso8601String(),
          tx.senderId,
          tx.recipientId,
          tx.recipientName,
          tx.amount,
          tx.tax,
          tx.total,
          tx.currency,
          tx.category ?? '',
          tx.status ?? '',
          tx.note ?? '',
          tx.attachmentUrl ?? '',
          tx.createdAt?.toIso8601String() ?? '',
        ]),
      ];

      final csv = const ListToCsvConverter().convert(rows);
      final bytes = Uint8List.fromList(utf8.encode(csv));

      if (!context.mounted) return;
      nav.pop();
      dialogClosed = true;

      final result = await FilePicker.platform.saveFile(
        fileName: 'WealthSync_transactions_export.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: bytes,
      );

      if (result == null) return;

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Exported to: $result"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      if (!dialogClosed) nav.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Export Failed: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Data & Support"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : AppColors.lightTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : AppColors.lightTextPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 18.sp,
        ),
      ),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark ? AppColors.darkGradient : AppColors.lightGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
            child: Column(
              children: [
                _SectionHeader("Data Management"),
                _SettingsTile(
                  icon: Icons.backup_outlined,
                  title: "Backup Data",
                  onTap: () => _handleBackup(context),
                ),
                _SettingsTile(
                  icon: Icons.restore_outlined,
                  title: "Restore Data",
                  onTap: () => _handleRestore(context),
                ),
                _SettingsTile(
                  icon: Icons.upload_file,
                  title: "Import Data (CSV)",
                  onTap: () => Get.to(() => const ImportScreen()),
                ),
                _SettingsTile(
                  icon: Icons.download,
                  title: "Export Transactions (CSV)",
                  onTap: () => _handleExportCsv(context),
                ),
                _SettingsTile(
                  icon: Icons.cloud_download,
                  title: "Export All Data (GDPR)",
                  onTap: () => _handleGdprExport(context),
                ),
                _SettingsTile(
                  icon: Icons.fact_check,
                  title: "Transaction Audit",
                  onTap: () => Get.to(() => const TransactionAuditScreen()),
                ),

                _Divider(),

                _SectionHeader("Support & Legal"),
                _SettingsTile(
                  icon: Icons.feedback_outlined,
                  title: "Send Feedback",
                  onTap: () => Get.to(() => const FeedbackScreen()),
                ),
                _SettingsTile(
                  icon: Icons.info_outline,
                  title: "About App",
                  onTap: () => Get.to(() => const AboutApplicationScreen()),
                ),
                _SettingsTile(
                  icon: Icons.gavel_outlined,
                  title: "Terms & Conditions",
                  onTap: () => Get.to(() => const LegalTrustPage()),
                ),
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: "Privacy Policy",
                  onTap: () => Get.to(() => const LegalTrustPage()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Reusable Components ----
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: 15.h, top: 10.h, left: 5.w),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            color: isDark ? Colors.white54 : AppColors.lightTextSecondary,
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Divider(color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lightBorder.withValues(alpha: 0.1)),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData? icon;
  final String title;
  final VoidCallback? onTap;

  const _SettingsTile({this.icon, required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.lightBorder.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: const Color(0xFF00E5FF),
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 16.w),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.2),
                  size: 16.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
