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
    // final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gradientColors = isDark
        ? [
            const Color(0xFF1A1A2E), // Midnight Void
            const Color(0xFF16213E).withValues(alpha: 0.95),
          ]
        : [const Color(0xFFF5F7FA), const Color(0xFFC3CFE2)]; // Premium Light

    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final secondaryTextColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : const Color(0xFF1A1A2E).withValues(alpha: 0.6);

    final cardColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.6);

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.white.withValues(alpha: 0.4);

    return AdaptiveScaffold(
      currentIndex: 3,
      backgroundColor: Colors.transparent,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Category Budgets",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20.sp),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Builder(
        builder: (_) {
          final SubscriptionController subscriptionController = Get.find();
          if (!subscriptionController.isPro) {
            return const ProLockWidget(
              title: "Budgeting",
              description:
                  "Create budgets, track spending, and get alerts with Pro.",
            );
          }

          if (_budgetController.isLoading.value) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
            );
          }

          final categoryBudgets = _budgetController.categoryBudgets;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
              child: Padding(
                padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 20.h),
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
                          return _buildBudgetCard(context, categoryBudgets[index], index, isDark, textColor, secondaryTextColor, cardColor, borderColor);
                        },
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: categoryBudgets.length,
                        separatorBuilder: (_, __) => SizedBox(height: 16.h),
                        itemBuilder: (context, index) {
                          return _buildBudgetCard(context, categoryBudgets[index], index, isDark, textColor, secondaryTextColor, cardColor, borderColor);
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
    Color textColor,
    Color secondaryTextColor,
    Color cardColor,
    Color borderColor,
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
      _controllers[item.categoryName]!.text = item.budget
          .toStringAsFixed(2);
    }

    final controller = _controllers[item.categoryName]!;

    final progress = item.budget > 0
        ? (item.spent / item.budget).clamp(0.0, 1.0)
        : 0.0;

    final progressColor = progress > 0.9
        ? const Color(0xFFFF4081)
        : (progress > 0.7
              ? Colors.orangeAccent
              : const Color(0xFF00E5FF));

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark ? 0.2 : 0.05,
            ),
            blurRadius: 15.w,
            offset: Offset(0, 5.w),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: CategoryInitialsIcon(
                  categoryName: item.categoryName,
                  size: 32.r,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  item.categoryName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                    color: textColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                "${CurrencyController.to.currencySymbol.value}${item.spent.toStringAsFixed(0)} / ${item.budget.toStringAsFixed(0)}",
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.h),
            child: LinearProgressIndicator(
              value: progress.toDouble(),
              color: progressColor,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
              minHeight: 6.h,
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44.h,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: TextFormField(
                    controller: controller,
                    focusNode: _focusNodes[item.categoryName],
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: textColor, fontSize: 14.sp),
                    decoration: InputDecoration(
                      hintText: 'Set Limit',
                      hintStyle: TextStyle(
                        color: secondaryTextColor.withValues(alpha: 0.4),
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 0),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              InkWell(
                onTap: () {
                  final amount = double.tryParse(controller.text) ?? 0;
                  _budgetController.saveBudget(item.categoryName, amount);
                },
                child: Container(
                  height: 44.h,
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF00E5FF)],
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                        blurRadius: 8.w,
                      ),
                    ],
                  ),
                  child: Text(
                    "Update",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate(delay: (index * 50).ms)
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
  }
}
