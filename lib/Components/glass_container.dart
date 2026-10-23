import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:ui';
import 'package:get/get.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Services/performance_controller.dart';
import 'package:money_control/Utils/responsive.dart';

/// The app's universal card surface.
///
/// Frosted (a real backdrop blur) on phones, solid in lite mode and on tablets.
/// Those two branches used to build two near-identical Containers and had
/// already drifted apart: fill alpha 0.92 vs 0.85, shadow blur 12 vs 10, spread
/// 1 vs 2. There is now one Container; only the fill alpha and the blur depend
/// on the mode.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.border,
    this.width,
    this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Obx makes the blur/solid switch reactive: toggling lite mode in Settings
    // immediately restores (or removes) the frosted look across the app.
    return Obx(() => _build(context));
  }

  Widget _build(BuildContext context) {
    // Read the reactive value FIRST. GetX must see an Rx read as the first
    // dependency inside this Obx; reading inherited widgets (Theme/MediaQuery)
    // or ScreenUtil before it leaves the observer unregistered and trips
    // GetX's "improper use of a GetX" guard (when later rebuilt under test).
    final liteMode = PerformanceController.to.liteMode.value;
    final useBlur = !liteMode && !Responsive.isTablet(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.lg.r);

    final card = Container(
      width: width,
      height: height,
      margin: margin ?? EdgeInsets.zero,
      padding: padding ?? EdgeInsets.all(AppSpace.s16.w),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: useBlur ? 0.2 : 0.3)
            : AppColors.lightGlassBg.withValues(alpha: useBlur ? 0.85 : 0.92),
        borderRadius: radius,
        border:
            border ??
            Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppColors.lightBorder.withValues(alpha: 0.6),
              width: 1.5,
            ),
        boxShadow: AppElevation.raised(isDark: isDark),
      ),
      child: child,
    );

    Widget container = RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: useBlur
            ? BackdropFilter(
                // Keep sigma <= 4: two 10-sigma blurs made scrolling unusable.
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: card,
              )
            : card,
      ),
    );

    if (onTap != null) {
      container = Semantics(
        button: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.translucent,
          child: container,
        ),
      );
    }
    return container;
  }
}
