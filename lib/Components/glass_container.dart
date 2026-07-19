import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:ui';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Utils/responsive.dart';

class GlassContainer extends StatelessWidget {
  static BoxDecoration glassDecoration({
    required bool isDark,
    double borderRadius = 24,
    Color? customColor,
    List<BoxShadow>? customShadow,
  }) {
    return BoxDecoration(
      color: customColor ??
          (isDark
              ? Colors.white.withValues(alpha: 0.05)
              : AppColors.lightSurface),
      borderRadius: BorderRadius.circular(borderRadius.r),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : AppColors.lightBorder,
      ),
      boxShadow: customShadow ??
          [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 15.w,
              offset: Offset(0.w, 8.w),
            ),
          ],
    );
  }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rBorderRadius = borderRadius ?? BorderRadius.circular(20.r);
    final isTablet = Responsive.isTablet(context);

    final container = RepaintBoundary(
      child: ClipRRect(
        borderRadius: rBorderRadius,
        child: isTablet
            ? Container(
                width: width,
                height: height,
                margin: margin ?? EdgeInsets.zero,
                padding: padding ?? EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : AppColors.lightSurface.withValues(alpha: 0.92),
                  borderRadius: rBorderRadius,
                  border:
                      border ??
                      Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : AppColors.lightBorder.withValues(alpha: 0.5),
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
              )
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(
                  width: width,
                  height: height,
                  margin: margin ?? EdgeInsets.zero,
                  padding: padding ?? EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : AppColors.lightSurface.withValues(alpha: 0.85),
                    borderRadius: rBorderRadius,
                    border:
                        border ??
                        Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : AppColors.lightBorder.withValues(alpha: 0.5),
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
              ),
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
