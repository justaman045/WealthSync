import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Services/performance_controller.dart';

/// The one empty state, used by every list in the app.
///
/// Restraint rules this enforces: one accent (the semantic `primary` unless a
/// caller overrides it), the type scale (`AppType`), the radius scale
/// (`AppRadius`) and the spacing scale (`AppSpace`). The entrance animations are
/// skipped in lite mode, like every other animated surface.
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color? color;
  final VoidCallback? onAction;
  final String? actionLabel;

  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.color,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = color ?? AppColors.primary;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final secondaryColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final liteMode = PerformanceController.to.liteMode.value;

    Widget entrance(
      Widget child, {
      required Duration delay,
      Curve curve = Curves.easeOut,
      Offset? scaleFrom,
    }) {
      if (liteMode) return child;
      var animated = child
          .animate()
          .fadeIn(delay: delay, duration: AppMotion.slow);
      if (scaleFrom != null) {
        animated = animated.scale(
          begin: scaleFrom,
          end: const Offset(1, 1),
          curve: curve,
          duration: AppMotion.slow,
        );
      }
      return animated;
    }

    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpace.s32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            entrance(
              Container(
                padding: EdgeInsets.all(AppSpace.s24.w),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(icon, size: 64.sp, color: accentColor),
              ),
              delay: Duration.zero,
              curve: Curves.easeOutBack,
              scaleFrom: const Offset(0.8, 0.8),
            ),
            SizedBox(height: AppSpace.s24.h),
            entrance(
              Text(
                title,
                style: AppType.titleLarge(textColor),
                textAlign: TextAlign.center,
              ),
              delay: AppMotion.stagger,
            ),
            SizedBox(height: AppSpace.s12.h),
            entrance(
              Text(
                subtitle,
                style: AppType.bodyMedium(secondaryColor),
                textAlign: TextAlign.center,
              ),
              delay: AppMotion.stagger * 2,
            ),
            if (onAction != null && actionLabel != null) ...[
              SizedBox(height: AppSpace.s32.h),
              // No styleFrom: the ElevatedButton theme owns the fill, the
              // radius and the label size. The previous copy re-declared all
              // three, plus a 0.4-alpha glow, which made an empty state's CTA
              // heavier than the primary action on a content screen.
              entrance(
                ElevatedButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
                delay: AppMotion.stagger * 3,
                scaleFrom: const Offset(0.8, 0.8),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
