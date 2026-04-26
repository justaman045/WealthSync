import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:money_control/Components/methods.dart';
import 'package:money_control/Components/nav_item.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  const BottomNavBar({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final containerColor = isDark
        ? const Color(0xFF161622).withValues(alpha: 0.8) // Deep Dark Glass
        : Colors.white.withValues(alpha: 0.9); // White Glass for Light Mode

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.grey.withValues(alpha: 0.2);

    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.1);

    final glowColor = isDark
        ? const Color(0xFF00E5FF) // Neon Cyan
        : const Color(0xFF6C63FF); // Blurple

    return Container(
      margin: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(40.r),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: glowColor.withValues(alpha: 0.05), // Subtle Glow
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                NavItem(
                  active: currentIndex == 0,
                  icon: Icons.grid_view_rounded, // Improved Icon
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
                  label: 'Insights', // Shortened from AI Insights
                  onTap: () {
                    HapticFeedback.lightImpact();
                    gotoScreen(2, currentIndex);
                  },
                ),
                NavItem(
                  active: currentIndex == 3,
                  icon: Icons.monetization_on_outlined,
                  label: 'Wealth', // New Tab
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
    );
  }
}
