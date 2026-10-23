import 'package:money_control/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Config/app_strings.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/goals_controller.dart';
import 'package:money_control/Models/goal_model.dart';
import 'package:money_control/Screens/add_goal_screen.dart';
import 'package:money_control/Utils/responsive.dart';
import 'package:money_control/Utils/wealth_math.dart';
import 'package:money_control/Components/empty_state.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  late final GoalsController ctrl;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<GoalsController>()) Get.put(GoalsController());
    ctrl = Get.find<GoalsController>();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark ? AppColors.darkGradient : AppColors.lightGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(AppStrings.goals),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Get.to(() => const AddGoalScreen()),
          backgroundColor: AppColors.primary,
          icon: Icon(Icons.add, color: isDark ? Colors.white : AppColors.lightTextPrimary),
          label: Text(
            AppStrings.newGoal,
            style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary, fontWeight: FontWeight.bold),
          ),
        ),
        body: Obx(() {
          if (ctrl.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          if (ctrl.goals.isEmpty) {
            return _buildEmptyState(context);
          }
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
              child: Responsive.isWideForm(context)
                  ? SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 100.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(ctrl, theme),
                          SizedBox(height: 16.h),
                          GridView.count(
                            crossAxisCount: Responsive.gridColumns(context),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 12.w,
                            mainAxisSpacing: 12.h,
                            childAspectRatio: 1.6,
                            children: ctrl.goals.map((goal) => _buildGoalCard(context, goal, ctrl, theme)).toList(),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 100.h),
                      children: [
                        _buildHeader(ctrl, theme),
                        SizedBox(height: 16.h),
                        ...ctrl.goals.map((goal) => _buildGoalCard(context, goal, ctrl, theme)),
                      ],
                    ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSummaryRow(GoalsController ctrl, ThemeData theme) {
    return Row(
      children: [
        _summaryChip(
          label: "${ctrl.activeGoalCount} Active",
          color: AppColors.primary,
          icon: Icons.flag_outlined,
        ),
        SizedBox(width: 12.w),
        _summaryChip(
          label: "${ctrl.completedGoalCount} Done",
          color: AppColors.success,
          icon: Icons.check_circle_outline,
        ),
      ],
    );
  }

  Widget _summaryChip({required String label, required Color color, required IconData icon}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14.sp),
          SizedBox(width: 6.w),
          Text(label, style: AppType.labelMedium(color)),
        ],
      ),
    );
  }

  Widget _buildGoalCard(BuildContext context, GoalModel goal, GoalsController ctrl, ThemeData theme) {
    final sym = CurrencyController.to.currencySymbol.value;
    final isDark = theme.brightness == Brightness.dark;
    final pct = formatPercent(goal.progress * 100, capBelowHundred: true);

    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: GestureDetector(
        onTap: () => _showAddProgressSheet(context, goal, ctrl),
        onLongPress: () {
          HapticFeedback.mediumImpact();
          _showDeleteDialog(context, goal, ctrl);
        },
        child: Container(
          padding: EdgeInsets.all(18.w),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: goal.isCompleted
                  ? AppColors.success.withValues(alpha: 0.4)
                  : isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lightBorder.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12.w,
                offset: Offset(0, 4.w),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(goal.emoji, style: TextStyle(fontSize: 28.sp)),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        if (goal.description != null && goal.description!.isNotEmpty)
                          Text(
                            goal.description!,
                            style: TextStyle(fontSize: 12.sp, color: theme.textTheme.bodyMedium?.color),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (goal.isCompleted)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.done,
                        style: AppType.labelMedium(AppColors.success),
                      ),
                    )
                  else
                    Text(
                      "$pct%",
                      style: AppType.titleSmall(AppColors.primary),
                    ),
                  _buildGoalMenu(context, goal, ctrl, theme),
                ],
              ),
              SizedBox(height: 14.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: LinearProgressIndicator(
                  value: goal.progress,
                  minHeight: 8.h,
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation(
                    goal.isCompleted ? AppColors.success : AppColors.primary,
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "$sym${NumberFormat('#,##0.##').format(goal.currentAmount)} of $sym${NumberFormat('#,##0.##').format(goal.targetAmount)}",
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: theme.textTheme.bodyMedium?.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (goal.daysLeft != null)
                    Builder(builder: (context) {
                      final days = goal.daysLeft!;
                      return Text(
                        days >= 0
                            ? "$days days left"
                            : "${-days} days overdue",
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: days < 0
                              ? AppColors.error
                              : theme.textTheme.bodySmall?.color,
                        ),
                      );
                    }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(GoalsController ctrl, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTotalCard(ctrl, theme),
        SizedBox(height: 12.h),
        _buildSummaryRow(ctrl, theme),
      ],
    );
  }

  Widget _buildTotalCard(GoalsController ctrl, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final sym = CurrencyController.to.currencySymbol.value;
    final summary = ctrl.summary;
    final pct = formatPercent(summary.progress * 100, capBelowHundred: true);
    final fmt = NumberFormat('#,##0.##');

    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.primary.withValues(alpha: 0.28), AppColors.primary.withValues(alpha: 0.08)]
              : [AppColors.primary.withValues(alpha: 0.16), AppColors.primary.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppStrings.totalProgress,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
              const Spacer(),
              Text(
                "$pct%",
                style: AppType.headlineSmall(AppColors.primary),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: LinearProgressIndicator(
              value: summary.progress,
              minHeight: 8.h,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${AppStrings.saved}  $sym${fmt.format(summary.totalSaved)}",
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: theme.textTheme.bodyMedium?.color),
              ),
              Text(
                "${AppStrings.target}  $sym${fmt.format(summary.totalTarget)}",
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: theme.textTheme.bodyMedium?.color),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalMenu(BuildContext context, GoalModel goal, GoalsController ctrl, ThemeData theme) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: 20.sp, color: theme.textTheme.bodyMedium?.color),
      padding: EdgeInsets.zero,
      onSelected: (value) {
        if (value == 'edit') {
          Get.to(() => AddGoalScreen(goal: goal));
        } else if (value == 'delete') {
          _showDeleteDialog(context, goal, ctrl);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'edit', child: Text(AppStrings.edit)),
        PopupMenuItem(value: 'delete', child: Text(AppStrings.delete)),
      ],
    );
  }

  void _showAddProgressSheet(BuildContext context, GoalModel goal, GoalsController ctrl) {
    if (goal.isCompleted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      isScrollControlled: true,
      constraints: BoxConstraints(maxWidth: Responsive.sheetMaxWidth(context)),
      builder: (_) => _AddProgressSheet(goal: goal, ctrl: ctrl),
    );
  }

  void _showDeleteDialog(BuildContext context, GoalModel goal, GoalsController ctrl) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text(AppLocalizations.of(context)!.deleteGoal, style: AppType.bodyLarge(isDark ? Colors.white : AppColors.lightTextPrimary)),
        content: Text(
          "Delete \"${goal.name}\"? This cannot be undone.",
          style: TextStyle(color: isDark ? Colors.white70 : AppColors.lightTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ctrl.deleteGoal(goal.id);
            },
            child: const Text("Delete", style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // One empty state for the whole app (EmptyStateWidget): an emoji at 60 pt
    // rendered in the OS emoji font, which is why this screen looked unlike
    // every other empty list.
    return EmptyStateWidget(
      icon: Icons.flag_outlined,
      title: l10n.goalsYet,
      subtitle: l10n.setSavingsPurchaseGoalTrack,
      actionLabel: l10n.addFirstGoal,
      onAction: () => Get.to(() => const AddGoalScreen()),
    );
  }
}

