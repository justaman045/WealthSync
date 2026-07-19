import 'package:flutter/material.dart';

class Responsive {
  Responsive._();

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= 600;

  static bool isLandscape(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  static bool isPortrait(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.portrait;

  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static int gridColumns(BuildContext context) {
    final width = screenWidth(context);
    if (width >= 1200) return 4;
    if (width >= 900) return 3;
    return 2;
  }

  static int wealthGridColumns(BuildContext context) => gridColumns(context);

  static double childAspectRatio(BuildContext context, {double base = 0.8}) {
    if (!isTablet(context)) return base;
    return base * 1.25;
  }

  static double contentMaxWidth(BuildContext context) {
    final width = screenWidth(context);
    if (width > 1100) return 1100;
    return width;
  }

  static double clampFont(double size, double screenWidth) {
    final scale = screenWidth / 390;
    final clampedScale = scale > 1.3 ? 1.3 : scale;
    return (size * clampedScale).roundToDouble();
  }

  static double responsiveSpacing(double base, double screenWidth) {
    final scale = screenWidth / 390;
    final clampedScale = scale > 1.3 ? 1.3 : scale;
    return (base * clampedScale).roundToDouble();
  }

  static double cardHeight(BuildContext context) {
    if (!isTablet(context)) return 180;
    return 160;
  }

  static double bottomNavHeight(BuildContext context) {
    if (!isTablet(context)) return 128;
    return 80;
  }

  static double appBarHeight(BuildContext context) {
    if (!isTablet(context)) return kToolbarHeight;
    return kToolbarHeight + 16;
  }

  static bool isWideForm(BuildContext context) =>
      isTablet(context) && isLandscape(context);

  static double sheetMaxWidth(BuildContext context) {
    if (!isTablet(context)) return double.infinity;
    final w = screenWidth(context);
    if (w > 600) return 520;
    return w;
  }

  static Widget wrapSheetContent(BuildContext context, Widget child) {
    final maxW = sheetMaxWidth(context);
    if (maxW == double.infinity) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: child,
      ),
    );
  }
}
