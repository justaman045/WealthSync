import 'package:money_control/Components/profile_avatar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' as rendering;
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/feature_gate.dart';
import 'package:money_control/Services/update_checker.dart';
import 'package:money_control/Config/app_strings.dart';
import 'package:money_control/Controllers/profile_controller.dart';
import 'package:money_control/Controllers/auth_controller.dart';
import 'package:money_control/Screens/Settings/general_settings.dart';
import 'package:money_control/Screens/Settings/security_settings.dart';
import 'package:money_control/Screens/Settings/data_support_settings.dart';
import 'package:money_control/Screens/edit_profile.dart';
import 'package:money_control/Components/adaptive_scaffold.dart';
import 'package:money_control/Screens/sms_import_screen.dart';
import 'package:money_control/Screens/subscription_screen.dart';
import 'package:money_control/Controllers/subscription_controller.dart';
import 'package:money_control/Screens/Admin/admin_menu.dart';
import 'package:money_control/Screens/lent_money_screen.dart';
import 'package:money_control/Screens/invite_friends.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:money_control/Services/referral_service.dart';
import 'package:money_control/Utils/responsive.dart';

class SettingsScreen extends StatefulWidget {
  final bool showNavigation;
  const SettingsScreen({super.key, this.showNavigation = true});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final ProfileController _profileController;
  String _version = "1.0.0";
  bool _isCheckingUpdate = false;
  final ValueNotifier<bool> _isBottomBarVisible = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<ProfileController>()) {
      Get.put(ProfileController());
    }
    _profileController = Get.find<ProfileController>();
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

    return AdaptiveScaffold(
      currentTab: 'settings',
      isVisible: widget.showNavigation ? _isBottomBarVisible : null,
      showNavigation: widget.showNavigation,
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark ? AppColors.darkGradient : AppColors.lightGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
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
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: Responsive.contentMaxWidth(context),
                ),
                child: Column(
                  children: [
                    _buildProfileHeader(),
                    SizedBox(height: 30.h),

                    // -- CATEGORIZED MENU --
                    _SectionHeader("Menu"),

                    // Subscription Card — hidden for admins (they are always Pro)
                    Obx(() {
                      if (!Get.isRegistered<SubscriptionController>())
                        return const SizedBox.shrink();
                      final ctrl = Get.find<SubscriptionController>();
                      if (ctrl.isAdmin.value) return const SizedBox.shrink();
                      final isPro = ctrl.isPro;
                      return _SettingsCategoryCard(
                        title: isPro
                            ? "Managing Subscription"
                            : AppStrings.upgradeToPro,
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
                      color: AppColors.primary,
                      onTap: () => Get.to(() => const GeneralSettingsScreen()),
                    ),

                    SizedBox(height: 16.h),

                    _SettingsCategoryCard(
                      title: "Security & Privacy",
                      subtitle: "Lock, Password, Account",
                      icon: Icons.security_rounded,
                      color: AppColors.primary,
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

                    FeatureVisible(
                      flagKey: 'sms_tracking',
                      child: _SettingsCategoryCard(
                        title: "Automation",
                        subtitle: "Import SMS",
                        icon: Icons.auto_mode_rounded,
                        color: Colors.greenAccent,
                        onTap: () {
                          if (!ensureFeatureVisible(context, 'sms_tracking')) {
                            return;
                          }
                          Get.to(() => const SmsImportScreen());
                        },
                      ),
                    ),

                    SizedBox(height: 16.h),

                    // INVITE FRIENDS
                    FeatureVisible(
                      flagKey: 'invite',
                      child: _InviteFriendsCard(),
                    ),

                    SizedBox(height: 16.h),

                    // LENT MONEY (PRO FEATURE)
                    FeatureVisible(
                      flagKey: 'lent_money',
                      child: _SettingsCategoryCard(
                        title: "Future Money Tracker",
                        subtitle: "Track money you lent and borrowed",
                        icon: Icons.handshake_rounded,
                        color: Colors.orangeAccent,
                        onTap: () {
                          if (!Get.isRegistered<SubscriptionController>()) {
                            return;
                          }
                          final ctrl = Get.find<SubscriptionController>();
                          if (!ctrl.isPro) {
                            Get.to(() => const SubscriptionScreen());
                            return;
                          }
                          if (!ensureFeatureVisible(context, 'lent_money')) {
                            return;
                          }
                          Get.to(() => const LentMoneyScreen());
                        },
                      ),
                    ),

                    SizedBox(height: 40.h),

                    // Admin Dashboard (Restricted)
                    Obx(() {
                      if (!Get.isRegistered<SubscriptionController>() ||
                          !Get.find<SubscriptionController>().isAdmin.value) {
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
                    FeatureVisible(
                      flagKey: 'update_checker',
                      child: Padding(
                        padding: EdgeInsets.only(top: 12.h),
                        child: GestureDetector(
                          onTap: _isCheckingUpdate
                              ? null
                              : () async {
                                  setState(() => _isCheckingUpdate = true);
                                  try {
                                    final hasUpdate =
                                        await UpdateChecker.checkForUpdateManual();
                                    if (!mounted) return;
                                    // ignore: use_build_context_synchronously — guarded by mounted above
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          hasUpdate
                                              ? "Update available!"
                                              : "You're up to date!",
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() => _isCheckingUpdate = false);
                                    }
                                  }
                                },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isCheckingUpdate)
                                SizedBox(
                                  width: 14.sp,
                                  height: 14.sp,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.4),
                                  ),
                                )
                              else
                                Icon(
                                  Icons.system_update_rounded,
                                  size: 14.sp,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.4),
                                ),
                              SizedBox(width: 6.w),
                              Text(
                                _isCheckingUpdate
                                    ? "Checking..."
                                    : "Check for Updates",
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.4),
                                  fontSize: 12.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!kIsWeb)
                      Padding(
                        padding: EdgeInsets.only(top: 16.h),
                        child: GlassContainer(
                          onTap: () async {
                            final url = Uri.parse(_webUrl);
                            try {
                              await launchUrl(
                                url,
                                mode: LaunchMode.externalApplication,
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Could not open browser"),
                                  ),
                                );
                              }
                            }
                          },
                          padding: EdgeInsets.all(16.w),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(12.w),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Icon(
                                  Icons.language,
                                  color: AppColors.primary,
                                  size: 28.sp,
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "WealthSync Web",
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      "Access from any device",
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      _webUrl.replaceAll("https://", ""),
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        color: AppColors.primary,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.open_in_new_rounded,
                                color: AppColors.primary,
                                size: 20.sp,
                              ),
                            ],
                          ),
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
        ),
      ),
      extendBody: true,
    );
  }

  Widget _buildProfileHeader() {
    return FeatureVisible(
      flagKey: 'profile',
      child: GestureDetector(
        onTap: () {
          if (!ensureFeatureVisible(context, 'profile')) return;
          Get.to(() => const EditProfileScreen());
        },
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
                    border: Border.all(color: AppColors.primary, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 15.w,
                      ),
                    ],
                  ),
                  child: AppAvatar(url: url, size: 60.w),
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
                        _profileController.currentUser.value?.email ??
                            "No Email",
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
      ),
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: () async {
          await Get.find<AuthController>().logout();
        },
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
        child: Text(
          AppStrings.signOut,
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

class _InviteFriendsCard extends StatefulWidget {
  @override
  State<_InviteFriendsCard> createState() => _InviteFriendsCardState();
}

const _webUrl = 'https://justaman045.github.io/WealthSync/';

class _InviteFriendsCardState extends State<_InviteFriendsCard> {
  String _code = '';
  int _count = 0;
  bool _loading = true;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _subscribeToStats();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _subscribeToStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      setState(() => _loading = false);
      return;
    }
    await ReferralService.ensureReferralCode();
    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.email)
        .snapshots()
        .listen(
          (snap) {
            if (!mounted) return;
            final data = snap.data() ?? {};
            setState(() {
              _code = data['referralCode'] as String? ?? '';
              _count = (data['referralCount'] as int?) ?? 0;
              _loading = false;
            });
          },
          onError: (e) {
            debugPrint('InviteFriends stream error: $e');
            if (mounted) setState(() => _loading = false);
          },
        );
  }

  Future<void> _copyCode() async {
    if (_code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Code copied"),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        if (!ensureFeatureVisible(context, 'invite')) return;
        Get.to(() => const InviteFriendsScreen());
      },
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.15),
              AppColors.secondary.withValues(alpha: 0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.card_giftcard_rounded,
                color: AppColors.primary,
                size: 24.sp,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: _loading
                  ? Text(
                      "Loading...",
                      style: TextStyle(
                        color: isDark
                            ? Colors.white54
                            : AppColors.lightTextSecondary,
                        fontSize: 13.sp,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Invite Friends",
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Row(
                          children: [
                            Text(
                              "Your code: ",
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: isDark
                                    ? Colors.white60
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                            InkWell(
                              onTap: _code.isEmpty ? null : _copyCode,
                              borderRadius: BorderRadius.circular(6.r),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _code.isEmpty ? '—' : _code,
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    if (_code.isNotEmpty) ...[
                                      SizedBox(width: 4.w),
                                      Icon(
                                        Icons.copy_rounded,
                                        size: 12.sp,
                                        color: AppColors.primary,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_count > 0)
                          Text(
                            "You've referred $_count friend${_count > 1 ? 's' : ''} — $_count month${_count > 1 ? 's' : ''} earned 🎉",
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.greenAccent,
                            ),
                          ),
                      ],
                    ),
            ),
            Icon(Icons.share_rounded, color: AppColors.primary, size: 20.sp),
          ],
        ),
      ),
    );
  }
}
