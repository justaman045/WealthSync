import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Config/app_strings.dart';
import 'package:money_control/Config/feature_flags.dart';
import 'package:money_control/Components/colors.dart';

/// Full-screen "Coming Soon" placeholder shown to non-admin users when an admin
/// has marked a feature `comingSoon` (admins keep using the real feature to
/// develop and test it). Reached from a reactive gate or an entry-point guard.
class ComingSoonScreen extends StatelessWidget {
  final String featureTitle;
  final IconData icon;

  const ComingSoonScreen({
    super.key,
    required this.featureTitle,
    this.icon = Icons.rocket_launch_outlined,
  });

  /// Convenience from a registry key so callers only pass the flag.
  factory ComingSoonScreen.forFlag(String flagKey) {
    final flag = FeatureFlag.find(flagKey);
    return ComingSoonScreen(
      featureTitle: flag?.title ?? flagKey,
      icon: flag?.icon ?? Icons.rocket_launch_outlined,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.darkBackground, AppColors.darkSurface, AppColors.darkSurface]
              : AppColors.lightGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            AppStrings.comingSoonTitle,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24.w),
              child: GlassContainer(
                padding: EdgeInsets.all(28.w),
                borderRadius: BorderRadius.circular(24.r),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(20.w),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: AppColors.primary, size: 44.sp),
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      featureTitle,
                      textAlign: TextAlign.center,
                      style: AppType.titleLarge(isDark ? Colors.white : AppColors.lightTextPrimary),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      AppStrings.comingSoonTitle,
                      style: AppType.titleSmall(AppColors.primary),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      AppStrings.comingSoonBody,
                      textAlign: TextAlign.center,
                      style: AppType.bodyLarge(isDark ? Colors.white70 : AppColors.lightTextSecondary),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      AppStrings.comingSoonFollow,
                      textAlign: TextAlign.center,
                      style: AppType.bodySmall(isDark ? Colors.white38 : AppColors.lightTextTertiary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}