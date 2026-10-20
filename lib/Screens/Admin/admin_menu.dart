import 'package:money_control/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Controllers/subscription_controller.dart';
import 'package:money_control/Screens/admin_dashboard.dart';
import 'package:money_control/Screens/Admin/admin_user_list.dart';
import 'package:money_control/Services/background_worker.dart';
import 'package:money_control/Screens/Admin/payment_settings_screen.dart';
import 'package:money_control/Screens/Admin/feature_flags_screen.dart';
import 'package:money_control/Platform/permission_platform.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/feature_gate.dart';
import 'package:money_control/Utils/responsive.dart';
import 'package:money_control/Services/error_handler.dart';

class AdminMenu extends StatefulWidget {
  const AdminMenu({super.key});

  @override
  State<AdminMenu> createState() => _AdminMenuState();
}

class _AdminMenuState extends State<AdminMenu> {
  bool _isImporting = false;

  Future<void> _triggerSmsImport() async {
    if (kIsWeb) {
      ErrorHandler.showInfo(
        'SMS import is not available in browser.',
        title: 'Not Available',
      );
      return;
    }
    var status = await Permission.sms.status;
    if (!status.isGranted) {
      if (status.isPermanentlyDenied) {
        ErrorHandler.showError(
          'SMS permission was permanently denied. Please enable it in app settings.',
          title: 'Permission Denied',
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Open Settings',
            textColor: Colors.white,
            onPressed: openAppSettings,
          ),
        );
        return;
      }
      status = await Permission.sms.request();
      if (!status.isGranted) {
        ErrorHandler.showError(
          'SMS permission is required to import transactions.',
          title: 'Permission Denied',
        );
        return;
      }
    }

    setState(() => _isImporting = true);
    try {
      final count = await BackgroundWorker.triggerSmsImport(days: 7);
      if (count > 0) {
        ErrorHandler.showSuccess(
          '$count new transaction${count > 1 ? 's' : ''} imported.',
          title: 'SMS Import Complete',
        );
      } else {
        ErrorHandler.showInfo(
          'No new transactions found in the last 7 days.',
          title: 'SMS Import Complete',
        );
      }
    } catch (e) {
      ErrorHandler.showError('Something went wrong: $e', title: 'Import Failed');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!Get.isRegistered<SubscriptionController>()) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64.sp, color: Colors.redAccent),
              SizedBox(height: 16.h),
              Text(AppLocalizations.of(context)!.accessDenied, style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }
    if (!Get.find<SubscriptionController>().isAdmin.value) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64.sp, color: Colors.redAccent),
              SizedBox(height: 16.h),
              Text(AppLocalizations.of(context)!.accessDenied, style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.darkBackground, AppColors.darkSurface, AppColors.darkSurface]
              : AppColors.lightGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            AppLocalizations.of(context)!.adminUtils,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Padding(
          padding: EdgeInsets.all(24.w),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
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
                title: "Feature Flags",
                subtitle: "Globally enable, hide or mark features as coming soon",
                icon: Icons.toggle_on_rounded,
                color: AppColors.primary,
                onTap: () => Get.to(() => const FeatureFlagsScreen()),
              ),
              SizedBox(height: 16.h),
              FeatureVisible(
                flagKey: 'sms_auto_import',
                child: _buildMenuCard(
                  context,
                  title: "SMS Auto-Import",
                  subtitle: "Import transactions from last 7 days",
                  icon: Icons.sms_rounded,
                  color: Colors.greenAccent,
                  loading: _isImporting,
                  onTap: _isImporting ? null : _triggerSmsImport,
                ),
              ),
            ],
              ),
            ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    loading ? 'Scanning SMS...' : subtitle,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white54
                          : AppColors.lightTextSecondary,
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
            ),
            loading
                ? const SizedBox.shrink()
                : Icon(
                    Icons.arrow_forward_ios,
                    color: isDark ? Colors.white24 : AppColors.lightTextTertiary,
                    size: 16.sp,
                  ),
          ],
        ),
      ),
    );
  }
}
