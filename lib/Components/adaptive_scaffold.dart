import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:money_control/Components/animated_bottom_nav.dart';
import 'package:money_control/Components/bottom_nav_bar.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/hover_effect.dart';
import 'package:money_control/Components/methods.dart';
import 'package:money_control/Utils/responsive.dart';

class AdaptiveScaffold extends StatelessWidget {
  final int currentIndex;
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

  const AdaptiveScaffold({
    super.key,
    required this.currentIndex,
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
  });

  static const _destinations = [
    _NavDestination(icon: Icons.grid_view_rounded, label: 'Home', index: 0),
    _NavDestination(
      icon: Icons.pie_chart_outline_rounded,
      label: 'Analytics',
      index: 1,
    ),
    _NavDestination(
      icon: Icons.auto_awesome_outlined,
      label: 'Insights',
      index: 2,
    ),
    _NavDestination(
      icon: Icons.monetization_on_outlined,
      label: 'Wealth',
      index: 3,
    ),
    _NavDestination(
      icon: Icons.tune_rounded,
      label: 'Settings',
      index: 4,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = Responsive.isTablet(context) && Responsive.isLandscape(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final scaffold = Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: isWide ? null : _buildBottomNav(context),
      extendBody: extendBody && !isWide,
      persistentFooterButtons: persistentFooterButtons,
    );

    if (isWide) {
      return Container(
        decoration: decoration,
        child: _WideLayout(
          currentIndex: currentIndex,
          isDark: isDark,
          child: scaffold,
        ),
      );
    }

    return Container(
      decoration: decoration,
      child: scaffold,
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    if (isVisible != null) {
      return AnimatedBottomNav(
        currentIndex: currentIndex,
        isVisible: isVisible!,
        navBarKey: navBarKey,
      );
    }
    return BottomNavBar(currentIndex: currentIndex);
  }
}

class _WideLayout extends StatelessWidget {
  final int currentIndex;
  final bool isDark;
  final Widget child;

  const _WideLayout({
    required this.currentIndex,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final railBg = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : Colors.white.withValues(alpha: 0.7);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : AppColors.lightBorder;
    final activeColor = isDark
        ? const Color(0xFF00E5FF)
        : const Color(0xFF6C63FF);

    return Row(
      children: [
        Container(
          width: 96,
          decoration: BoxDecoration(
            color: railBg,
            border: Border(right: BorderSide(color: borderColor)),
          ),
          child: RepaintBoundary(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ...AdaptiveScaffold._destinations.map(
                        (d) => _RailItem(
                          icon: d.icon,
                          label: d.label,
                          active: currentIndex == d.index,
                          activeColor: activeColor,
                          isDark: isDark,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            gotoScreen(d.index, currentIndex);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
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
                  style: TextStyle(
                    color: active ? activeColor : inactiveColor,
                    fontSize: 11.sp,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
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
}

class _NavDestination {
  final IconData icon;
  final String label;
  final int index;

  const _NavDestination({
    required this.icon,
    required this.label,
    required this.index,
  });
}
