import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:ui';
import 'package:get/get.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Services/performance_controller.dart';
import 'package:money_control/Utils/responsive.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final BoxBorder? border; // NEW
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.border, // NEW
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
    final useBlur =
        !PerformanceController.to.liteMode.value && !Responsive.isTablet(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rBorderRadius = borderRadius ?? BorderRadius.circular(20.r);

    final solid = Container(
      width: width,
      height: height,
      margin: margin ?? EdgeInsets.zero,
      padding: padding ?? EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.3)
            : AppColors.lightGlassBg.withValues(alpha: 0.92),
        borderRadius: rBorderRadius,
        border:
            border ??
            Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppColors.lightBorder.withValues(alpha: 0.6),
              width: 1.5,
            ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12.w,
            spreadRadius: 1.w,
          ),
        ],
      ),
      child: child,
    );

    final container = RepaintBoundary(
      child: ClipRRect(
        borderRadius: rBorderRadius,
        child: useBlur
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(
                  width: width,
                  height: height,
                  margin: margin ?? EdgeInsets.zero,
                  padding: padding ?? EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : AppColors.lightGlassBg.withValues(alpha: 0.85),
                    borderRadius: rBorderRadius,
                    border:
                        border ??
                        Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : AppColors.lightBorder.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10.w,
                        spreadRadius: 2.w,
                      ),
                    ],
                  ),
                  child: child,
                ),
              )
            : solid,
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.translucent,
        child: container,
      );
    }
    return container;
  }
}
