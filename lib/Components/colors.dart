import 'package:flutter/material.dart';

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
    Color(0xFFF2F4F7), // Warm off-white
    Color(0xFFD5DAE0), // Silver gray (visible depth)
  ];

  // ------------------ ALERTS ------------------
  static const Color success = Color(0xFF0FA958);
  static const Color error = Color(0xFFFF5252);
  static const Color warning = Color(0xFFFFC107);

  // ------------------ NEUTRALS (Dark Mode) ------------------
  static const Color darkBackground = Color(0xFF1A1A2E);
  static const Color darkSurface = Color(0xFF1E1E2C);
  static const Color darkSurfaceCard = Color(0xFF252538);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Colors.white60;
  static const Color darkTextTertiary = Colors.white38;
  static const Color darkBorder = Color(0xFF2D2D44);
  static const Color darkDivider = Color(0xFF2A2A3E);

  // ------------------ NEUTRALS (Light Mode) ------------------
  static const Color lightBackground = Color(0xFFF2F4F7);
  static const Color lightSurface = Colors.white;
  static const Color lightSurfaceCard = Color(0xFFF8F9FB);
  static const Color lightTextPrimary = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF4B5563);
  static const Color lightTextTertiary = Color(0xFF9CA3AF);
  static const Color lightBorder = Color(0xFFD1D5DB);
  static const Color lightDivider = Color(0xFFE5E7EB);
  static const Color lightGlassBg = Color(0xFFF8F9FB);
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
      outline: AppColors.lightBorder,
    ),

    cardTheme: const CardThemeData(
      color: AppColors.lightSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shadowColor: Color(0x1A000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.lightTextPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
      iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.lightSurface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.lightTextTertiary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),

    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.lightSurface,
      indicatorColor: Color(0x1A6C63FF),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: AppColors.lightTextTertiary)),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(color: AppColors.lightTextTertiary, fontSize: 12),
      ),
    ),

    // TYPOGRAPHY — use plain doubles; ScreenUtil is not initialized at theme-build time.
    textTheme: const TextTheme(
      bodyMedium: TextStyle(
        color: AppColors.lightTextSecondary,
        fontSize: 14,
      ),
      bodyLarge: TextStyle(color: AppColors.lightTextPrimary, fontSize: 16),
      titleLarge: TextStyle(
        color: AppColors.lightTextPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 20,
      ),
      labelSmall: TextStyle(
        color: AppColors.lightTextTertiary,
        fontSize: 12,
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.lightDivider,
      thickness: 1,
    ),

    // INPUTS
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFFECEEF2),
      hintStyle: TextStyle(color: AppColors.lightTextTertiary),
      labelStyle: TextStyle(color: AppColors.lightTextSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: AppColors.lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      outline: AppColors.darkBorder,
    ),

    cardTheme: const CardThemeData(
      color: AppColors.darkSurfaceCard,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shadowColor: Color(0x40000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.darkTextPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
      iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.darkTextTertiary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),

    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      indicatorColor: Color(0x336C63FF),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: AppColors.darkTextTertiary)),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(color: AppColors.darkTextTertiary, fontSize: 12),
      ),
    ),

    // TYPOGRAPHY — use plain doubles; ScreenUtil is not initialized at theme-build time.
    textTheme: const TextTheme(
      bodyMedium: TextStyle(
        color: AppColors.darkTextSecondary,
        fontSize: 14,
      ),
      bodyLarge: TextStyle(color: AppColors.darkTextPrimary, fontSize: 16),
      titleLarge: TextStyle(
        color: AppColors.darkTextPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 20,
      ),
      labelSmall: TextStyle(
        color: AppColors.darkTextTertiary,
        fontSize: 12,
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.darkDivider,
      thickness: 1,
    ),

    // INPUTS
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0x0DFFFFFF),
      hintStyle: TextStyle(color: AppColors.darkTextTertiary),
      labelStyle: TextStyle(color: AppColors.darkTextSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: AppColors.darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}
