import 'package:flutter/material.dart';

//
// ────────────────────────────────────────────────
//  DESIGN TOKENS — typography, space, radius, motion, elevation
//
//  Plain doubles only: ScreenUtil is NOT initialised when the theme is
//  built (see colors.dart). Call sites append the `.w` / `.h` / `.r`
//  extension at the point of use:
//
//      SizedBox(height: AppSpace.s16.h)
//      BorderRadius.circular(AppRadius.lg.r)
//
//  `AppType` takes the colour as a parameter instead of importing
//  AppColors, so this file stays a leaf (no import cycle with colors.dart).
// ────────────────────────────────────────────────
//

/// Single UI typeface. Bundled as a static weight family in pubspec.yaml so
/// the app never depends on a runtime font fetch (or a web FOUT).
const String kAppFontFamily = 'Inter';

///
/// ────────────────────────────────────────────────
///  TYPOGRAPHY
/// ────────────────────────────────────────────────
///
/// The full Material 3 role set. Before this existed the app had 777 raw
/// `fontSize:` values across 33 distinct sizes (including 12.5 / 11.5 / 13.5),
/// so no two screens agreed on what a "body" or a "caption" was.
///
/// Display / headline / title roles carry tabular figures: they are used for
/// money, and proportional digits make the balance count-up re-flow on every
/// frame. Prose roles stay proportional.
class AppType {
  AppType._();

  /// Lining, fixed-width digits. Use on any figure that changes in place.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static TextStyle _base({
    required Color color,
    required double size,
    required FontWeight weight,
    required double height,
    double tracking = 0,
    bool numeric = false,
  }) {
    return TextStyle(
      fontFamily: kAppFontFamily,
      color: color,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: tracking,
      fontFeatures: numeric ? tabular : null,
    );
  }

  // ------------------ DISPLAY ------------------
  static TextStyle displayLarge(Color color) => _base(
    color: color,
    size: 57,
    weight: FontWeight.w700,
    height: 1.12,
    tracking: -1.5,
    numeric: true,
  );

  static TextStyle displayMedium(Color color) => _base(
    color: color,
    size: 45,
    weight: FontWeight.w700,
    height: 1.14,
    tracking: -1.0,
    numeric: true,
  );

  static TextStyle displaySmall(Color color) => _base(
    color: color,
    size: 36,
    weight: FontWeight.w700,
    height: 1.16,
    tracking: -0.8,
    numeric: true,
  );

  // ------------------ HEADLINE ------------------
  static TextStyle headlineLarge(Color color) => _base(
    color: color,
    size: 32,
    weight: FontWeight.w700,
    height: 1.2,
    tracking: -0.6,
    numeric: true,
  );

  static TextStyle headlineMedium(Color color) => _base(
    color: color,
    size: 28,
    weight: FontWeight.w700,
    height: 1.22,
    tracking: -0.4,
    numeric: true,
  );

  static TextStyle headlineSmall(Color color) => _base(
    color: color,
    size: 24,
    weight: FontWeight.w600,
    height: 1.25,
    tracking: -0.3,
    numeric: true,
  );

  // ------------------ TITLE ------------------
  static TextStyle titleLarge(Color color) => _base(
    color: color,
    size: 22,
    weight: FontWeight.w600,
    height: 1.3,
    tracking: -0.2,
    numeric: true,
  );

  static TextStyle titleMedium(Color color) => _base(
    color: color,
    size: 16,
    weight: FontWeight.w600,
    height: 1.35,
    tracking: 0,
    numeric: true,
  );

  static TextStyle titleSmall(Color color) => _base(
    color: color,
    size: 14,
    weight: FontWeight.w600,
    height: 1.35,
    tracking: 0.1,
    numeric: true,
  );

  // ------------------ BODY ------------------
  static TextStyle bodyLarge(Color color) => _base(
    color: color,
    size: 16,
    weight: FontWeight.w400,
    height: 1.5,
  );

  static TextStyle bodyMedium(Color color) => _base(
    color: color,
    size: 14,
    weight: FontWeight.w400,
    height: 1.5,
  );

  static TextStyle bodySmall(Color color) => _base(
    color: color,
    size: 12,
    weight: FontWeight.w400,
    height: 1.45,
    tracking: 0.1,
  );

  // ------------------ LABEL ------------------
  static TextStyle labelLarge(Color color) => _base(
    color: color,
    size: 14,
    weight: FontWeight.w600,
    height: 1.3,
    tracking: 0.2,
  );

  static TextStyle labelMedium(Color color) => _base(
    color: color,
    size: 12,
    weight: FontWeight.w600,
    height: 1.3,
    tracking: 0.3,
  );

  static TextStyle labelSmall(Color color) => _base(
    color: color,
    size: 11,
    weight: FontWeight.w600,
    height: 1.3,
    tracking: 0.4,
  );

  // ------------------ SPECIAL ------------------

  /// Headline money figure (balance card, net worth, totals). Tabular so the
  /// count-up animation never shifts the layout.
  static TextStyle money({
    required Color color,
    double size = 36,
    FontWeight weight = FontWeight.w700,
  }) {
    return _base(
      color: color,
      size: size,
      weight: weight,
      height: 1.1,
      tracking: -1.0,
      numeric: true,
    );
  }

  /// Opt an arbitrary style into tabular figures — used where a figure sits in
  /// a prose role (e.g. an amount inside a `bodyMedium` list row).
  static TextStyle numericOf(TextStyle style) {
    return style.copyWith(fontFeatures: tabular);
  }
}

