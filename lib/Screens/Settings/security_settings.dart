import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Controllers/privacy_controller.dart';
import 'package:money_control/Services/biometric_service.dart';
import 'package:money_control/Screens/deactivate_account.dart';
import 'package:money_control/Services/error_handler.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/settings_widgets.dart';
import 'package:money_control/Utils/responsive.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  late final PrivacyController privacyController;
  late final BiometricService bioService;

  @override
  void initState() {
    super.initState();
    privacyController = Get.find<PrivacyController>();
    bioService = Get.find<BiometricService>();
  }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Security & Privacy"),
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
                SectionHeader("Access Control"),

                // Biometric Toggle
                if (!kIsWeb)
                  Obx(
                    () => SettingsTile(
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
                  () => SettingsTile(
                    icon: Icons.visibility_off_outlined,
                    title: "Privacy Mode (Blur)",
                    trailing: Switch(
                      value: privacyController.isPrivacyMode.value,
                      activeThumbColor: const Color(0xFF00E5FF),
                      onChanged: (val) => privacyController.togglePrivacy(),
                    ),
                  ),
                ),

                SectionDivider(),

                SectionHeader("Account Security"),

                SettingsTile(
                  icon: Icons.lock_reset_outlined,
                  title: "Change Password",
                  onTap: () => _sendPasswordResetEmail(context),
                ),

                SettingsTile(
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
        ),
      ),
    );
  }
}
