import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

//
// ────────────────────────────────────────────────
//  🎨 APP COLORS SYSTEM
// ────────────────────────────────────────────────
//

class AppColors {
  AppColors._(); // Private constructor

  // ------------------ BRAND COLORS ------------------
  static const Color primary = Color(0xFF6C63FF); // Main Purple/Blurple
  static const Color secondary = Color(0xFF00E5FF); // Cyan/Neon Blue
  static const Color accent = Color(0xFFFF4081); // Pink Accent

  // ------------------ GRADIENTS ------------------
  static const List<Color> darkGradient = [
    Color(0xFF1A1A2E), // Midnight Void
    Color(0xFF16213E), // Deep Blue
  ];

  static const List<Color> lightGradient = [
    Color(0xFFF5F7FA), // Premium Light
    Color(0xFFC3CFE2), // Soft Blue-Grey
  ];

  // ------------------ ALERTS ------------------
  static const Color success = Color(0xFF0FA958);
  static const Color error = Color(0xFFFF5252);
  static const Color warning = Color(0xFFFFC107);

  // ------------------ NEUTRALS (Dark Mode) ------------------
  static const Color darkBackground = Color(0xFF1A1A2E);
  static const Color darkSurface = Color(0xFF1E1E2C);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Colors.white60;

  // ------------------ NEUTRALS (Light Mode) ------------------
  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color lightSurface = Colors.white;
  static const Color lightTextPrimary = Color(0xFF1A1A2E);
  static const Color lightTextSecondary = Color(0xFF757575);
  static const Color lightBorder = Color(0xFFE0E0E0);
  static const Color lightDivider = Color(0xFFE0E0E0);
}

//
// ────────────────────────────────────────────────
//  THEME DATA
// ────────────────────────────────────────────────
//

ThemeData buildLightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBackground,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      error: AppColors.error,
    ),

    // TYPOGRAPHY
    textTheme: TextTheme(
      bodyMedium: TextStyle(
        color: AppColors.lightTextSecondary,
        fontSize: 14.sp,
      ),
      bodyLarge: TextStyle(color: AppColors.lightTextPrimary, fontSize: 16.sp),
      titleLarge: TextStyle(
        color: AppColors.lightTextPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 20.sp,
      ),
    ),

    // INPUTS
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.05),
      hintStyle: const TextStyle(color: AppColors.lightTextSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide.none,
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
    ),
  );
}

ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      error: AppColors.error,
    ),

    // TYPOGRAPHY
    textTheme: TextTheme(
      bodyMedium: TextStyle(
        color: AppColors.darkTextSecondary,
        fontSize: 14.sp,
      ),
      bodyLarge: TextStyle(color: AppColors.darkTextPrimary, fontSize: 16.sp),
      titleLarge: TextStyle(
        color: AppColors.darkTextPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 20.sp,
      ),
    ),

    // INPUTS
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      hintStyle: const TextStyle(color: AppColors.darkTextSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide.none,
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
    ),
  );
}
