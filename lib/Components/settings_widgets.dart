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
      padding: EdgeInsets.only(
        bottom: AppSpace.s16.h,
        top: AppSpace.s8.h,
        left: AppSpace.s4.w,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: AppType.labelMedium(
            isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
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
      padding: EdgeInsets.symmetric(vertical: AppSpace.s8.h),
      // A hairline, not a 10%-alpha border: the light-mode 0.1 alpha of an
      // already-pale border rendered as nothing at all.
      child: Divider(
        height: 1,
        thickness: 1,
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? textColor;
  final Widget? trailing;

  const SettingsTile({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.iconColor,
    this.textColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpace.s12.h),
      child: Material(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg.r),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpace.s16.w,
              vertical: AppSpace.s16.h,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg.r),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: iconColor ?? AppColors.primary,
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 16.w),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppType.titleSmall(
                          textColor ??
                              (isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary),
                        ),
                      ),
                      if (subtitle != null) ...[
                        SizedBox(height: AppSpace.s4.h),
                        Text(
                          subtitle!,
                          style: AppType.bodySmall(
                            isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing!
                else
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
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
