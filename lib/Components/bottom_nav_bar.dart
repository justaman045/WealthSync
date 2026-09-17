import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Components/methods.dart';
import 'package:money_control/Components/nav_item.dart';
import 'package:money_control/Config/tab_destinations.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Services/performance_controller.dart';
import 'package:money_control/Utils/responsive.dart';

class BottomNavBar extends StatelessWidget {
  final String currentTab;
  final List<TabDestination> destinations;
  final ValueChanged<String>? onTab;
  const BottomNavBar({
    super.key,
    required this.currentTab,
    required this.destinations,
    this.onTab,
  });

  /// Height of the floating nav bar from the screen bottom (bottom margin +
  /// vertical padding + item height). Embedded screens lift their FABs by
  /// this amount so they render above the pill.
  static double get extendedHeight => 24.h + 42.h + 20.h;

  @override
  Widget build(BuildContext context) {
    // Obx: the blur is toggled reactively when lite mode changes in Settings.
    return Obx(() => _build(context));
  }

  Widget _build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = Responsive.isTablet(context);
    final lite = PerformanceController.to.liteMode.value;

    if (destinations.isEmpty) return const SizedBox.shrink();

    final containerColor = isDark
        ? const Color(0xFF161622).withValues(alpha: 0.8)
        : Colors.white.withValues(alpha: 0.95);

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : AppColors.lightBorder;

    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.12);

    final glowColor = isDark ? AppColors.primary : AppColors.primary;

    final navRow = Padding(
      padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 10.h),
      // spaceEvenly (NOT spaceBetween) so the remaining tabs are distributed
      // evenly whenever an admin hides one: spaceBetween crams the items to
      // the two edges and leaves a single wide gap where the tab used to be.
      // Each item keeps its natural width (the active label pill can be ~120px
      // wide, so forcing equal Flex slices overflows at 5 tabs on a phone).
      // The 13.w horizontal padding is deliberate headroom: pill widths come
      // from fractional screenutil values + scaled text, and their sum can
      // exceed the spaceEvenly Row by <1px at ~390dp width (a 0.209px
      // RenderFlex overflow was seen on-device) unless the Row keeps slack.
      // SpaceEvenly then rebalances the extra room across the gaps.
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final d in destinations) _navItem(d),
        ],
      ),
    );

    return Container(
      margin: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(40.r),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 20.w,
            offset: Offset(0.w, 10.w),
          ),
          BoxShadow(
            color: glowColor.withValues(alpha: 0.05),
            blurRadius: 15.w,
            spreadRadius: 2.w,
          ),
        ],
      ),
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40.r),
          child: isTablet || lite
              ? navRow
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: navRow,
                ),
        ),
      ),
    );
  }

  Widget _navItem(TabDestination d) {
    return NavItem(
      active: currentTab == d.name,
      icon: d.icon,
      label: d.label,
      onTap: () {
        HapticFeedback.lightImpact();
        if (onTab != null) {
          onTab!(d.name);
        } else {
          gotoScreen(d.name);
        }
      },
    );
  }
}