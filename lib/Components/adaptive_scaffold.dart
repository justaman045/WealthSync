import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Components/animated_bottom_nav.dart';
import 'package:money_control/Components/bottom_nav_bar.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/feature_gate.dart';
import 'package:money_control/Components/hover_effect.dart';
import 'package:money_control/Components/methods.dart';
import 'package:money_control/Config/tab_destinations.dart';
import 'package:money_control/Services/feature_flag_service.dart';
import 'package:money_control/Services/performance_controller.dart';
import 'package:money_control/Utils/responsive.dart';

class AdaptiveScaffold extends StatelessWidget {
  final String currentTab;
  final ValueNotifier<bool>? isVisible;
  final Key? navBarKey;
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final bool extendBody;
  final bool extendBodyBehindAppBar;
  final Color backgroundColor;
  final Decoration? decoration;
  final List<Widget>? persistentFooterButtons;
  final bool showNavigation;
  final ValueChanged<String>? onNavChanged;

  const AdaptiveScaffold({
    super.key,
    required this.currentTab,
    this.isVisible,
    this.navBarKey,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.backgroundColor = Colors.transparent,
    this.decoration,
    this.persistentFooterButtons,
    this.showNavigation = true,
    this.onNavChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isWide =
        Responsive.isTablet(context) && Responsive.isLandscape(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget buildScaffold(bool wide) {
      final fab = (showNavigation || wide || floatingActionButton == null)
          ? floatingActionButton
          : Padding(
              padding: EdgeInsets.only(bottom: BottomNavBar.extendedHeight),
              child: floatingActionButton,
            );
      return Scaffold(
        backgroundColor: backgroundColor,
        extendBodyBehindAppBar: extendBodyBehindAppBar,
        appBar: appBar,
        body: body,
        floatingActionButton: fab,
        floatingActionButtonLocation: floatingActionButtonLocation,
        bottomNavigationBar: (!wide && showNavigation)
            ? _buildBottomNav(context, visibleTabs())
            : null,
        extendBody: extendBody && !wide,
        persistentFooterButtons: persistentFooterButtons,
      );
    }

    if (isWide && showNavigation) {
      return Container(
        decoration: decoration,
        child: _WideLayout(
          currentTab: currentTab,
          isDark: isDark,
          onNavChanged: onNavChanged,
          child: Container(
            decoration: const BoxDecoration(),
            child: GetBuilder<FeatureFlagService>(
              builder: (_) => buildScaffold(true),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: decoration,
      child: GetBuilder<FeatureFlagService>(
        builder: (_) => buildScaffold(false),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context, List<TabDestination> tabs) {
    if (isVisible != null) {
      return AnimatedBottomNav(
        currentTab: currentTab,
        destinations: tabs,
        isVisible: isVisible!,
        navBarKey: navBarKey,
      );
    }
    return BottomNavBar(currentTab: currentTab, destinations: tabs);
  }
}

class _WideLayout extends StatelessWidget {
  final String currentTab;
  final bool isDark;
  final Widget child;
  final ValueChanged<String>? onNavChanged;

  const _WideLayout({
    required this.currentTab,
    required this.isDark,
    required this.child,
    this.onNavChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AdaptiveNavigationRail(
          currentTab: currentTab,
          isDark: isDark,
          onNavChanged: onNavChanged,
        ),
        Expanded(child: child),
      ],
    );
  }
}

class AdaptiveNavigationRail extends StatelessWidget {
  final String currentTab;
  final bool isDark;
  final ValueChanged<String>? onNavChanged;

  const AdaptiveNavigationRail({
    super.key,
    required this.currentTab,
    required this.isDark,
    this.onNavChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Obx: the rail blur is toggled reactively when lite mode changes.
    return Obx(() => _buildRail(context));
  }

  Widget _buildRail(BuildContext context) {
    final railBg = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : Colors.white.withValues(alpha: 0.7);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : AppColors.lightBorder;
    final activeColor = isDark ? AppColors.primary : AppColors.primary;

    return Container(
      width: 96,
      decoration: BoxDecoration(
        color: railBg,
        border: Border(right: BorderSide(color: borderColor)),
      ),
      child: RepaintBoundary(
        child: PerformanceController.to.liteMode.value
            ? SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  child: _buildRailItems(context, activeColor),
                ),
              )
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    child: _buildRailItems(context, activeColor),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildRailItems(BuildContext ctx, Color activeColor) {
    final tabs = visibleTabs();
    if (tabs.isEmpty) return const SizedBox.shrink();
    return GetBuilder<FeatureFlagService>(
      builder: (_) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...tabs.map((d) {
            final key = d.featureKey;
            return _RailItem(
              icon: d.icon,
              label: d.label,
              active: currentTab == d.name,
              activeColor: activeColor,
              isDark: isDark,
              onTap: () {
                HapticFeedback.lightImpact();
                if (key != null && !ensureFeatureVisible(ctx, key)) {
                  return;
                }
                if (onNavChanged != null) {
                  onNavChanged!(d.name);
                } else {
                  gotoScreen(d.name);
                }
              },
            );
          }),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final bool isDark;
  final VoidCallback onTap;

  const _RailItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.45);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      child: HoverEffect(
        scale: 1.05,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16.r),
          child: InkWell(
            borderRadius: BorderRadius.circular(16.r),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              padding: EdgeInsets.symmetric(vertical: 10.h),
              decoration: BoxDecoration(
                color: active
                    ? activeColor.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16.r),
                border: active
                    ? Border.all(
                        color: activeColor.withValues(alpha: 0.25),
                        width: 1,
                      )
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: active ? activeColor : inactiveColor,
                    size: 22.sp,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppType.labelSmall(active ? activeColor : inactiveColor),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}