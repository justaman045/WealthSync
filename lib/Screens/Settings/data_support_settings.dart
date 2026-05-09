import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
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

class DataSupportSettingsScreen extends StatelessWidget {
  const DataSupportSettingsScreen({super.key});

  Future<void> _handleBackup(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;

    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      await LocalBackupService.backupUserTransactions(user!.email!);

      if (!context.mounted) return;
      Navigator.of(context).pop(); // close loading
      // Defer past the dialog-pop frame so GetX overlay is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.snackbar(
          "Backup Success",
          "Data backed up securely",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: isDark ? Colors.white : Colors.black,
        );
      });
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.snackbar("Error", "Backup failed: $e");
      });
    }
  }

  Future<void> _handleRestore(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Similar restore logic to original settings
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    if (userEmail == null) return;

    Get.defaultDialog(
      title: "Restore Data",
      middleText:
          "This handles restoring from local cache. Overwrite current data?",
      textConfirm: "Restore",
      textCancel: "Cancel",
      confirmTextColor: isDark ? Colors.white : Colors.black,
      onConfirm: () async {
        Navigator.of(context).pop(); // close dialog
        try {
          await LocalBackupService.restoreUserTransactions(userEmail);
          Get.snackbar(
            "Restore Success",
            "Data restored from backup",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: isDark ? Colors.white : Colors.black,
          );
        } catch (e) {
          Get.snackbar("Error", "Restore failed: $e");
        }
      },
    );
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
          TransactionModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();

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
          tx.createdAt?.toDate().toIso8601String() ?? '',
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
                  title: "Export Data (CSV)",
                  onTap: () => _handleExportCsv(context),
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
