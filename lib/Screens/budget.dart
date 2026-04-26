import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import 'package:money_control/Components/bottom_nav_bar.dart';
import 'package:money_control/Components/cateogary_initial_icon.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Components/pro_lock_widget.dart';
import 'package:money_control/Controllers/subscription_controller.dart';
import 'package:money_control/Controllers/budget_controller.dart';

class CategoryBudgetScreen extends StatefulWidget {
  const CategoryBudgetScreen({super.key});

  @override
  State<CategoryBudgetScreen> createState() => _CategoryBudgetScreenState();
}

class _CategoryBudgetScreenState extends State<CategoryBudgetScreen> {
  final BudgetController _budgetController = Get.put(BudgetController());
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};

  @override
  void initState() {
    super.initState();
    _budgetController.fetchBudgetsAndSpends();
  }

  @override
  void dispose() {
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

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
        body: Obx(() {
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

          return Padding(
            padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 20.h),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: categoryBudgets.length,
              separatorBuilder: (_, __) => SizedBox(height: 16.h),
              itemBuilder: (context, index) {
                final item = categoryBudgets[index];

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

                // Color logic: Green if <80%, Turn Yellow/Red as it fills
                final progressColor = progress > 0.9
                    ? const Color(0xFFFF4081) // Neon Pink/Red
                    : (progress > 0.7
                          ? Colors.orangeAccent
                          : const Color(0xFF00E5FF)); // Cyan

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
                            blurRadius: 15,
                            offset: const Offset(0, 5),
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

                          /// PROGRESS BAR
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

                          /// INPUT + SAVE
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
                                          : Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                    ),
                                  ),
                                  child: TextFormField(
                                    controller: controller,
                                    focusNode: _focusNodes[item.categoryName],
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 14.sp,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Set Limit',
                                      hintStyle: TextStyle(
                                        color: secondaryTextColor.withValues(
                                          alpha: 0.4,
                                        ),
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 14.w,
                                        vertical:
                                            0, // Centers text vertically in 44h container
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              InkWell(
                                onTap: () {
                                  final amount =
                                      double.tryParse(controller.text) ?? 0;
                                  _budgetController.saveBudget(
                                    item.categoryName,
                                    amount,
                                  );
                                },
                                child: Container(
                                  height: 44.h,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20.w,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF6C63FF),
                                        Color(0xFF00E5FF),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12.r),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF6C63FF,
                                        ).withValues(alpha: 0.4),
                                        blurRadius: 8,
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
              },
            ),
          );
        }),
        bottomNavigationBar: const BottomNavBar(currentIndex: 3),
      ),
    );
  }
}
