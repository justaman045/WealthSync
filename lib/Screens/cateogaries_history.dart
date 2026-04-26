import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:get/get.dart';
import 'package:money_control/Components/cateogary_initial_icon.dart';

import 'package:money_control/Screens/cateogary_history.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Components/empty_state.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Controllers/budget_controller.dart';

class CategoriesHistoryScreen extends StatefulWidget {
  const CategoriesHistoryScreen({super.key});

  @override
  State<CategoriesHistoryScreen> createState() =>
      _CategoriesHistoryScreenState();
}

class _CategoriesHistoryScreenState extends State<CategoriesHistoryScreen> {
  int selectedTab = 0;

  DateTime get _startOfMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  DateTime get _endOfMonth {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month + 1,
      1,
    ).subtract(const Duration(seconds: 1));
  }

  @override
  void initState() {
    super.initState();
    // Ensure BudgetController is in memory and fetch data if needed
    final BudgetController budgetController = Get.put(BudgetController());
    if (budgetController.categoryBudgets.isEmpty) {
      budgetController.fetchBudgetsAndSpends();
    }
  }

  void _onTabChanged(int index) {
    if (index != selectedTab) {
      HapticFeedback.selectionClick();
      setState(() {
        selectedTab = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: const Color(0xFF1A1A2E).withValues(alpha: 0.8),
            ),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          "Categories History",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1A1A2E), // Midnight Void Top
              const Color(
                0xFF16213E,
              ).withValues(alpha: 0.95), // Deep Blue Bottom
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: 100.h), // AppBar and Status Bar spacer
            // TABS
            Container(
              margin: EdgeInsets.symmetric(horizontal: 40.w),
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30.r),
              ),
              child: Row(
                children: [
                  Expanded(child: _tabButton("Income", 0)),
                  Expanded(child: _tabButton("Expense", 1)),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // LIST
            Expanded(
              child: Obx(() {
                final TransactionController txController = Get.find();
                final BudgetController budgetController =
                    Get.find(); // Now guaranteed to exist

                if ((txController.isLoading.value &&
                        txController.transactions.isEmpty) ||
                    (budgetController.isLoading.value &&
                        budgetController.categoryBudgets.isEmpty)) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
                  );
                }

                // 1. Filter Transactions for this month
                final startOfMonth = _startOfMonth;
                final endOfMonth = _endOfMonth;
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return const SizedBox();

                final monthlyTx = txController.transactions.where((tx) {
                  return tx.date.isAfter(startOfMonth) &&
                      tx.date.isBefore(endOfMonth);
                }).toList();

                // 2. Aggregate totals by category
                final Map<String, double> categoryTotalMap = {};
                for (var tx in monthlyTx) {
                  // Logic to determine Income/Expense based on sender/recipient
                  bool isIncome = false;
                  bool isExpense = false;

                  if (tx.recipientId == user.uid) isIncome = true;
                  if (tx.senderId == user.uid) isExpense = true;

                  // Only count expense transactions as negative and income as positive
                  if ((selectedTab == 0 && isIncome) ||
                      (selectedTab == 1 && isExpense)) {
                    final catVal = tx.category ?? 'Uncategorized';
                    categoryTotalMap[catVal] =
                        (categoryTotalMap[catVal] ?? 0.0) + tx.amount.abs();
                  }
                }

                // 3. Build List Items combining with Budgets
                final List<_CategoryItem> items = [];
                // Use categories from controller, defaulting to existing map keys if not found
                final knownCategories = txController.categories;

                // We want to show all categories that have transactions OR are known
                final allCategoryNames = {
                  ...categoryTotalMap.keys,
                  ...knownCategories.map((c) => c.name),
                };

                for (var name in allCategoryNames) {
                  final total = categoryTotalMap[name] ?? 0.0;
                  // Find icon from known categories
                  final catModel = knownCategories.firstWhereOrNull(
                    (c) => c.name == name,
                  );

                  // Find budget from BudgetController
                  // BudgetController items accessible? It has categoryBudgets list.
                  final budgetItem = budgetController.categoryBudgets
                      .firstWhereOrNull((b) => b.categoryName == name);
                  final budgetAmount = budgetItem?.budget ?? 0.0;

                  // Only add if there is a total OR a budget (optional: or just total > 0)
                  // Original code showed all categories. Let's show all.
                  items.add(
                    _CategoryItem(
                      id: catModel?.id ?? name,
                      name: name,
                      iconUrl: catModel?.icon,
                      total: total,
                      budget: budgetAmount,
                    ),
                  );
                }

                if (items.isEmpty) {
                  return Center(
                    child: EmptyStateWidget(
                      title: "No Categories",
                      subtitle: "No transactions found for this period.",
                      icon: Icons.category_outlined,
                      color: Colors.white38,
                    ),
                  );
                }

                // Sort by total descending
                items.sort((a, b) => b.total.compareTo(a.total));

                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 30.h),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final category = items[index];
                    return _buildCategoryCard(category, category.budget)
                        .animate(delay: (index * 50).ms)
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // Helper moved to class level or kept here
  // We need to update _CategoryItem definition to include budget if we want cleaner code,
  // or pass it separately. I added `budget` to `_CategoryItem` instantiation above,
  // so let's update `_CategoryItem` class too.

  Widget _tabButton(String text, int index) {
    final isSelected = selectedTab == index;
    // Income = Green (index 0), Expense = Red (index 1)
    final activeColor = index == 0
        ? const Color(0xFF00E676)
        : const Color(0xFFFF1744);

    return GestureDetector(
      onTap: () => _onTabChanged(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(26.r),
          border: isSelected
              ? Border.all(color: activeColor.withValues(alpha: 0.5))
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected ? activeColor : Colors.white54,
            fontSize: 14.sp,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(_CategoryItem category, double budget) {
    // 0 = Income (Green), 1 = Expense (Red)
    final isExpense = selectedTab == 1;
    final primaryColor = isExpense
        ? const Color(0xFFFF1744)
        : const Color(0xFF00E676);

    // Dim items with 0 spend
    final isZero = category.total == 0;
    final opacity = isZero ? 0.3 : 1.0;

    return GestureDetector(
      onTap: () {
        Get.to(() => CategoryTransactionsScreen(categoryName: category.name));
      },
      child: Opacity(
        opacity: opacity,
        child: Container(
          margin: EdgeInsets.only(bottom: 12.h),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05), // Dark Glass
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 46.r,
                height: 46.r,
                decoration: const BoxDecoration(color: Colors.transparent),
                child: category.iconUrl != null
                    ? CircleAvatar(
                        backgroundImage: NetworkImage(category.iconUrl!),
                        backgroundColor: primaryColor.withValues(alpha: 0.1),
                      )
                    : CategoryInitialsIcon(
                        categoryName: category.name,
                        size: 46.r,
                      ),
              ),
              SizedBox(width: 16.w),

              // Name & Progress
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (budget > 0 && isExpense) ...[
                      SizedBox(height: 6.h),
                      // Budget Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (category.total / budget).clamp(0.0, 1.0),
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation(
                            category.total > budget
                                ? Colors
                                      .redAccent // Over budget
                                : primaryColor, // Safe
                          ),
                          minHeight: 4.h,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(width: 12.w),

              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${CurrencyController.to.currencySymbol.value} ${category.total.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  if (budget > 0 && isExpense)
                    Padding(
                      padding: EdgeInsets.only(top: 4.h),
                      child: Text(
                        'of ${CurrencyController.to.currencySymbol.value}${budget.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11.sp,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryItem {
  final String id;
  final String name;
  final String? iconUrl;
  double total;
  final double budget; // Added budget field

  _CategoryItem({
    required this.id,
    required this.name,
    this.iconUrl,
    required this.total,
    required this.budget,
  });
}
