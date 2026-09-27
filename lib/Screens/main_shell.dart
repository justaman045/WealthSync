import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Components/adaptive_scaffold.dart';
import 'package:money_control/Components/bottom_nav_bar.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/feature_gate.dart';
import 'package:money_control/Components/offline_banner.dart';
import 'package:money_control/Config/tab_destinations.dart';
import 'package:money_control/Screens/analysis.dart';
import 'package:money_control/Screens/analytics.dart';
import 'package:money_control/Screens/edit_profile.dart';
import 'package:money_control/Screens/homescreen.dart';
import 'package:money_control/Screens/settings.dart';
import 'package:money_control/Screens/wealth_builder.dart';
import 'package:money_control/Services/feature_flag_service.dart';
import 'package:money_control/Services/performance_controller.dart';
import 'package:money_control/Utils/responsive.dart';

class MainShell extends StatefulWidget {
  final String initialName;
  const MainShell({super.key, this.initialName = 'home'});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  /// Ordered list of tab names that have been opened this session, oldest
  /// first. Kept pages are stored in [_pages] so hidden tabs keep state.
  final List<String> _kept = [];
  late String _current = widget.initialName;
  final Map<String, Widget> _pages = {};

  @override
  void initState() {
    super.initState();
    _kept.add(widget.initialName);
  }

  Future<void> _select(String name) async {
    if (name == _current) return;
    final dest = allTabs.firstWhere((t) => t.name == name);
    final key = dest.featureKey;
    if (key != null && !ensureFeatureVisible(context, key)) {
      return;
    }
    // The Wealth Builder computes financial targets from the user's age, so
    // users without an age must set one first.
    if (name == 'wealth') {
      final hasAge = await _checkAgeGate();
      if (!mounted) return;
      if (!hasAge) return;
    }
    setState(() {
      _current = name;
      if (!_kept.contains(name)) _kept.add(name);
    });
  }

  /// Returns true when the user may open the Wealth Builder. When age is
  /// missing (or invalid) it shows the "Setup Required" dialog and returns
  /// false. Fails open on read errors so a transient Firestore failure never
  /// strands the user on the tab bar.
  Future<bool> _checkAgeGate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return true;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email)
          .get();
      final data = doc.data();
      int? age = data?['age'] is num ? (data!['age'] as num).toInt() : null;
      if (age == null && data?['dob'] != null) {
        final dobTs = data!['dob'];
        final dob = dobTs is Timestamp ? dobTs.toDate() : null;
        if (dob != null) {
          final now = DateTime.now();
          age = now.year - dob.year;
          if (now.month < dob.month ||
              (now.month == dob.month && now.day < dob.day)) {
            age--;
          }
        }
      }
      if (age != null && age > 0) return true;
    } catch (e) {
      debugPrint("Error checking age: $e");
      return true;
    }

    final overlayCtx = Get.overlayContext;
    if (overlayCtx == null) return false;
    // Get.overlayContext always resolves a fresh context — false positive.
    // ignore: use_build_context_synchronously
    await showGeneralDialog(
      context: overlayCtx, // ignore: use_build_context_synchronously
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: Colors.black.withValues(alpha: 0.8),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: () {
                final sw = MediaQuery.sizeOf(ctx).width;
                final raw = sw * 0.85;
                return raw > 340
                    ? 340.0
                    : raw < 260
                    ? 260.0
                    : raw;
              }(),
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: Get.isDarkMode
                      ? AppColors.darkGradient
                      : AppColors.lightGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28.r),
                border: Border.all(
                  color: Get.isDarkMode
                      ? Colors.white.withValues(alpha: 0.15)
                      : AppColors.lightBorder,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 30.w,
                    offset: Offset(0.w, 10.w),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
                      size: 32.sp,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    "Setup Required",
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: Get.isDarkMode
                          ? Colors.white
                          : AppColors.lightTextPrimary,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    "To use the Wealth Builder, we need your age to calculate financial targets.",
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Get.isDarkMode
                          ? Colors.white70
                          : AppColors.lightTextSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 28.h),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            "Cancel",
                            style: TextStyle(
                                color: Get.isDarkMode
                                    ? Colors.white54
                                    : AppColors.lightTextTertiary),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // This profile entry point sat outside the `profile`
                            // flag, so `hidden` removed the settings row while
                            // this button still pushed EditProfileScreen.
                            if (!ensureFeatureUsable(ctx, 'profile')) return;
                            Navigator.pop(ctx);
                            Get.to(() => const EditProfileScreen());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Set Age",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(anim1.value),
          child: child,
        );
      },
    );
    return false;
  }

  Widget _buildPage(String name) {
    switch (name) {
      case 'home':
        return const BankingHomeScreen(showNavigation: false);
      case 'analytics':
        return const AnalyticsScreen(showNavigation: false);
      case 'insights':
        return const AIInsightsScreen(showNavigation: false);
      case 'wealth':
        return const WealthBuilderScreen(showNavigation: false);
      default:
        return const SettingsScreen(showNavigation: false);
    }
  }

  Widget _page(String name) => _pages[name] ??= _buildPage(name);

  @override
  Widget build(BuildContext context) {
    final isWide =
        Responsive.isTablet(context) && Responsive.isLandscape(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final stack = Column(
      children: [
        const OfflineBanner(),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Hidden pages are wrapped in Offstage (not just translated off-
              // screen) so they keep their state but stop rasterizing every
              // frame. Previously the heavy AI Insights/Analytics pages stayed
              // composited indefinitely after a visit, which melted the
              // emulator's software renderer (qemu segfault ~6 min in).
              // The active page mirrors the row order of [_kept] for the slide
              // direction so navigation still animates left/right.
              for (int i = 0; i < _kept.length; i++)
                _buildKeptPage(i),
            ],
          ),
        ),
      ],
    );

    if (isWide) {
      return Row(
        children: [
          // Rebuild the rail when an admin toggles a tab feature so hidden
          // tabs disappear (and restored tabs come back) without a restart.
          GetBuilder<FeatureFlagService>(
            builder: (_) => AdaptiveNavigationRail(
              currentTab: _current,
              isDark: isDark,
              onNavChanged: _select,
            ),
          ),
          Expanded(child: stack),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: stack,
      bottomNavigationBar: GetBuilder<FeatureFlagService>(
        builder: (_) => BottomNavBar(
          currentTab: _current,
          destinations: visibleTabs(),
          onTab: _select,
        ),
      ),
    );
  }

  Widget _buildKeptPage(int i) {
    final name = _kept[i];
    final active = name == _current;
    final activeIndex = _kept.indexOf(_current);
    return IgnorePointer(
      ignoring: !active,
      child: ExcludeSemantics(
        excluding: !active,
        child: Offstage(
          offstage: !active,
          child: AnimatedSlide(
            offset: Offset(active ? 0 : (i < activeIndex ? -1 : 1), 0),
            duration: PerformanceController.to.liteMode.value
                ? Duration.zero
                : const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            child: _page(name),
          ),
        ),
      ),
    );
  }
}
