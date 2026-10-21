import 'package:flutter/material.dart';
import 'package:money_control/Components/colors.dart';

/// The glass surface the analytics cards share.
///
/// The analytics screen used to own these three helpers privately, which meant
/// every card that moved out had to be handed its colours as parameters — six
/// of them, and a chance to pass the wrong one for the wrong surface.
///
/// `isDark` is passed in rather than read from `Theme.of(context)` on purpose:
/// the screen caches the theme for the whole build (a `Theme.of` call per
/// card is exactly what that cache exists to avoid), and a cached value is
/// still the value the card would have read.
class AnalyticsTokens {
  const AnalyticsTokens._();

  /// The primary text colour on the analytics surface.
  static Color text(bool isDark, [double opacity = 1]) => isDark
      ? Colors.white.withValues(alpha: opacity)
      : AppColors.lightTextPrimary.withValues(alpha: opacity);

  /// The secondary text colour on the analytics surface.
  ///
  /// The dark surface fades the text towards white; the light surface has no
  /// faded variant of its secondary colour, so the opacity only applies in
  /// dark mode.
  static Color mutedText(bool isDark, [double opacity = 1]) => isDark
      ? Colors.white.withValues(alpha: opacity)
      : AppColors.lightTextSecondary;

  /// The fill of a glass card.
  static Color glassBackground(bool isDark) => isDark
      ? Colors.white.withValues(alpha: 0.05)
      : AppColors.lightSurface;

  /// The hairline border of a glass card.
  static Color glassBorder(bool isDark) => isDark
      ? Colors.white.withValues(alpha: 0.1)
      : AppColors.lightBorder;
}
