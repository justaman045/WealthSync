import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:money_control/Controllers/transaction_controller.dart';

class BudgetController extends GetxController {
  static BudgetController get to => Get.find();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final TransactionController _transactionController =
      Get.find<TransactionController>();

  RxBool isLoading = false.obs;
  RxList<BudgetCategoryItem> categoryBudgets = <BudgetCategoryItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    // Listen to transaction changes to auto-update spending
    ever(_transactionController.transactions, (_) {
      if (categoryBudgets.isNotEmpty) {
        _calculateSpending();
      }
    });
  }

  Future<void> fetchBudgetsAndSpends() async {
    isLoading.value = true;
    try {
      final user = _auth.currentUser;
      if (user == null) {
        categoryBudgets.clear();
        return;
      }

      // 1. Fetch Categories
      final catSnap = await _firestore
          .collection('users')
          .doc(user.email)
          .collection('categories')
          .get();

      // 2. Fetch Budgets
      final budgetsSnap = await _firestore
          .collection('users')
          .doc(user.email)
          .collection('budgets')
          .get();

      Map<String, double> budgetsMap = {};
      for (var doc in budgetsSnap.docs) {
        budgetsMap[doc.id] = (doc.data()['amount'] as num?)?.toDouble() ?? 0;
      }

      List<BudgetCategoryItem> items = [];

      for (var doc in catSnap.docs) {
        final catName = doc['name'] ?? doc.id;
        final budgetAmount = budgetsMap[catName] ?? 0;

        // Controller will be managed by the widget or here.
        // For simplicity in GetX, we can keep the value here and UI handles text controller if needed
        items.add(
          BudgetCategoryItem(
            categoryName: catName,
            budget: budgetAmount,
            spent: 0, // Will be calculated next
          ),
        );
      }

      categoryBudgets.assignAll(items);
      _calculateSpending();
    } catch (e) {
      debugPrint("Error fetching budgets: $e");
      Get.snackbar("Error", "Failed to load budgets");
    } finally {
      isLoading.value = false;
    }
  }

  void _calculateSpending() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(
      now.year,
      now.month + 1,
      1,
    ).subtract(const Duration(seconds: 1));

    // Filter transactions from memory
    final monthlyTxs = _transactionController.transactions.where((tx) {
      final date = tx.date;
      return date.isAfter(startOfMonth.subtract(const Duration(seconds: 1))) &&
          date.isBefore(endOfMonth.add(const Duration(seconds: 1)));
    }).toList();

    // Sum by category
    Map<String, double> spendMap = {};
    for (var tx in monthlyTxs) {
      if (tx.category != null) {
        spendMap[tx.category!] =
            (spendMap[tx.category!] ?? 0) + tx.amount.abs();
      }
    }

    // Update items
    categoryBudgets.refresh(); // Signal update
    for (var item in categoryBudgets) {
      item.spent = spendMap[item.categoryName] ?? 0.0;
    }
    categoryBudgets.refresh();
  }

  Future<void> saveBudget(String categoryName, double amount) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.email)
          .collection('budgets')
          .doc(categoryName)
          .set({'amount': amount});

      // Update local state immediately
      final index = categoryBudgets.indexWhere(
        (item) => item.categoryName == categoryName,
      );
      if (index != -1) {
        categoryBudgets[index].budget = amount;
        categoryBudgets.refresh();
      }

      Get.snackbar(
        "Success",
        "Budget saved for $categoryName",
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(20),
        borderRadius: 20,
      );
    } catch (e) {
      Get.snackbar("Error", "Failed to save budget");
    }
  }
}

class BudgetCategoryItem {
  final String categoryName;
  double budget;
  double spent;

  BudgetCategoryItem({
    required this.categoryName,
    required this.budget,
    required this.spent,
  });
}
