import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Components/colors.dart';

/// Contract tests for the design-token layer.
///
/// Two things are being pinned here:
///
/// 1. **Text contrast.** The palette shipped `lightTextTertiary` at 2.41:1 and
///    `darkTextTertiary` at 4.05:1 — both below WCAG AA (4.5:1) for body text,
///    used in 72 places. A future palette tweak must not silently undo that.
/// 2. **Scale shape.** Radii and spacing collapsed from 20 ad-hoc values to a
///    fixed scale. If someone adds an eighth radius, this fails.
void main() {
  group('palette contrast (WCAG AA, 4.5:1)', () {
    // Every surface a given text colour can plausibly land on. The worst
    // (lightest-in-dark / darkest-in-light) surface is what matters.
    final lightSurfaces = <String, Color>{
      'lightBackground': AppColors.lightBackground,
      'lightSurface': AppColors.lightSurface,
      'lightSurfaceCard': AppColors.lightSurfaceCard,
      'lightActionSurface': AppColors.lightActionSurface,
    };
    final darkSurfaces = <String, Color>{
      'darkBackground': AppColors.darkBackground,
      'darkSurface': AppColors.darkSurface,
      'darkSurfaceCard': AppColors.darkSurfaceCard,
    };

    final lightText = <String, Color>{
      'lightTextPrimary': AppColors.lightTextPrimary,
      'lightTextSecondary': AppColors.lightTextSecondary,
      'lightTextTertiary': AppColors.lightTextTertiary,
    };
    final darkText = <String, Color>{
      'darkTextPrimary': AppColors.darkTextPrimary,
      'darkTextSecondary': AppColors.darkTextSecondary,
      'darkTextTertiary': AppColors.darkTextTertiary,
    };

    lightText.forEach((textName, textColor) {
      lightSurfaces.forEach((surfaceName, surfaceColor) {
        test('$textName on $surfaceName', () {
          final ratio = contrastRatio(textColor, surfaceColor);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '$textName ($textColor) on $surfaceName ($surfaceColor) '
                'measures ${ratio.toStringAsFixed(2)}:1',
          );
        });
      });
    });

    darkText.forEach((textName, textColor) {
      darkSurfaces.forEach((surfaceName, surfaceColor) {
        test('$textName on $surfaceName', () {
          final ratio = contrastRatio(textColor, surfaceColor);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '$textName ($textColor) on $surfaceName ($surfaceColor) '
                'measures ${ratio.toStringAsFixed(2)}:1',
          );
        });
      });
    });
  });

  group('radius scale', () {
    const values = [
      AppRadius.xs,
      AppRadius.sm,
      AppRadius.md,
      AppRadius.lg,
      AppRadius.xl,
      AppRadius.xxl,
    ];

    test('is strictly ascending', () {
      for (var i = 1; i < values.length; i++) {
        expect(values[i], greaterThan(values[i - 1]));
      }
    });

    test('has no more than seven steps', () {
      // Six concrete radii + the pill. Adding an eighth means the scale has
      // started leaking ad-hoc values again.
      expect(values.length, 6);
      expect(AppRadius.pill, greaterThan(AppRadius.xxl));
    });
  });

  group('spacing scale', () {
    const values = [
      AppSpace.s2,
      AppSpace.s4,
      AppSpace.s8,
      AppSpace.s12,
      AppSpace.s16,
      AppSpace.s20,
      AppSpace.s24,
      AppSpace.s32,
      AppSpace.s40,
      AppSpace.s48,
    ];

    test('is strictly ascending', () {
      for (var i = 1; i < values.length; i++) {
        expect(values[i], greaterThan(values[i - 1]));
      }
    });

    test('sits on a 4-point grid', () {
      for (final value in values.skip(1)) {
        expect(value % 4, 0, reason: '$value is not a multiple of 4');
      }
    });

    test('page gutter is a scale member', () {
      expect(values, contains(AppSpace.pageGutter));
    });
  });

  group('typography', () {
    const ink = Color(0xFF000000);

    test('every role uses the bundled family', () {
      final roles = <TextStyle>[
        AppType.displayLarge(ink),
        AppType.displayMedium(ink),
        AppType.displaySmall(ink),
        AppType.headlineLarge(ink),
        AppType.headlineMedium(ink),
        AppType.headlineSmall(ink),
        AppType.titleLarge(ink),
        AppType.titleMedium(ink),
        AppType.titleSmall(ink),
        AppType.bodyLarge(ink),
        AppType.bodyMedium(ink),
        AppType.bodySmall(ink),
        AppType.labelLarge(ink),
        AppType.labelMedium(ink),
        AppType.labelSmall(ink),
      ];
      for (final role in roles) {
        expect(role.fontFamily, kAppFontFamily);
        expect(role.color, ink);
      }
    });

    test('display > headline > title > body size ordering', () {
      expect(
        AppType.displayLarge(ink).fontSize,
        greaterThan(AppType.headlineLarge(ink).fontSize!),
      );
      expect(
        AppType.headlineLarge(ink).fontSize,
        greaterThan(AppType.titleLarge(ink).fontSize!),
      );
      expect(
        AppType.titleLarge(ink).fontSize,
        greaterThan(AppType.bodyLarge(ink).fontSize!),
      );
    });

    test('numeric roles carry tabular figures', () {
      // Money figures must not re-flow while a count-up animates.
      for (final role in [
        AppType.displayLarge(ink),
        AppType.headlineLarge(ink),
        AppType.titleLarge(ink),
        AppType.money(color: ink),
      ]) {
        expect(role.fontFeatures, AppType.tabular);
      }
    });

    test('prose roles stay proportional', () {
      expect(AppType.bodyMedium(ink).fontFeatures, isNull);
      expect(AppType.labelMedium(ink).fontFeatures, isNull);
    });

    test('numericOf opts a prose role into tabular figures', () {
      final style = AppType.numericOf(AppType.bodyMedium(ink));
      expect(style.fontFeatures, AppType.tabular);
      expect(style.fontSize, AppType.bodyMedium(ink).fontSize);
    });
  });

  group('motion', () {
    test('durations are ordered fast < base < slow < entrance', () {
      expect(AppMotion.fast, lessThan(AppMotion.base));
      expect(AppMotion.base, lessThan(AppMotion.slow));
      expect(AppMotion.slow, lessThan(AppMotion.entrance));
    });
  });

  group('palette contract', () {
    // Material's 100%-saturation accent swatches (cyanAccent, redAccent, …) were
    // used 190 times across 31 files as ad-hoc semantic colours. They cannot be
    // themed, they clash with the indigo brand, and they signal nothing —
    // `redAccent` meant "delete" in one place and "danger" in another. Every one
    // now resolves to an AppColors token.
    //
    // The exceptions are identity colours: a portfolio chart needs 28
    // distinguishable hues and a category tile needs a stable per-name hue,
    // which is data, not UI chrome.
    const allowed = {
      'lib/Config/wealth_asset_registry.dart',
      'lib/Config/asset_screen_configs.dart',
      'lib/Components/cateogary_initial_icon.dart',
    };
    final accentPattern = RegExp(r'Colors\.[a-zA-Z]+Accent');

    test('no Material accent swatch is used as a UI colour', () {
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final relative = entity.path.replaceAll(r'\', '/');
        if (allowed.contains(relative)) continue;
        final source = entity.readAsStringSync();
        for (final match in accentPattern.allMatches(source)) {
          final line = source.substring(0, match.start).split('\n').length;
          offenders.add('$relative:$line ${match.group(0)}');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Use an AppColors token instead of a Material accent swatch:\n'
            '${offenders.join('\n')}',
      );
    });

    // Same argument for the named Material swatches: 121 `Colors.green` /
    // `Colors.red` / `Colors.deepPurple` sites meant "success" / "error" /
    // "a decorative purple" without saying so, so a greyscale/accent change
    // could not reach them.
    test('no named Material swatch is used as a UI colour', () {
      final named = RegExp(
        r'Colors\.(red|green|orange|purple|blue|amber|pink|teal|lime|indigo|'
        r'deepPurple|deepOrange|lightBlue|lightGreen|yellow)\b(?!\.shade)',
      );
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final relative = entity.path.replaceAll(r'\', '/');
        if (allowed.contains(relative)) continue;
        final source = entity.readAsStringSync();
        for (final match in named.allMatches(source)) {
          final line = source.substring(0, match.start).split('\n').length;
          offenders.add('$relative:$line ${match.group(0)}');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Use an AppColors token instead of a named Material swatch:\n'
            '${offenders.join('\n')}',
      );
    });
  });
}

/// WCAG 2.1 relative luminance for a single sRGB channel.
double _linearChannel(double channel) {
  return channel <= 0.04045
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
}

double relativeLuminance(Color color) {
  final r = _linearChannel(color.r);
  final g = _linearChannel(color.g);
  final b = _linearChannel(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double contrastRatio(Color foreground, Color background) {
  final l1 = relativeLuminance(foreground);
  final l2 = relativeLuminance(background);
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}
