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
import 'package:money_control/Services/cache_service.dart';
import 'package:money_control/Services/local_backup_service.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/feature_gate.dart';
import 'package:money_control/Components/settings_widgets.dart';
import 'package:money_control/Screens/import_screen.dart';
import 'package:money_control/Screens/transaction_audit_screen.dart';
import 'package:money_control/Utils/responsive.dart';

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
    if (!ensureFeatureVisible(context, 'restore_data')) return;
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    if (userEmail == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Restore Data"),
        content: const Text(
            "This handles restoring from local cache. Merge restored transactions with current data?"),
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
      if (!await LocalBackupService.hasUserBackup(userEmail)) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("No local backup found. Tap 'Backup Data' first."),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      final restored =
          await LocalBackupService.restoreUserTransactions(userEmail);
      // The restore re-writes Firestore; drop the cold-load cache so a reload
      // within the TTL doesn't surface stale data (mirrors import_screen).
      LocalCacheService.invalidate('transactions_$userEmail');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            restored > 0
                ? "Restored $restored transaction${restored == 1 ? '' : 's'} from backup"
                : "Backup had no transactions to restore",
          ),
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
    if (!ensureFeatureVisible(context, 'export_all_data')) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;

    // Mirrors UserService._subcollections (the canonical account-deletion
    // list) so "export all" and "delete all" stay in sync.
    const collections = [
      // Core
      'transactions', 'recurring_payments', 'categories', 'budgets',
      'notifications', 'goals', 'loans', 'challenges', 'lent_money',
      'sms_rules', 'category_rules', 'learning_data',
      // Liquid & Fixed Income
      'fd_accounts', 'ppf_accounts', 'post_office_schemes', 'bonds', 'chit_funds',
      // Equity & Growth
      'stock_holdings', 'sip_holdings', 'etf_holdings', 'foreign_stocks',
      'startup_investments',
      // Retirement
      'pf_accounts', 'vpf_accounts', 'nps_accounts',
      // Alternative Assets
      'gold_holdings', 'sgb_holdings', 'jewelry_items', 'crypto_holdings',
      'reit_holdings', 'p2p_loans',
      // Physical Assets
      'agri_land', 'properties', 'vehicles',
      // Protection & Business
      'insurance_policies', 'business_assets',
      // Liabilities
      'bnpl_entries', 'credit_cards',
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
      final skipped = <String>[];

      // Fetch the user profile doc (name, phone, address, DOB — personal data
      // that must be part of a GDPR export).
      try {
        final profileDoc = await FirebaseFirestore.instance
            .doc('users/${user.email}')
            .get();
        data['profile'] = profileDoc.exists ? profileDoc.data() : null;
      } catch (e) {
        debugPrint('GDPR export: skipping profile ($e)');
        skipped.add('profile');
      }

      // Fetch wealth portfolio document
      try {
        final wealthDoc = await FirebaseFirestore.instance
            .doc('users/${user.email}/wealth/portfolio')
            .get();
        data['wealth_portfolio'] = wealthDoc.exists ? wealthDoc.data() : null;
      } catch (e) {
        debugPrint('GDPR export: skipping wealth portfolio ($e)');
        skipped.add('wealth_portfolio');
      }

      // Fetch all subcollections — one failed read must not abort the export.
      for (final col in collections) {
        try {
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
        } catch (e) {
          debugPrint('GDPR export: skipping $col ($e)');
          skipped.add(col);
        }
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
      final summary = skipped.isEmpty
          ? "GDPR export saved to: $result"
          : "GDPR export saved to: $result (skipped: ${skipped.join(', ')})";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(summary),
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
    if (!ensureFeatureVisible(context, 'export_csv')) return;
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
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
                child: Column(
                  children: [
                SectionHeader("Data Management"),
                SettingsTile(
                  icon: Icons.backup_outlined,
                  title: "Backup Data",
                  onTap: () => _handleBackup(context),
                ),
                FeatureVisible(
                  flagKey: 'restore_data',
                  child: SettingsTile(
                    icon: Icons.restore_outlined,
                    title: "Restore Data",
                    onTap: () => _handleRestore(context),
                  ),
                ),
                FeatureVisible(
                  flagKey: 'import_data',
                  child: SettingsTile(
                    icon: Icons.upload_file,
                    title: "Import Data (CSV)",
                    onTap: () {
                      if (!ensureFeatureVisible(context, 'import_data')) {
                        return;
                      }
                      Get.to(() => const ImportScreen());
                    },
                  ),
                ),
                FeatureVisible(
                  flagKey: 'export_csv',
                  child: SettingsTile(
                    icon: Icons.download,
                    title: "Export Transactions (CSV)",
                    onTap: () => _handleExportCsv(context),
                  ),
                ),
                FeatureVisible(
                  flagKey: 'export_all_data',
                  child: SettingsTile(
                    icon: Icons.cloud_download,
                    title: "Export All Data (GDPR)",
                    onTap: () => _handleGdprExport(context),
                  ),
                ),
                FeatureVisible(
                  flagKey: 'transaction_audit',
                  child: SettingsTile(
                    icon: Icons.fact_check,
                    title: "Transaction Audit",
                    onTap: () {
                      if (!ensureFeatureVisible(context, 'transaction_audit')) {
                        return;
                      }
                      Get.to(() => const TransactionAuditScreen());
                    },
                  ),
                ),

                SectionDivider(),

                SectionHeader("Support & Legal"),
                SettingsTile(
                  icon: Icons.feedback_outlined,
                  title: "Send Feedback",
                  onTap: () => Get.to(() => const FeedbackScreen()),
                ),
                SettingsTile(
                  icon: Icons.info_outline,
                  title: "About App",
                  onTap: () => Get.to(() => const AboutApplicationScreen()),
                ),
                SettingsTile(
                  icon: Icons.gavel_outlined,
                  title: "Terms & Conditions",
                  onTap: () => Get.to(() => const LegalTrustPage()),
                ),
                SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: "Privacy Policy",
                  onTap: () => Get.to(() => const LegalTrustPage()),
                ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
