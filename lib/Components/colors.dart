import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:money_control/Components/design_tokens.dart';

// Layout, typography, motion and radius tokens live in design_tokens.dart.
// Re-exported here so the ~60 files that already import colors.dart keep
// resolving `AppRadius` / `AppSpace` without a second import.
export 'package:money_control/Components/design_tokens.dart';

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

  /// ≥4.5:1 against `darkSurfaceCard`, the lightest dark surface it can land
  /// on. The previous 0xFF71717A measured 4.05:1 and failed WCAG AA.
  static const Color darkTextTertiary = Color(0xFF8A8A94);
  static const Color darkBorder = Color(0xFF26262B);
  static const Color darkDivider = Color(0xFF1E1E22);

  // ------------------ NEUTRALS (Light Mode) ------------------
  static const Color lightBackground = Color(0xFFF7F7F8);
  static const Color lightSurface = Colors.white;
  static const Color lightSurfaceCard = Colors.white;
  static const Color lightActionSurface = Color(0xFFF4F4F5);
  static const Color lightTextPrimary = Color(0xFF18181B);
  static const Color lightTextSecondary = Color(0xFF52525B);

  /// ≥4.5:1 against `lightActionSurface`, the darkest light surface it can land
  /// on. The previous 0xFFA1A1AA measured 2.41:1 and failed WCAG AA.
  static const Color lightTextTertiary = Color(0xFF6B6B74);
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
//  THEME DATA
//
//  One builder for both modes. Before this, light and dark were two ~100-line
//  hand-maintained copies that had already drifted (elevation 1 vs 2, different
//  shadow alphas, different navigation indicator alphas) and between them
//  styled only 7 of the ~24 component types (no dialog, snackbar, button,
//  chip, switch, slider, tab, sheet, popup, tooltip, progress or FAB theme),
//  so every one of those fell back to raw Material defaults next to custom
//  glass cards.
// ────────────────────────────────────────────────
//

/// The semantic surface/text set for one brightness. Widgets never need to
/// branch on `isDark` to pick a token.
class _Palette {
  const _Palette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceCard,
    required this.actionSurface,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.divider,
  });

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceCard;
  final Color actionSurface;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color border;
  final Color divider;

  bool get isDark => brightness == Brightness.dark;
}

const _Palette _lightPalette = _Palette(
  brightness: Brightness.light,
  background: AppColors.lightBackground,
  surface: AppColors.lightSurface,
  surfaceCard: AppColors.lightSurfaceCard,
  actionSurface: AppColors.lightActionSurface,
  textPrimary: AppColors.lightTextPrimary,
  textSecondary: AppColors.lightTextSecondary,
  textTertiary: AppColors.lightTextTertiary,
  border: AppColors.lightBorder,
  divider: AppColors.lightDivider,
);

const _Palette _darkPalette = _Palette(
  brightness: Brightness.dark,
  background: AppColors.darkBackground,
  surface: AppColors.darkSurface,
  surfaceCard: AppColors.darkSurfaceCard,
  actionSurface: AppColors.darkSurfaceCard,
  textPrimary: AppColors.darkTextPrimary,
  textSecondary: AppColors.darkTextSecondary,
  textTertiary: AppColors.darkTextTertiary,
  border: AppColors.darkBorder,
  divider: AppColors.darkDivider,
);

ThemeData buildLightTheme() => _buildTheme(_lightPalette);

ThemeData buildDarkTheme() => _buildTheme(_darkPalette);

