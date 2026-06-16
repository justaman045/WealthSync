import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/goals_controller.dart';
import 'package:money_control/Models/goal_model.dart';
import 'package:money_control/Screens/add_goal_screen.dart';

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
          title: const Text("Goals"),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Get.to(() => const AddGoalScreen()),
          backgroundColor: AppColors.primary,
          icon: Icon(Icons.add, color: isDark ? Colors.white : AppColors.lightTextPrimary),
          label: Text(
            "New Goal",
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
          return ListView(
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 100.h),
            children: [
              _buildSummaryRow(ctrl, theme),
              SizedBox(height: 16.h),
              ...ctrl.goals.map((goal) => _buildGoalCard(context, goal, ctrl, theme)),
            ],
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
          Text(label, style: TextStyle(color: color, fontSize: 13.sp, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildGoalCard(BuildContext context, GoalModel goal, GoalsController ctrl, ThemeData theme) {
    final sym = CurrencyController.to.currencySymbol.value;
    final isDark = theme.brightness == Brightness.dark;
    final pct = (goal.progress * 100).toStringAsFixed(0);

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
                blurRadius: 12,
                offset: const Offset(0, 4),
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
                        "Done!",
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    Text(
                      "$pct%",
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
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

  void _showAddProgressSheet(BuildContext context, GoalModel goal, GoalsController ctrl) {
    if (goal.isCompleted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sym = CurrencyController.to.currencySymbol.value;
    final amtCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24.w,
          right: 24.w,
          top: 24.h,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Add to ${goal.emoji} ${goal.name}",
              style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.lightTextPrimary),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: amtCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary),
              decoration: InputDecoration(
                prefixText: "$sym ",
                prefixStyle: TextStyle(color: isDark ? Colors.white70 : AppColors.lightTextSecondary, fontSize: 16.sp),
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
                onPressed: ctrl.isSaving.value
                    ? null
                    : () async {
                        final val = double.tryParse(amtCtrl.text);
                        if (val == null || val <= 0) return;
                        Navigator.pop(context);
                        await ctrl.updateProgress(goal.id, val);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                ),
                child: ctrl.isSaving.value
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: isDark ? Colors.white : AppColors.lightTextPrimary, strokeWidth: 2))
                    : Text("Add Progress", style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary, fontSize: 15.sp, fontWeight: FontWeight.w600)),
              )),
            ),
          ],
        ),
      ),
    ).whenComplete(() => amtCtrl.dispose());
  }

  void _showDeleteDialog(BuildContext context, GoalModel goal, GoalsController ctrl) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text("Delete Goal?", style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary, fontSize: 17.sp)),
        content: Text(
          "Delete \"${goal.name}\"? This cannot be undone.",
          style: TextStyle(color: isDark ? Colors.white70 : AppColors.lightTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ctrl.deleteGoal(goal.id);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("🎯", style: TextStyle(fontSize: 60.sp)),
          SizedBox(height: 16.h),
          Text(
            "No goals yet",
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            "Set a savings or purchase goal\nand track your progress.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.sp, color: Theme.of(context).textTheme.bodyMedium?.color),
          ),
          SizedBox(height: 28.h),
          ElevatedButton.icon(
            onPressed: () => Get.to(() => const AddGoalScreen()),
            icon: const Icon(Icons.add),
            label: const Text("Add your first goal"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: isDark ? Colors.white : AppColors.lightTextPrimary,
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
            ),
          ),
        ],
      ),
    );
  }
}
