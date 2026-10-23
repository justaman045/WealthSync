import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import 'package:money_control/Components/adaptive_scaffold.dart';
import 'package:money_control/Components/cateogary_initial_icon.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Components/pro_lock_widget.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Controllers/subscription_controller.dart';
import 'package:money_control/Controllers/budget_controller.dart';
import 'package:money_control/Utils/responsive.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Services/performance_controller.dart';
import 'package:money_control/Config/app_strings.dart';
import 'package:money_control/l10n/app_localizations.dart';

class CategoryBudgetScreen extends StatefulWidget {
  const CategoryBudgetScreen({super.key});

  @override
  State<CategoryBudgetScreen> createState() => _CategoryBudgetScreenState();
}

class _CategoryBudgetScreenState extends State<CategoryBudgetScreen> {
  late final BudgetController _budgetController;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  Worker? _budgetWorker;
  Worker? _loadingWorker;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<TransactionController>()) {
      Get.put(TransactionController());
    }
    if (!Get.isRegistered<BudgetController>()) {
      Get.put(BudgetController());
    }
    _budgetController = Get.find<BudgetController>();
    _budgetController.fetchBudgetsAndSpends();
    _budgetWorker = ever(_budgetController.categoryBudgets, (_) {
      if (mounted) setState(() {});
    });
    _loadingWorker = ever(_budgetController.isLoading, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _budgetWorker?.dispose();
    _loadingWorker?.dispose();
    for (var ctrl in _controllers.values) {
      ctrl.dispose();
    }
    for (var fn in _focusNodes.values) {
      fn.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gradientColors = isDark
        ? [
            AppColors.darkBackground, // Midnight Void
            AppColors.darkSurface.withValues(alpha: 0.95),
          ]
        : [AppColors.lightBackground, AppColors.lightBorder]; // Premium Light

    return AdaptiveScaffold(
      currentTab: 'wealth',
      backgroundColor: Colors.transparent,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      // Background, centring, title size and icon size come from AppBarTheme.
      appBar: AppBar(
        title: Text(AppStrings.categoryBudgets),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Builder(
        builder: (_) {
          final SubscriptionController subscriptionController = Get.find();
          if (!subscriptionController.isPro) {
            return ProLockWidget(
              title: AppStrings.budgeting,
              description: AppLocalizations.of(context)!.budgetProUpsell,
            );
          }

          if (_budgetController.isLoading.value) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final categoryBudgets = _budgetController.categoryBudgets;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                AppSpace.s20.w,
                AppSpace.s8.h,
                AppSpace.s20.w,
                AppSpace.s20.h,
              ),
                child: Responsive.isWideForm(context)
                    ? GridView.builder(
                        padding: EdgeInsets.zero,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: Responsive.gridColumns(context),
                          crossAxisSpacing: 16.w,
                          mainAxisSpacing: 16.h,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: categoryBudgets.length,
                        itemBuilder: (context, index) {
                          return _buildBudgetCard(context, categoryBudgets[index], index, isDark);
                        },
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: categoryBudgets.length,
                        separatorBuilder: (_, __) => SizedBox(height: 16.h),
                        itemBuilder: (context, index) {
                          return _buildBudgetCard(context, categoryBudgets[index], index, isDark);
                        },
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBudgetCard(
    BuildContext context,
    dynamic item,
    int index,
    bool isDark,
  ) {
    // Ensure controller exists and is synced
    if (!_controllers.containsKey(item.categoryName)) {
      _controllers[item.categoryName] = TextEditingController(
        text: item.budget.toStringAsFixed(2),
      );
      _focusNodes[item.categoryName] = FocusNode();
    } else if (_controllers[item.categoryName]!.text !=
            item.budget.toStringAsFixed(2) &&
        !_focusNodes[item.categoryName]!.hasFocus) {
      _controllers[item.categoryName]!.text = item.budget.toStringAsFixed(2);
    }

    final controller = _controllers[item.categoryName]!;
    final l10n = AppLocalizations.of(context)!;

    final progress = item.budget > 0
        ? (item.spent / item.budget).clamp(0.0, 1.0)
        : 0.0;

    final progressColor = progress > 0.9
        ? AppColors.error
        : (progress > 0.7 ? AppColors.warning : AppColors.primary);

    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final card = Container(
      padding: EdgeInsets.all(AppSpace.s16.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: AppElevation.raised(isDark: isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(AppSpace.s8.w),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightActionSurface,
                  shape: BoxShape.circle,
                ),
                child: CategoryInitialsIcon(
                  categoryName: item.categoryName,
                  size: 32.r,
                ),
              ),
              SizedBox(width: AppSpace.s12.w),
              Expanded(
                child: Text(
                  item.categoryName,
                  style: AppType.titleMedium(textColor),
                ),
              ),
              Text(
                "${CurrencyController.to.currencySymbol.value}${item.spent.toStringAsFixed(0)} / ${item.budget.toStringAsFixed(0)}",
                style: AppType.bodySmall(secondaryTextColor),
              ),
            ],
          ),
          SizedBox(height: AppSpace.s16.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs.r),
            child: LinearProgressIndicator(
              value: progress.toDouble(),
              color: progressColor,
              backgroundColor: isDark
                  ? AppColors.darkSurface
                  : AppColors.lightActionSurface,
              minHeight: 6.h,
            ),
          ),
          SizedBox(height: AppSpace.s16.h),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44.h,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkBackground
                        : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(AppRadius.sm.r),
                    border: Border.all(
                      color:
                          isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: TextFormField(
                    controller: controller,
                    focusNode: _focusNodes[item.categoryName],
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: AppType.bodyMedium(textColor),
                    decoration: InputDecoration(
                      hintText: l10n.budgetSetLimit,
                      hintStyle: AppType.bodyMedium(
                        isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextTertiary,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpace.s12.w,
                        vertical: 0,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppSpace.s12.w),
              SizedBox(
                height: 44.h,
                child: FilledButton(
                  onPressed: () {
                    final amount = double.tryParse(controller.text) ?? 0;
                    _budgetController.saveBudget(item.categoryName, amount);
                  },
                  child: Text(l10n.budgetUpdate),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (PerformanceController.to.liteMode.value) return card;
    return card
        .animate(delay: (index * 50).ms)
        .fadeIn(duration: AppMotion.slow)
        .slideY(begin: 0.1, end: 0, curve: AppMotion.standard);
  }
}
