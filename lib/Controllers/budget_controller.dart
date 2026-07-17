import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Controllers/subscription_controller.dart';
import 'package:money_control/Services/cache_service.dart';

class BudgetController extends GetxController {
  static BudgetController get to => Get.find();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late final TransactionController _transactionController;

  String? get _userEmail => _auth.currentUser?.email;
  String get _cacheKey => 'budgets_${_userEmail ?? ''}';

  RxBool isLoading = false.obs;
  RxList<BudgetCategoryItem> categoryBudgets = <BudgetCategoryItem>[].obs;

  Worker? _txWorker;

  @override
  void onInit() {
    super.onInit();
    _transactionController = Get.find<TransactionController>();
    _loadFromCache();
    _txWorker = ever(_transactionController.transactions, (_) {
      if (categoryBudgets.isNotEmpty) {
        _calculateSpending();
      }
    });
  }

  @override
  void onClose() {
    _txWorker?.dispose();
    super.onClose();
  }

  void _loadFromCache() {
    final cached = LocalCacheService.get(_cacheKey);
    if (cached is List) {
      categoryBudgets.assignAll(cached.map((e) {
        final map = LocalCacheService.hiveRestore(Map<String, dynamic>.from(e as Map));
        return BudgetCategoryItem(
          categoryName: map['categoryName'] as String? ?? '',
          budget: (map['budget'] as num?)?.toDouble() ?? 0,
          spent: (map['spent'] as num?)?.toDouble() ?? 0,
        );
      }));
      _calculateSpending();
    }
  }

  Future<void> fetchBudgetsAndSpends() async {
    isLoading.value = true;
    try {
      final email = _userEmail;
      if (email == null) {
        categoryBudgets.clear();
        return;
      }

      // 1. Fetch Categories
      final catSnap = await _firestore
          .collection('users')
          .doc(email)
          .collection('categories')
          .get();

      // 2. Fetch Budgets
      final budgetsSnap = await _firestore
          .collection('users')
          .doc(email)
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
      if (_userEmail != null) {
        final cacheData = items.map((i) => {
          'categoryName': i.categoryName,
          'budget': i.budget,
          'spent': i.spent,
        }).toList();
        LocalCacheService.put(_cacheKey, cacheData, ttl: LocalCacheService.slow5m);
      }
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

    // Sum only expenses (negative amounts) by category.
    Map<String, double> spendMap = {};
    for (var tx in monthlyTxs) {
      if (tx.category != null && tx.amount < 0) {
        spendMap[tx.category!] =
            (spendMap[tx.category!] ?? 0) + tx.amount.abs();
      }
    }

    for (var item in categoryBudgets) {
      item.spent = spendMap[item.categoryName] ?? 0.0;
    }
    categoryBudgets.refresh();
  }

  Future<void> saveBudget(String categoryName, double amount) async {
    if (!SubscriptionController.to.isPro) return;
    final email = _userEmail;
    if (email == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(email)
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

      LocalCacheService.invalidate(_cacheKey);

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
