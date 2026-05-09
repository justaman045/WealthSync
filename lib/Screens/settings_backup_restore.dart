// ignore_for_file: use_build_context_synchronously
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';

import 'package:money_control/Services/local_backup_service.dart';
import 'package:money_control/Services/error_handler.dart';

class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({super.key});

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
  bool working = false;

  void _setWorking(bool v) => setState(() => working = v);

  Future<void> _backupNow() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _setWorking(true);
    await LocalBackupService.backupUserTransactions(user.email!);
    if (!mounted) return;
    _setWorking(false);

    ErrorHandler.showSuccess("Backup completed successfully!");
  }

  Future<void> _exportBackup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 🔥 Always create/update the latest backup BEFORE exporting
    await LocalBackupService.backupUserTransactions(user.email!);

    final backup = await LocalBackupService.readUserTransactionsBackup(
      user.email!,
    );

    if (backup.isEmpty) {
      ErrorHandler.showError("No transactions found to backup", title: "Backup");
      return;
    }

    final file = await LocalBackupService.exportBackupFile(user.email!);

    // ignore: deprecated_member_use
    await Share.shareXFiles([XFile(file.path)], text: "Finance Control Backup");

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Backup exported!")));
  }

  Future<void> _restoreBackup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (picked == null) return;

    final path = picked.files.single.path;
    if (path == null) return;

    try {
      _setWorking(true);

      final raw = await File(path).readAsString();
      final decoded = jsonDecode(raw);

      if (decoded is! List) throw Exception("Invalid backup format");

      final col = FirebaseFirestore.instance
          .collection("users")
          .doc(user.email)
          .collection("transactions");

      final batch = FirebaseFirestore.instance.batch();

      for (var tx in decoded) {
        final map = Map<String, dynamic>.from(tx);
        final id = map['id'];
        map.remove('id');

        if (map.containsKey('date') && map['date'] is String) {
          map['date'] = DateTime.parse(map['date']);
        }
        if (map.containsKey('createdAt') && map['createdAt'] is String) {
          map['createdAt'] = DateTime.parse(map['createdAt']);
        }

        final docRef = col.doc(id);
        batch.set(docRef, map, SetOptions(merge: true));
      }

      await batch.commit();

      if (!mounted) return;
      _setWorking(false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Restore successful!")));
    } catch (e) {
      if (!mounted) return;
      _setWorking(false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Restore failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gradientColors = isDark
        ? [
            const Color(0xFF1A1A2E), // Midnight Void
            const Color(0xFF16213E).withValues(alpha: 0.95),
          ]
        : [const Color(0xFFF5F7FA), const Color(0xFFC3CFE2)]; // Premium Light

    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            "Backup & Restore",
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
          child: working
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: isDark
                            ? const Color(0xFF00E5FF)
                            : scheme.primary,
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        "Processing...",
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _item(
                      icon: Icons.cloud_upload_outlined,
                      title: "Backup Transactions",
                      subtitle: "Save a secure offline copy",
                      iconBg: const Color(0xFF6C63FF),
                      onTap: _backupNow,
                      isDark: isDark,
                    ),
                    SizedBox(height: 16.h),
                    _item(
                      icon: Icons.ios_share_rounded,
                      title: "Export Backup",
                      subtitle: "Share or store the backup file",
                      iconBg: const Color(0xFF00E5FF),
                      onTap: _exportBackup,
                      isDark: isDark,
                    ),
                    SizedBox(height: 16.h),
                    _item(
                      icon: Icons.restore,
                      title: "Restore Backup",
                      subtitle: "Import a saved JSON backup",
                      iconBg: const Color(0xFFEA80FC),
                      onTap: _restoreBackup,
                      isDark: isDark,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _item({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconBg,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final containerColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.6);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.white.withValues(alpha: 0.4);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        splashColor: iconBg.withValues(alpha: 0.2),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: containerColor,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: iconBg.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28.sp, color: iconBg),
              ),
              SizedBox(width: 20.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: textColor.withValues(alpha: 0.6),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20.sp,
                color: textColor.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
