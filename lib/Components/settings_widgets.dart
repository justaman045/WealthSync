import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:money_control/Components/colors.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: 15.h, top: 10.h, left: 5.w),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            color: isDark ? Colors.white54 : AppColors.lightTextSecondary,
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class SectionDivider extends StatelessWidget {
  const SectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Divider(color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lightBorder.withValues(alpha: 0.1)),
    );
  }
}

class SettingsTile extends StatelessWidget {
  final IconData? icon;
  final String title;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? textColor;
  final Widget? trailing;

  const SettingsTile({
    super.key,
    this.icon,
    required this.title,
    this.onTap,
    this.iconColor,
    this.textColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.lightBorder.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: (iconColor ?? const Color(0xFF00E5FF)).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: iconColor ?? const Color(0xFF00E5FF),
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 16.w),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: textColor ?? (isDark ? Colors.white : AppColors.lightTextPrimary),
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (trailing != null)
                  trailing!
                else
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.2),
                    size: 16.sp,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
