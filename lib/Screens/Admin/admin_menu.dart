import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Controllers/subscription_controller.dart';
import 'package:money_control/Screens/admin_dashboard.dart';
import 'package:money_control/Screens/Admin/admin_user_list.dart';
import 'package:money_control/Services/background_worker.dart';
import 'package:money_control/Screens/Admin/payment_settings_screen.dart';
import 'package:permission_handler/permission_handler.dart';

class AdminMenu extends StatefulWidget {
  const AdminMenu({super.key});

  @override
  State<AdminMenu> createState() => _AdminMenuState();
}

class _AdminMenuState extends State<AdminMenu> {
  bool _isImporting = false;

  Future<void> _triggerSmsImport() async {
    final status = await Permission.sms.request();
    if (!status.isGranted) {
      Get.snackbar(
        'Permission Denied',
        'SMS permission is required to import transactions.',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isImporting = true);
    try {
      final count = await BackgroundWorker.triggerSmsImport(days: 7);
      Get.snackbar(
        'SMS Import Complete',
        count > 0
            ? '$count new transaction${count > 1 ? 's' : ''} imported.'
            : 'No new transactions found in the last 7 days.',
        backgroundColor: count > 0 ? const Color(0xFF0FA958) : Colors.grey[700]!,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      Get.snackbar(
        'Import Failed',
        'Something went wrong: $e',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Get.find<SubscriptionController>().isAdmin.value) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.lock_outline, size: 64, color: Colors.redAccent),
              SizedBox(height: 16),
              Text("Access Denied", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0F2027),
            Color(0xFF203A43),
            Color(0xFF2C5364),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            "Admin Utils",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            children: [
              _buildMenuCard(
                context,
                title: "Pending Approvals",
                subtitle: "Review upgrade requests",
                icon: Icons.checklist_rtl_rounded,
                color: Colors.orangeAccent,
                onTap: () => Get.to(() => const AdminDashboard()),
              ),
              SizedBox(height: 16.h),
              _buildMenuCard(
                context,
                title: "Manage Users",
                subtitle: "View all users & set expiry",
                icon: Icons.people_alt_rounded,
                color: Colors.cyanAccent,
                onTap: () => Get.to(() => const AdminUserListScreen()),
              ),
              SizedBox(height: 16.h),
              _buildMenuCard(
                context,
                title: "Payment Settings",
                subtitle: "Toggle Google Play / Manual UPI mode",
                icon: Icons.payment_rounded,
                color: Colors.purpleAccent,
                onTap: () => Get.to(() => const PaymentSettingsScreen()),
              ),
              SizedBox(height: 16.h),
              _buildMenuCard(
                context,
                title: "SMS Auto-Import",
                subtitle: "Import transactions from last 7 days",
                icon: Icons.sms_rounded,
                color: Colors.greenAccent,
                loading: _isImporting,
                onTap: _isImporting ? null : _triggerSmsImport,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    bool loading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        padding: EdgeInsets.all(20.w),
        borderRadius: BorderRadius.circular(20.r),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: loading
                  ? SizedBox(
                      width: 32.sp,
                      height: 32.sp,
                      child: CircularProgressIndicator(
                        color: color,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Icon(icon, color: color, size: 32.sp),
            ),
            SizedBox(width: 20.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    loading ? 'Scanning SMS...' : subtitle,
                    style: TextStyle(color: Colors.white54, fontSize: 14.sp),
                  ),
                ],
              ),
            ),
            loading
                ? const SizedBox.shrink()
                : Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16.sp),
          ],
        ),
      ),
    );
  }
}