///
/// ────────────────────────────────────────────────
///  SPACING
/// ────────────────────────────────────────────────
///
/// A 4-based scale. The codebase previously used 16 distinct vertical gaps and
/// 10 distinct page paddings picked per screen.
class AppSpace {
  AppSpace._();

  static const double s2 = 2;
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;

  /// Horizontal page gutter. One value for every scrollable screen body.
  static const double pageGutter = 16;
}

///
/// ────────────────────────────────────────────────
///  RADIUS
/// ────────────────────────────────────────────────
///
/// Consolidated from 20 distinct values (2, 3, 4, 6, 8, 10, 12, 14, 16, 18,
/// 20, 22, 24, 26, 28, 30, …) to this seven-step scale. Migration maps every
/// ad-hoc radius to its nearest step; nothing here is new geometry.
class AppRadius {
  AppRadius._();

  /// Chips, badges, tiny pills.
  static const double xs = 8;

  /// Small controls, inline tiles.
  static const double sm = 10;

  /// Cards, list tiles.
  static const double md = 14;

  /// Inputs, buttons.
  static const double lg = 18;

  /// Sheets, hero cards.
  static const double xl = 24;

  /// Feature surfaces (balance card, modals).
  static const double xxl = 32;

  /// Fully rounded.
  static const double pill = 100;
}

///
/// ────────────────────────────────────────────────
///  MOTION
/// ────────────────────────────────────────────────
///
/// Durations were previously written inline per widget (150 / 200 / 300 / 400 /
/// 600 / 800 ms, no shared source).
class AppMotion {
  AppMotion._();

  /// State change on an already-visible control (chip toggle, tile press).
  static const Duration fast = Duration(milliseconds: 150);

  /// Default widget transition (expand, fade, slide between states).
  static const Duration base = Duration(milliseconds: 250);

  /// Larger surface change (sheet, card resize).
  static const Duration slow = Duration(milliseconds: 400);

  /// One-shot entrance of a screen's content.
  static const Duration entrance = Duration(milliseconds: 600);

  /// Delay step between staggered entrance items.
  static const Duration stagger = Duration(milliseconds: 80);

  /// Standard easing for movement and size changes.
  static const Curve standard = Curves.easeOutCubic;

  /// Decelerating, for values that settle (money count-up).
  static const Curve emphasized = Curves.easeOutExpo;

  /// Entrance only — never for an ongoing state change.
  static const Curve entranceCurve = Curves.easeOutBack;
}

///
/// ────────────────────────────────────────────────
///  ELEVATION
/// ────────────────────────────────────────────────
///
/// Three levels, matching the hairline-border direction of the design system.
/// Earlier surfaces each invented their own `BoxShadow` (blur 8/10/12/20/30,
/// spread 1/2/5, alphas 0.05–0.4).
class AppElevation {
  AppElevation._();

  /// Borderless flat surface — separated by a hairline, no shadow.
  static const List<BoxShadow> none = [];

  /// Resting card.
  static List<BoxShadow> raised({required bool isDark}) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
        blurRadius: 12,
        offset: const Offset(0, 3),
      ),
    ];
  }

  /// Overlay / floating element (sheet, FAB, popover).
  static List<BoxShadow> floating({required bool isDark}) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.10),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ];
  }
}
