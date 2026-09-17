import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:money_control/Components/colors.dart';

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
        ? AppColors.primary // Neon Cyan
        : AppColors.primary; // Blurple

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
          // Floor the horizontal padding to whole logical pixels: the summed
          // pill widths feed a spaceEvenly Row, and leftover fractional
          // screenutil values can collectively exceed the row by <1px at
          // certain device widths, causing a RenderFlex overflow.
          padding: EdgeInsets.symmetric(
            horizontal: (active ? 16 : 12).w.floorToDouble(),
          ),
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
                      blurRadius: 12.w,
                      spreadRadius: -2.w,
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
                SizedBox(width: (8.w).floorToDouble()),
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
