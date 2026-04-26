import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class NavItem extends StatelessWidget {
  final bool active;
  final IconData icon;
  final String? label;
  final VoidCallback? onTap;

  const NavItem({
    super.key,
    required this.active,
    required this.icon,
    this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeColor = isDark
        ? const Color(0xFF00E5FF) // Neon Cyan
        : const Color(0xFF6C63FF); // Blurple

    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : Colors.black.withValues(alpha: 0.5);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(30.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(30.r),
        onTap: () {
          if (onTap != null) {
            HapticFeedback.lightImpact();
            onTap!();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          height: 42.h,
          padding: EdgeInsets.symmetric(horizontal: active ? 16.w : 12.w),
          decoration: BoxDecoration(
            color: active
                ? activeColor.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(30.r),
            border: active
                ? Border.all(
                    color: activeColor.withValues(alpha: 0.3),
                    width: 1,
                  )
                : null,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.2),
                      blurRadius: 12,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: active ? activeColor : inactiveColor,
                size: 22.sp,
              ),
              if (active && label != null) ...[
                SizedBox(width: 8.w),
                Text(
                  label!,
                  style: TextStyle(
                    color: activeColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
