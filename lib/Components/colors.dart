import 'package:flutter/material.dart';

//
// ────────────────────────────────────────────────
//  APP DESIGN TOKENS — premium minimal fintech
//  Single indigo accent · zinc neutrals · hairline borders
// ────────────────────────────────────────────────
//

class AppColors {
  AppColors._(); // Private constructor

  // ------------------ BRAND ------------------
  static const Color primary = Color(0xFF4F46E5); // Indigo 600
  static const Color primaryPress = Color(0xFF4338CA); // Indigo 700
  static const Color secondary = Color(0xFF6366F1); // Indigo 500
  static const Color accent = Color(0xFF8B5CF6); // Violet (charts only)

  // Containers / tints for the accent family
  static const Color primaryContainerDark = Color(0xFF312E81);

  // ------------------ BACKGROUNDS (flattened) ------------------
  // Kept as two-stop lists for source compatibility; both stops are equal so
  // every former gradient renders as a clean solid surface.
  static const List<Color> darkGradient = [
    Color(0xFF0A0A0C),
    Color(0xFF0A0A0C),
  ];

  static const List<Color> lightGradient = [
    Color(0xFFF7F7F8),
    Color(0xFFF7F7F8),
  ];

  // ------------------ ALERTS ------------------
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // ------------------ NEUTRALS (Dark Mode) ------------------
  static const Color darkBackground = Color(0xFF0A0A0C);
  static const Color darkSurface = Color(0xFF131316);
  static const Color darkSurfaceCard = Color(0xFF17171B);
  static const Color darkTextPrimary = Color(0xFFFAFAFA);
  static const Color darkTextSecondary = Color(0xFFA1A1AA);
  static const Color darkTextTertiary = Color(0xFF71717A);
  static const Color darkBorder = Color(0xFF26262B);
  static const Color darkDivider = Color(0xFF1E1E22);

  // ------------------ NEUTRALS (Light Mode) ------------------
  static const Color lightBackground = Color(0xFFF7F7F8);
  static const Color lightSurface = Colors.white;
  static const Color lightSurfaceCard = Colors.white;
  static const Color lightActionSurface = Color(0xFFF4F4F5);
  static const Color lightTextPrimary = Color(0xFF18181B);
  static const Color lightTextSecondary = Color(0xFF52525B);
  static const Color lightTextTertiary = Color(0xFFA1A1AA);
  static const Color lightBorder = Color(0xFFE4E4E7);
  static const Color lightDivider = Color(0xFFEFEFF1);
  static const Color lightGlassBg = Colors.white; // opaque now

  // ------------------ CHART SERIES ------------------
  // Distinguishable, muted; derived from the token family.
  static const List<Color> chartSeries = [
    Color(0xFF6366F1), // indigo
    Color(0xFF14B8A6), // teal
    Color(0xFFF59E0B), // amber
    Color(0xFFF43F5E), // rose
    Color(0xFF0EA5E9), // sky
    Color(0xFF8B5CF6), // violet
  ];
}

//
// ────────────────────────────────────────────────
//  RADIUS / SPACING / SHADOW TOKENS
//  (plain doubles only — ScreenUtil is not initialized at theme-build time)
// ────────────────────────────────────────────────
//

class AppRadius {
  AppRadius._();
  static const double xs = 8;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double pill = 100;
}

class AppShadows {
  AppShadows._();
  static const List<BoxShadow> cardLight = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> cardDark = [
    BoxShadow(color: Color(0x40000000), blurRadius: 10, offset: Offset(0, 3)),
  ];
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
    colorScheme: ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      error: AppColors.error,
      outline: AppColors.lightBorder,
    ),

    cardTheme: CardThemeData(
      color: AppColors.lightSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shadowColor: Color(0x22000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
      ),
    ),

    appBarTheme: AppBarTheme(
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

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.lightSurface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.lightTextTertiary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.lightSurface,
      indicatorColor: AppColors.primary.withValues(alpha: 0.13),
      iconTheme:
          WidgetStatePropertyAll(IconThemeData(color: AppColors.lightTextTertiary)),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(color: AppColors.lightTextTertiary, fontSize: 12),
      ),
    ),

    // TYPOGRAPHY — use plain doubles; ScreenUtil is not initialized at theme-build time.
    textTheme: TextTheme(
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

    dividerTheme: DividerThemeData(
      color: AppColors.lightDivider,
      thickness: 1,
    ),

    // INPUTS
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightActionSurface,
      hintStyle: TextStyle(color: AppColors.lightTextTertiary),
      labelStyle: TextStyle(color: AppColors.lightTextSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
        borderSide: BorderSide(color: AppColors.lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}

ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      error: AppColors.error,
      outline: AppColors.darkBorder,
    ),

    cardTheme: CardThemeData(
      color: AppColors.darkSurfaceCard,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shadowColor: Color(0x40000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
      ),
    ),

    appBarTheme: AppBarTheme(
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

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.darkTextTertiary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      indicatorColor: AppColors.primary.withValues(alpha: 0.20),
      iconTheme:
          WidgetStatePropertyAll(IconThemeData(color: AppColors.darkTextTertiary)),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(color: AppColors.darkTextTertiary, fontSize: 12),
      ),
    ),

    // TYPOGRAPHY — use plain doubles; ScreenUtil is not initialized at theme-build time.
    textTheme: TextTheme(
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

    dividerTheme: DividerThemeData(
      color: AppColors.darkDivider,
      thickness: 1,
    ),

    // INPUTS
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurfaceCard,
      hintStyle: TextStyle(color: AppColors.darkTextTertiary),
      labelStyle: TextStyle(color: AppColors.darkTextSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
        borderSide: BorderSide(color: AppColors.darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}
