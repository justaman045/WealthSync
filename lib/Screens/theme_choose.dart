import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Components/bottom_nav_bar.dart';
import 'package:money_control/Components/colors.dart';

enum AppThemeMode { system, light, dark }

class ThemeController extends GetxController {
  final _themeMode = ThemeMode.system.obs;

  ThemeMode get themeMode => _themeMode.value;

  void setThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        _themeMode.value = ThemeMode.system;
        Get.changeThemeMode(ThemeMode.system);
        break;
      case AppThemeMode.light:
        _themeMode.value = ThemeMode.light;
        Get.changeThemeMode(ThemeMode.light);
        break;
      case AppThemeMode.dark:
        _themeMode.value = ThemeMode.dark;
        Get.changeThemeMode(ThemeMode.dark);
        break;
    }
  }

  AppThemeMode get current => _themeMode.value == ThemeMode.system
      ? AppThemeMode.system
      : _themeMode.value == ThemeMode.dark
      ? AppThemeMode.dark
      : AppThemeMode.light;
}

class ThemeSettingsScreen extends StatelessWidget {
  ThemeSettingsScreen({super.key});

  final themeController = Get.put(ThemeController());

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final surface = scheme.surface;
    final border = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface; // Used for border color
    final secondaryText = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark ? AppColors.darkGradient : AppColors.lightGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text(
            "Select App Theme",
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 18.sp,
            ),
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: scheme.onSurface,
              size: 20.sp,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          toolbarHeight: 64.h,
        ),
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 20.h),
          child: Obx(
            () => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: border, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.012),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 5.h,
                  ),
                  child: Column(
                    children: [
                      _ThemeModeTile(
                        title: "System Default",
                        subtitle: "Follow device light/dark settings",
                        icon: Icons.phone_android_rounded,
                        selected:
                            themeController.current == AppThemeMode.system,
                        onTap: () =>
                            themeController.setThemeMode(AppThemeMode.system),
                      ),
                      Divider(height: 0, color: border),
                      _ThemeModeTile(
                        title: "Light Mode",
                        subtitle: "Bright and clear appearance",
                        icon: Icons.light_mode_rounded,
                        selected: themeController.current == AppThemeMode.light,
                        onTap: () =>
                            themeController.setThemeMode(AppThemeMode.light),
                      ),
                      Divider(height: 0, color: border),
                      _ThemeModeTile(
                        title: "Dark Mode",
                        subtitle: "Reduce eye strain in low light",
                        icon: Icons.dark_mode_rounded,
                        selected: themeController.current == AppThemeMode.dark,
                        onTap: () =>
                            themeController.setThemeMode(AppThemeMode.dark),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 30.h),
                Text(
                  "Your preference will be saved and changed immediately.",
                  style: TextStyle(color: secondaryText, fontSize: 13.sp),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomNavBar(currentIndex: 2),
      ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeModeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        icon,
        color: selected
            ? scheme.primary
            : scheme.onSurface.withValues(alpha: 0.6),
        size: 27.sp,
      ),
      title: Text(
        title,
        style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12.2.sp)),
      trailing: selected
          ? Icon(Icons.check_circle, color: scheme.primary, size: 25.sp)
          : null,
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 4.w),
      minVerticalPadding: 0,
      dense: true,
    );
  }
}
