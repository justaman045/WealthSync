import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Controllers/privacy_controller.dart';
import 'package:money_control/Services/biometric_service.dart';
import 'package:money_control/Screens/deactivate_account.dart';
import 'package:money_control/Services/error_handler.dart';

class SecuritySettingsScreen extends StatelessWidget {
  const SecuritySettingsScreen({super.key});

  Future<void> _sendPasswordResetEmail(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);
      ErrorHandler.showSuccess("Link sent to ${user.email}");
    } catch (e) {
      ErrorHandler.showError("Failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final PrivacyController privacyController = Get.find();
    final BiometricService bioService = Get.find();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Security & Privacy"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18.sp,
        ),
      ),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1A1A2E), // Midnight Void
              const Color(0xFF16213E).withValues(alpha: 0.95),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
            child: Column(
              children: [
                _SectionHeader("Access Control"),

                // Biometric Toggle
                Obx(
                  () => _SettingsTile(
                    icon: Icons.fingerprint,
                    title: "Biometric App Lock",
                    trailing: Switch(
                      value: bioService.isBiometricEnabled.value,
                      activeThumbColor: const Color(0xFF00E5FF),
                      onChanged: (val) => bioService.toggleBiometric(val),
                    ),
                  ),
                ),

                // Privacy Mode Toggle
                Obx(
                  () => _SettingsTile(
                    icon: Icons.visibility_off_outlined,
                    title: "Privacy Mode (Blur)",
                    trailing: Switch(
                      value: privacyController.isPrivacyMode.value,
                      activeThumbColor: const Color(0xFF00E5FF),
                      onChanged: (val) => privacyController.togglePrivacy(),
                    ),
                  ),
                ),

                _Divider(),

                _SectionHeader("Account Security"),

                _SettingsTile(
                  icon: Icons.lock_reset_outlined,
                  title: "Change Password",
                  onTap: () => _sendPasswordResetEmail(context),
                ),

                _SettingsTile(
                  icon: Icons.delete_forever_outlined,
                  title: "Delete Account",
                  iconColor: Colors.redAccent,
                  textColor: Colors.redAccent,
                  onTap: () => Get.to(() => const DeactivateAccountScreen()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Reusable Components (Ideally verify if we can share these) ----
// Since these are small enough, I'll duplicate them for self-containment
// or I can put them in a shared widgets file.
// For now duplication is faster and less risky of breaking other things.

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 15.h, top: 10.h, left: 5.w),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            color: Colors.white54,
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
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Divider(color: Colors.white.withValues(alpha: 0.1)),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData? icon;
  final String title;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? textColor;
  final Widget? trailing;

  const _SettingsTile({
    this.icon,
    required this.title,
    this.onTap,
    this.iconColor,
    this.textColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
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
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: (iconColor ?? const Color(0xFF00E5FF)).withValues(
                        alpha: 0.1,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: iconColor ?? const Color(0xFF00E5FF),
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 16.w),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: textColor ?? Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (trailing != null)
                  trailing!
                else
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white24,
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
