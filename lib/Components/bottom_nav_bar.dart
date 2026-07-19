import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:money_control/Components/methods.dart';
import 'package:money_control/Components/nav_item.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Utils/responsive.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  const BottomNavBar({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = Responsive.isTablet(context);

    final containerColor = isDark
        ? const Color(0xFF161622).withValues(alpha: 0.8)
        : Colors.white.withValues(alpha: 0.95);

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : AppColors.lightBorder;

    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.12);

    final glowColor = isDark
        ? const Color(0xFF00E5FF)
        : AppColors.primary;

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
          child: isTablet
              ? Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      NavItem(
                        active: currentIndex == 0,
                        icon: Icons.grid_view_rounded,
                        label: 'Home',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          gotoScreen(0, currentIndex);
                        },
                      ),
                      NavItem(
                        active: currentIndex == 1,
                        icon: Icons.pie_chart_outline_rounded,
                        label: 'Analytics',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          gotoScreen(1, currentIndex);
                        },
                      ),
                      NavItem(
                        active: currentIndex == 2,
                        icon: Icons.auto_awesome_outlined,
                        label: 'Insights',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          gotoScreen(2, currentIndex);
                        },
                      ),
                      NavItem(
                        active: currentIndex == 3,
                        icon: Icons.monetization_on_outlined,
                        label: 'Wealth',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          gotoScreen(3, currentIndex);
                        },
                      ),
                      NavItem(
                        active: currentIndex == 4,
                        icon: Icons.tune_rounded,
                        label: 'Settings',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          gotoScreen(4, currentIndex);
                        },
                      ),
                    ],
                  ),
                )
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        NavItem(
                          active: currentIndex == 0,
                          icon: Icons.grid_view_rounded,
                          label: 'Home',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            gotoScreen(0, currentIndex);
                          },
                        ),
                        NavItem(
                          active: currentIndex == 1,
                          icon: Icons.pie_chart_outline_rounded,
                          label: 'Analytics',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            gotoScreen(1, currentIndex);
                          },
                        ),
                        NavItem(
                          active: currentIndex == 2,
                          icon: Icons.auto_awesome_outlined,
                          label: 'Insights',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            gotoScreen(2, currentIndex);
                          },
                        ),
                        NavItem(
                          active: currentIndex == 3,
                          icon: Icons.monetization_on_outlined,
                          label: 'Wealth',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            gotoScreen(3, currentIndex);
                          },
                        ),
                        NavItem(
                          active: currentIndex == 4,
                          icon: Icons.tune_rounded,
                          label: 'Settings',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            gotoScreen(4, currentIndex);
                          },
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