class _AddProgressSheet extends StatefulWidget {
  const _AddProgressSheet({required this.goal, required this.ctrl});

  final GoalModel goal;
  final GoalsController ctrl;

  @override
  State<_AddProgressSheet> createState() => _AddProgressSheetState();
}

class _AddProgressSheetState extends State<_AddProgressSheet> {
  final _amtCtrl = TextEditingController();

  @override
  void dispose() {
    _amtCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final val = double.tryParse(_amtCtrl.text);
    if (val == null || val <= 0) return;
    Navigator.pop(context);
    await widget.ctrl.updateProgress(widget.goal.id, val);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sym = CurrencyController.to.currencySymbol.value;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24.w,
          right: 24.w,
          top: 24.h,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32.h,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Add to ${widget.goal.emoji} ${widget.goal.name}",
                style: AppType.titleMedium(isDark ? Colors.white : AppColors.lightTextPrimary),
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: _amtCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary),
                decoration: InputDecoration(
                  prefixText: "$sym ",
                  prefixStyle: AppType.bodyLarge(isDark ? Colors.white70 : AppColors.lightTextSecondary),
                  hintText: "Amount to add",
                  hintStyle: TextStyle(color: isDark ? Colors.white38 : AppColors.lightTextTertiary),
                  filled: true,
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.049),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: Obx(() => ElevatedButton(
                  onPressed: widget.ctrl.isSaving.value ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                  ),
                  child: widget.ctrl.isSaving.value
                      ? SizedBox(width: 20.w, height: 20.h, child: CircularProgressIndicator(color: isDark ? Colors.white : AppColors.lightTextPrimary, strokeWidth: 2))
                      : Text(AppLocalizations.of(context)!.addProgress, style: AppType.labelLarge(isDark ? Colors.white : AppColors.lightTextPrimary)),
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
