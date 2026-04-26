import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' as rendering;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Controllers/profile_controller.dart';
import 'package:money_control/Screens/loginscreen.dart';
import 'package:money_control/Screens/Settings/general_settings.dart';
import 'package:money_control/Screens/Settings/security_settings.dart';
import 'package:money_control/Screens/Settings/data_support_settings.dart';
import 'package:money_control/Screens/edit_profile.dart';
import 'package:money_control/Components/bottom_nav_bar.dart';
import 'package:money_control/Screens/sms_import_screen.dart';
import 'package:money_control/Screens/subscription_screen.dart';
import 'package:money_control/Controllers/subscription_controller.dart';
import 'package:money_control/Screens/Admin/admin_menu.dart';
import 'package:money_control/Screens/lent_money_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ProfileController _profileController = Get.put(ProfileController());
  String _version = "1.0.0";
  final ValueNotifier<bool> _isBottomBarVisible = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    _getVersion();
  }

  @override
  void dispose() {
    _isBottomBarVisible.dispose();
    super.dispose();
  }

  Future<void> _getVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = "${info.version} (${info.buildNumber})";
        });
      }
    } catch (e) {
      debugPrint("Error fetching version: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark ? AppColors.darkGradient : AppColors.lightGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text("Settings"),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false, // Hide back button on main tab
          titleTextStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
        body: NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (notification.direction == rendering.ScrollDirection.reverse) {
              if (_isBottomBarVisible.value) _isBottomBarVisible.value = false;
            } else if (notification.direction ==
                rendering.ScrollDirection.forward) {
              if (!_isBottomBarVisible.value) _isBottomBarVisible.value = true;
            }
            return false;
          },
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 10.h),
              child: Column(
                children: [
                  _buildProfileHeader(),
                  SizedBox(height: 30.h),

                  // -- CATEGORIZED MENU --
                  _SectionHeader("Menu"),

                  // Subscription Card — hidden for admins (they are always Pro)
                  Obx(() {
                    final ctrl = Get.find<SubscriptionController>();
                    if (ctrl.isAdmin.value) return const SizedBox.shrink();
                    final isPro = ctrl.isPro;
                    return _SettingsCategoryCard(
                      title: isPro ? "Managing Subscription" : "Upgrade to Pro",
                      subtitle: isPro
                          ? "You are a Pro Member"
                          : "Unlock limits & features",
                      icon: isPro
                          ? Icons.verified_user_rounded
                          : Icons.diamond_outlined,
                      color: isPro ? Colors.greenAccent : Colors.cyanAccent,
                      onTap: () => Get.to(() => const SubscriptionScreen()),
                    );
                  }),
                  SizedBox(height: 16.h),
                  _SettingsCategoryCard(
                    title: "General",
                    subtitle: "Currency, Categories, Budget, Notifications",
                    icon: Icons.tune_rounded,
                    color: const Color(0xFF6C63FF),
                    onTap: () => Get.to(() => const GeneralSettingsScreen()),
                  ),

                  SizedBox(height: 16.h),

                  _SettingsCategoryCard(
                    title: "Security & Privacy",
                    subtitle: "Lock, Password, Account",
                    icon: Icons.security_rounded,
                    color: const Color(0xFF00E5FF),
                    onTap: () => Get.to(() => const SecuritySettingsScreen()),
                  ),

                  SizedBox(height: 16.h),

                  _SettingsCategoryCard(
                    title: "Data & Support",
                    subtitle: "Backup, Feedback, Legal",
                    icon: Icons.help_outline_rounded,
                    color: Colors.orangeAccent,
                    onTap: () =>
                        Get.to(() => const DataSupportSettingsScreen()),
                  ),

                  SizedBox(height: 16.h),

                  _SettingsCategoryCard(
                    title: "Automation",
                    subtitle: "Import SMS",
                    icon: Icons.auto_mode_rounded,
                    color: Colors.greenAccent,
                    onTap: () => Get.to(() => const SmsImportScreen()),
                  ),

                  SizedBox(height: 16.h),

                  // LENT MONEY (PRO FEATURE)
                  _SettingsCategoryCard(
                    title: "Future Money Tracker",
                    subtitle: "Track money you lent and borrowed",
                    icon: Icons.handshake_rounded,
                    color: Colors.orangeAccent,
                    onTap: () {
                      final ctrl = Get.find<SubscriptionController>();
                      if (!ctrl.isPro) {
                        Get.to(() => const SubscriptionScreen());
                        return;
                      }
                      Get.to(() => const LentMoneyScreen());
                    },
                  ),

                  SizedBox(height: 40.h),

                  // Admin Dashboard (Restricted)
                  Obx(() {
                    if (!Get.find<SubscriptionController>().isAdmin.value) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      children: [
                        _SettingsCategoryCard(
                          key: const ValueKey("admin_utils_card"),
                          title: "Admin Utils",
                          subtitle: "Manage Data & Approvals",
                          icon: Icons.admin_panel_settings_rounded,
                          color: Colors.redAccent,
                          onTap: () => Get.to(() => const AdminMenu()),
                        ),
                        SizedBox(height: 40.h),
                      ],
                    );
                  }),

                  _buildSignOutButton(),
                  SizedBox(height: 24.h),
                  Text(
                    "Version $_version",
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.3),
                      fontSize: 12.sp,
                    ),
                  ),
                  SizedBox(
                    height: 150.h,
                  ), // Increased padding to prevent cut-off
                ],
              ),
            ),
          ),
        ),
        extendBody: true,
        bottomNavigationBar: ValueListenableBuilder<bool>(
          valueListenable: _isBottomBarVisible,
          builder: (context, visible, child) {
            return AnimatedSlide(
              duration: const Duration(milliseconds: 200),
              offset: visible ? Offset.zero : const Offset(0, 1),
              child: child,
            );
          },
          child: const BottomNavBar(currentIndex: 4),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return GestureDetector(
      onTap: () => Get.to(() => const EditProfileScreen()),
      child: GlassContainer(
        padding: EdgeInsets.all(20.w),
        borderRadius: BorderRadius.circular(24.r),
        child: Row(
          children: [
            Obx(() {
              final url = _profileController.photoURL.value;
              return Container(
                width: 60.w,
                height: 60.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF00E5FF), width: 2),
                  image: DecorationImage(
                    image: url.isNotEmpty
                        ? CachedNetworkImageProvider(url)
                        : const AssetImage("assets/profile.png")
                              as ImageProvider,
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                      blurRadius: 15,
                    ),
                  ],
                ),
              );
            }),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Obx(
                    () => Text(
                      _profileController.currentUser.value?.displayName ??
                          "User",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Obx(
                    () => Text(
                      _profileController.currentUser.value?.email ?? "No Email",
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 12.sp,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.3),
              size: 16.sp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: () async {
          await FirebaseAuth.instance.signOut();
          Get.offAll(() => const LoginScreen());
        },
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
        child: Text(
          "Sign Out",
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 16.sp,
          ),
        ),
      ),
    );
  }
}

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
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class _SettingsCategoryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SettingsCategoryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        padding: EdgeInsets.all(20.w),
        borderRadius: BorderRadius.circular(20.r),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Icon(icon, color: color, size: 28.sp),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.3),
              size: 16.sp,
            ),
          ],
        ),
      ),
    );
  }
}
