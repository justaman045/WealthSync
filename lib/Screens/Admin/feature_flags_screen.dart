import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Config/app_strings.dart';
import 'package:money_control/Config/feature_flags.dart';
import 'package:money_control/Services/error_handler.dart';
import 'package:money_control/Services/feature_flag_service.dart';
import 'package:money_control/Utils/responsive.dart';

class FeatureFlagsScreen extends StatefulWidget {
  const FeatureFlagsScreen({super.key});

  @override
  State<FeatureFlagsScreen> createState() => _FeatureFlagsScreenState();
}

class _FeatureFlagsScreenState extends State<FeatureFlagsScreen> {
  String? _savingKey;

  static Color _statusColor(String status) {
    switch (status) {
      case FeatureStatus.comingSoon:
        return AppColors.warning;
      case FeatureStatus.hidden:
        return AppColors.error;
      default:
        return AppColors.success;
    }
  }

  static String _statusLabel(String status) {
    switch (status) {
      case FeatureStatus.comingSoon:
        return AppStrings.statusComingSoon;
      case FeatureStatus.hidden:
        return AppStrings.statusHidden;
      default:
        return AppStrings.statusEnabled;
    }
  }

  Future<void> _onStatusChanged(FeatureFlag flag, String newStatus) async {
    final service = FeatureFlagService.to;
    if (flag.critical &&
        newStatus != FeatureStatus.enabled &&
        service.statusOf(flag.key) == FeatureStatus.enabled) {
      final confirmed = await _confirmCriticalDisable(flag);
      if (confirmed != true) return;
    }
    if (!mounted) return;
    setState(() => _savingKey = flag.key);
    try {
      await service.setStatus(flag.key, newStatus);
      if (mounted) {
        ErrorHandler.showSuccess(
          '${flag.title} is ${_statusLabel(newStatus).toLowerCase()}',
          title: 'Feature Updated',
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(
          'Failed to update ${flag.title}: $e',
          title: 'Error',
        );
      }
    } finally {
      if (mounted) setState(() => _savingKey = null);
    }
  }

  Future<bool?> _confirmCriticalDisable(FeatureFlag flag) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          icon: Icon(
            Icons.shield_outlined,
            color: AppColors.warning,
            size: 40.sp,
          ),
          title: Text(
            AppStrings.criticalFeatureTitle,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            '${flag.title}: ${AppStrings.criticalFeatureWarning}',
            style: TextStyle(
              color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? Colors.white54 : AppColors.lightTextTertiary,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(AppStrings.disableCriticalConfirm),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!FeatureFlagService.to.userIsAdmin) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64.sp, color: Colors.redAccent),
              SizedBox(height: 16.h),
              Text(
                'Access Denied',
                style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  AppColors.darkBackground,
                  AppColors.darkSurface,
                  AppColors.darkSurface,
                ]
              : AppColors.lightGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            AppStrings.featureFlags,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.contentMaxWidth(context),
              ),
              child: GetBuilder<FeatureFlagService>(
                builder: (_) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(isDark),
                    SizedBox(height: 20.h),
                    for (final group in FeatureFlag.groups) ...[
                      _buildGroupHeader(isDark, group),
                      for (final key in group.keys) ...[
                        if (FeatureFlag.find(key) case final flag?)
                          _buildRow(context, isDark, flag),
                      ],
                      SizedBox(height: 10.h),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return GlassContainer(
      padding: EdgeInsets.all(20.w),
      borderRadius: BorderRadius.circular(20.r),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.flag_circle_outlined,
              color: AppColors.primary,
              size: 30.sp,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.featureFlags,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  AppStrings.featureFlagsSubtitle,
                  style: TextStyle(
                    color: isDark
                        ? Colors.white54
                        : AppColors.lightTextSecondary,
                    fontSize: 13.sp,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(bool isDark, FeatureFlagGroup group) {
    return Padding(
      padding: EdgeInsets.only(top: 8.h, bottom: 12.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(group.icon, color: AppColors.primary, size: 16.sp),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              group.title.toUpperCase(),
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
          Text(
            '${group.keys.length}',
            style: TextStyle(
              color: isDark ? Colors.white38 : AppColors.lightTextTertiary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, bool isDark, FeatureFlag flag) {
    final status = FeatureFlagService.to.statusOf(flag.key);
    final saving = _savingKey == flag.key;
    final statusColor = _statusColor(status);
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: GlassContainer(
        padding: EdgeInsets.all(18.w),
        borderRadius: BorderRadius.circular(20.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(flag.icon, color: statusColor, size: 22.sp),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        flag.title,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : AppColors.lightTextPrimary,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (flag.critical) ...[
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              color: AppColors.warning,
                              size: 13.sp,
                            ),
                            SizedBox(width: 4.w),
                            Flexible(
                              child: Text(
                                AppStrings.criticalFeatureTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.warning,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 12.w),
                _FeatureStatusSelector(
                  flag: flag,
                  status: status,
                  saving: saving,
                  onChanged: (s) => _onStatusChanged(flag, s),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Text(
              flag.description,
              style: TextStyle(
                color: isDark ? Colors.white54 : AppColors.lightTextSecondary,
                fontSize: 13.sp,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modern status selector: a token-styled chip that opens an animated popup
/// listing the three statuses with a colored dot and hint text.
class _FeatureStatusSelector extends StatefulWidget {
  final FeatureFlag flag;
  final String status;
  final bool saving;
  final ValueChanged<String> onChanged;

  const _FeatureStatusSelector({
    required this.flag,
    required this.status,
    required this.saving,
    required this.onChanged,
  });

  @override
  State<_FeatureStatusSelector> createState() => _FeatureStatusSelectorState();
}

class _FeatureStatusSelectorState extends State<_FeatureStatusSelector> {
  bool _open = false;

  Future<void> _openMenu() async {
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null || !box.hasSize) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final position = RelativeRect.fromRect(rect, Offset.zero & overlay.size);
    setState(() => _open = true);
    final selected = await showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      elevation: 12,
      color: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurfaceCard
          : Colors.white,
      popUpAnimationStyle: AnimationStyle(
        duration: const Duration(milliseconds: 180),
        reverseDuration: const Duration(milliseconds: 140),
      ),
      items: [
        for (final status in const [
          FeatureStatus.enabled,
          FeatureStatus.comingSoon,
          FeatureStatus.hidden,
        ])
          PopupMenuItem<String>(
            key: ValueKey('status-${widget.flag.key}-$status'),
            value: status,
            enabled: !widget.saving,
            height: 60.h,
            child: _StatusOption(
              status: status,
              selected: status == widget.status,
            ),
          ),
      ],
    );
    if (mounted) setState(() => _open = false);
    if (selected != null && selected != widget.status) {
      widget.onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _FeatureFlagsScreenState._statusColor(widget.status);
    return GestureDetector(
      key: ValueKey('flag-${widget.flag.key}-toggle'),
      behavior: HitTestBehavior.opaque,
      onTap: widget.saving ? null : _openMenu,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.16 : 0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.saving)
              SizedBox(
                width: 13.sp,
                height: 13.sp,
                child: CircularProgressIndicator(color: color, strokeWidth: 2),
              )
            else
              Container(
                width: 9.sp,
                height: 9.sp,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 6.sp,
                    ),
                  ],
                ),
              ),
            SizedBox(width: 7.w),
            Text(
              _FeatureFlagsScreenState._statusLabel(widget.status),
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 3.w),
            AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: const Duration(milliseconds: 180),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16.sp,
                color: isDark ? Colors.white54 : AppColors.lightTextTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusOption extends StatelessWidget {
  final String status;
  final bool selected;

  const _StatusOption({required this.status, required this.selected});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _FeatureFlagsScreenState._statusColor(status);
    final label = _FeatureFlagsScreenState._statusLabel(status);
    final String hint;
    switch (status) {
      case FeatureStatus.comingSoon:
        hint = AppStrings.statusComingSoonHint;
      case FeatureStatus.hidden:
        hint = AppStrings.statusHiddenHint;
      default:
        hint = AppStrings.statusEnabledHint;
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: Row(
        children: [
          Container(
            width: 12.w,
            height: 12.w,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  hint,
                  style: TextStyle(
                    color: isDark
                        ? Colors.white38
                        : AppColors.lightTextTertiary,
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          if (selected)
            Icon(Icons.check_circle_rounded, color: color, size: 20.sp),
        ],
      ),
    );
  }
}