ThemeData _buildTheme(_Palette p) {
  const primary = AppColors.primary;
  final onPrimary = Colors.white;
  final accentTint = primary.withValues(alpha: p.isDark ? 0.24 : 0.12);
  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
  );
  final fieldShape = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.lg),
    borderSide: BorderSide.none,
  );
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.lg),
  );
  const buttonMinSize = Size(64, 48); // 48 dp minimum tap target
  final buttonPadding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12);

  final scheme = ColorScheme(
    brightness: p.brightness,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: accentTint,
    onPrimaryContainer: primary,
    secondary: AppColors.secondary,
    onSecondary: onPrimary,
    secondaryContainer: AppColors.secondary.withValues(
      alpha: p.isDark ? 0.24 : 0.12,
    ),
    onSecondaryContainer: AppColors.secondary,
    tertiary: AppColors.accent,
    onTertiary: onPrimary,
    tertiaryContainer: AppColors.accent.withValues(alpha: p.isDark ? 0.24 : 0.12),
    onTertiaryContainer: AppColors.accent,
    error: AppColors.error,
    onError: onPrimary,
    errorContainer: AppColors.error.withValues(alpha: p.isDark ? 0.24 : 0.12),
    onErrorContainer: AppColors.error,
    surface: p.surface,
    onSurface: p.textPrimary,
    onSurfaceVariant: p.textSecondary,
    surfaceContainerLowest: p.background,
    surfaceContainerLow: p.surface,
    surfaceContainer: p.surfaceCard,
    surfaceContainerHigh: p.surfaceCard,
    surfaceContainerHighest: p.actionSurface,
    outline: p.border,
    outlineVariant: p.divider,
    inverseSurface: p.textPrimary,
    onInverseSurface: p.surface,
    inversePrimary: AppColors.primaryPress,
    surfaceTint: Colors.transparent,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  final textTheme = TextTheme(
    displayLarge: AppType.displayLarge(p.textPrimary),
    displayMedium: AppType.displayMedium(p.textPrimary),
    displaySmall: AppType.displaySmall(p.textPrimary),
    headlineLarge: AppType.headlineLarge(p.textPrimary),
    headlineMedium: AppType.headlineMedium(p.textPrimary),
    headlineSmall: AppType.headlineSmall(p.textPrimary),
    titleLarge: AppType.titleLarge(p.textPrimary),
    titleMedium: AppType.titleMedium(p.textPrimary),
    titleSmall: AppType.titleSmall(p.textPrimary),
    bodyLarge: AppType.bodyLarge(p.textPrimary),
    bodyMedium: AppType.bodyMedium(p.textSecondary),
    bodySmall: AppType.bodySmall(p.textTertiary),
    labelLarge: AppType.labelLarge(p.textPrimary),
    labelMedium: AppType.labelMedium(p.textSecondary),
    labelSmall: AppType.labelSmall(p.textTertiary),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: p.brightness,
    fontFamily: kAppFontFamily,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    colorScheme: scheme,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    disabledColor: p.textTertiary.withValues(alpha: 0.5),
    iconTheme: IconThemeData(color: p.textSecondary, size: 22),

    // ------------------ SURFACES ------------------
    cardTheme: CardThemeData(
      color: p.surfaceCard,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: cardShape,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: AppType.titleLarge(p.textPrimary).copyWith(fontSize: 19),
      iconTheme: IconThemeData(color: p.textPrimary, size: 22),
      actionsIconTheme: IconThemeData(color: p.textPrimary, size: 22),
      systemOverlayStyle: p.isDark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
    ),

    dividerTheme: DividerThemeData(
      color: p.divider,
      thickness: 1,
      space: 1,
    ),

    listTileTheme: ListTileThemeData(
      iconColor: p.textSecondary,
      textColor: p.textPrimary,
      subtitleTextStyle: AppType.bodySmall(p.textTertiary),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
    ),

    // ------------------ NAVIGATION ------------------
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: p.surface,
      selectedItemColor: primary,
      unselectedItemColor: p.textTertiary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: AppType.labelSmall(primary),
      unselectedLabelStyle: AppType.labelSmall(p.textTertiary),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: accentTint,
      indicatorShape: const StadiumBorder(),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected)
              ? primary
              : p.textTertiary,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? AppType.labelSmall(primary)
            : AppType.labelSmall(p.textTertiary);
      }),
    ),

    tabBarTheme: TabBarThemeData(
      labelColor: primary,
      unselectedLabelColor: p.textSecondary,
      indicatorColor: primary,
      dividerColor: p.divider,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: AppType.labelLarge(primary),
      unselectedLabelStyle: AppType.labelLarge(p.textSecondary),
    ),

    // ------------------ OVERLAYS ------------------
    dialogTheme: DialogThemeData(
      backgroundColor: p.surfaceCard,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(color: p.border),
      ),
      titleTextStyle: AppType.titleLarge(p.textPrimary),
      contentTextStyle: AppType.bodyMedium(p.textSecondary),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s24,
        vertical: AppSpace.s24,
      ),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surfaceCard,
      modalBackgroundColor: p.surfaceCard,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      dragHandleColor: p.border,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: p.surfaceCard,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      textStyle: AppType.bodyMedium(p.textPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: p.border),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      // Inverse surface: dark bar on a light app, lifted neutral on a dark one.
      backgroundColor: p.isDark ? p.border : AppColors.lightTextPrimary,
      contentTextStyle: AppType.bodyMedium(onPrimary),
      actionTextColor: AppColors.secondary,
      elevation: 0,
      insetPadding: const EdgeInsets.all(AppSpace.s16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: p.textPrimary,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      textStyle: AppType.bodySmall(p.surface),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s12,
        vertical: AppSpace.s8,
      ),
      waitDuration: const Duration(milliseconds: 500),
    ),

    // ------------------ CONTROLS ------------------
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        disabledBackgroundColor: primary.withValues(alpha: 0.38),
        disabledForegroundColor: onPrimary.withValues(alpha: 0.60),
        elevation: 0,
        shadowColor: Colors.transparent,
        minimumSize: buttonMinSize,
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: AppType.labelLarge(onPrimary),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.surfaceCard,
        foregroundColor: p.textPrimary,
        disabledBackgroundColor: p.actionSurface,
        disabledForegroundColor: p.textTertiary,
        elevation: 0,
        shadowColor: Colors.transparent,
        minimumSize: buttonMinSize,
        padding: buttonPadding,
        shape: buttonShape,
        side: BorderSide(color: p.border),
        textStyle: AppType.labelLarge(p.textPrimary),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.textPrimary,
        disabledForegroundColor: p.textTertiary,
        minimumSize: buttonMinSize,
        padding: buttonPadding,
        shape: buttonShape,
        side: BorderSide(color: p.border),
        textStyle: AppType.labelLarge(p.textPrimary),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        disabledForegroundColor: p.textTertiary,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: AppType.labelLarge(primary),
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: p.textPrimary,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: onPrimary,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: p.actionSurface,
      selectedColor: accentTint,
      disabledColor: p.actionSurface.withValues(alpha: 0.5),
      side: BorderSide(color: p.border),
      shape: const StadiumBorder(),
      labelStyle: AppType.labelMedium(p.textSecondary),
      secondaryLabelStyle: AppType.labelMedium(primary),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s8,
        vertical: AppSpace.s4,
      ),
      showCheckmark: false,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected) ? onPrimary : p.textTertiary;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected) ? primary : p.border;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected) ? primary : p.border;
      }),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected) ? primary : Colors.transparent;
      }),
      checkColor: WidgetStatePropertyAll(onPrimary),
      side: BorderSide(color: p.border, width: 1.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xs / 2),
      ),
    ),

    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected) ? primary : p.border;
      }),
    ),

    sliderTheme: SliderThemeData(
      activeTrackColor: primary,
      inactiveTrackColor: p.border,
      thumbColor: primary,
      overlayColor: primary.withValues(alpha: 0.12),
      trackHeight: 4,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? accentTint
              : Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? primary
              : p.textSecondary;
        }),
        side: WidgetStatePropertyAll(BorderSide(color: p.border)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
        textStyle: WidgetStatePropertyAll(AppType.labelMedium(p.textSecondary)),
        minimumSize: const WidgetStatePropertyAll(Size(48, 40)),
      ),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primary,
      linearTrackColor: p.border,
      circularTrackColor: Colors.transparent,
    ),

    badgeTheme: BadgeThemeData(
      backgroundColor: AppColors.error,
      textColor: onPrimary,
      textStyle: AppType.labelSmall(onPrimary),
    ),

    textSelectionTheme: TextSelectionThemeData(
      cursorColor: primary,
      selectionColor: primary.withValues(alpha: 0.25),
      selectionHandleColor: primary,
    ),

    // ------------------ INPUTS ------------------
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.actionSurface,
      hintStyle: AppType.bodyMedium(p.textTertiary),
      labelStyle: AppType.bodyMedium(p.textSecondary),
      floatingLabelStyle: AppType.labelMedium(primary),
      helperStyle: AppType.bodySmall(p.textTertiary),
      errorStyle: AppType.bodySmall(AppColors.error),
      border: fieldShape,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: p.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s16,
        vertical: AppSpace.s12,
      ),
    ),
  );
}
