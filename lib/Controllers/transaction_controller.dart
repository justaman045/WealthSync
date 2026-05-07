import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:money_control/Models/cateogary.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Repositories/transaction_repository.dart';
import 'package:money_control/Services/budget_service.dart';
import 'package:money_control/Services/local_backup_service.dart';
import 'package:money_control/Services/offline_queue.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:money_control/Services/error_handler.dart';
import 'package:money_control/Services/widget_service.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/subscription_controller.dart';
import 'package:money_control/Screens/subscription_screen.dart';

class TransactionController extends GetxController {
  final TransactionRepository _repository = TransactionRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final SubscriptionController _subscriptionController;

  // State
  var transactions = <TransactionModel>[].obs;
  var categories = <CategoryModel>[].obs;
  var isLoading = false.obs;
  var isSaving = false.obs;
  var streakCount = 0.obs;

  // Sorted categories by usage
  var sortedCategoryNames = <String>[].obs;

  late final Worker _categoriesWorker;
  late final Worker _transactionsWorker;

  @override
  void onInit() {
    super.onInit();
    _subscriptionController = Get.find<SubscriptionController>();
    bindTransactions();
    bindCategories();
    // Single debounce on transactions handles both sorting and widget updates.
    _categoriesWorker = debounce(
      categories,
      (_) => fetchSortedCategories(),
      time: const Duration(milliseconds: 300),
    );
    _transactionsWorker = debounce(
      transactions,
      (_) => _updateHomeWidget(),
      time: const Duration(milliseconds: 500),
    );
  }

  @override
  void onClose() {
    _categoriesWorker.dispose();
    _transactionsWorker.dispose();
    super.onClose();
  }

  // Derived State
  double get totalBalance {
    double balance = 0.0;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 0.0;

    for (var tx in transactions) {
      if (tx.senderId == uid) {
        balance -= tx.amount.abs();
        balance -= tx.tax;
      } else if (tx.recipientId == uid) {
        balance += tx.amount.abs();
      }
    }
    return balance;
  }

  Future<void> refreshData() async {
    isLoading.value = true;
    try {
      // 1. Simulate network fetch delay for UX (shimmer visibility)
      await Future.delayed(const Duration(milliseconds: 1500));

      // 2. Re-fetch sorted categories (or any other non-stream data)
      fetchSortedCategories();

      // Note: Transactions/Categories are streams, so they update automatically.
    } finally {
      isLoading.value = false;
    }
  }

  void bindTransactions() {
    transactions.bindStream(_repository.getTransactionsStream());
  }

  void _updateHomeWidget() {
    try {
      final sym = CurrencyController.to.currencySymbol.value;
      WidgetService.updateBalance(totalBalance, sym);
    } catch (_) {}
  }

  void bindCategories() {
    categories.bindStream(_repository.getCategoriesStream());
  }

  void fetchSortedCategories() {
    // Optimization: Calculate in-memory from existing streams
    if (categories.isEmpty) {
      sortedCategoryNames.clear();
      return;
    }

    final categoryUsage = <String, int>{};

    // 1. Count usage from cached transactions
    for (var tx in transactions) {
      if (tx.category != null && tx.category!.isNotEmpty) {
        categoryUsage[tx.category!] = (categoryUsage[tx.category!] ?? 0) + 1;
      }
    }

    // 2. Sort available categories by usage
    // Create a list of all known category names
    final allNames = categories.map((c) => c.name).toList();

    // Sort: High usage first, then alphabetical for ties/unused
    allNames.sort((a, b) {
      final usageA = categoryUsage[a] ?? 0;
      final usageB = categoryUsage[b] ?? 0;
      if (usageA != usageB) {
        return usageB.compareTo(usageA); // Descending usage
      }
      return a.compareTo(b); // Alphabetical tie-breaker
    });

    sortedCategoryNames.assignAll(allNames);
  }

  // ——————————————————————————————————————
  //  Actions
  // ——————————————————————————————————————

  Future<bool> addCategory(String name) async {
    // 1. Check PRO Limit (Categories)
    if (!_subscriptionController.isPro && categories.length >= 10) {
      Get.to(() => const SubscriptionScreen());
      return false;
    }

    if (name.isEmpty) {
      ErrorHandler.showError("Category name cannot be empty");
      return false;
    }

    if (categories.any((c) => c.name.toLowerCase() == name.toLowerCase())) {
      ErrorHandler.showError("Category already exists");
      return false;
    }

    try {
      final doc = await _repository.addCategory(name);
      categories.add(CategoryModel(id: doc.id, name: name));
      sortedCategoryNames.add(name); // Ensure it appears in QuickSend
      return true;
    } catch (e) {
      _handleFirestoreError(e, "Failed to add category");
      return false;
    }
  }

  Future<bool> deleteCategory(CategoryModel category) async {
    if (categories.length <= 1) {
      ErrorHandler.showError("At least one category must exist.");
      return false;
    }

    try {
      await _repository.deleteCategory(category.id);
      categories.removeWhere((c) => c.id == category.id);
      return true;
    } catch (e) {
      _handleFirestoreError(e, "Failed to delete category");
      return false;
    }
  }

  Future<bool> saveTransaction({
    required double amount,
    required String name,
    required String note,
    required String category,
    required DateTime date,
    required String type, // 'send' or 'receive'
    required String currency,
  }) async {
    if (isSaving.value) return false;
    isSaving.value = true;

    // 2. Check PRO Limit (Transactions)
    if (!_subscriptionController.isPro) {
      final now = DateTime.now();
      // Use subtract(microseconds:1) so transactions at midnight on the 1st are included.
      final startOfMonth = DateTime(now.year, now.month, 1)
          .subtract(const Duration(microseconds: 1));
      final txCount = transactions
          .where((t) => t.date.isAfter(startOfMonth))
          .length;

      if (txCount >= 150) {
        Get.to(() => const SubscriptionScreen());
        isSaving.value = false;
        return false;
      }
    }

    final user = _auth.currentUser;
    if (user == null) {
      isSaving.value = false;
      return false;
    }

    if (amount <= 0) {
      ErrorHandler.showError("Enter a valid amount");
      isSaving.value = false;
      return false;
    }
    if (name.isEmpty) {
      ErrorHandler.showError("Enter a valid name");
      isSaving.value = false;
      return false;
    }

    final isSend = type == 'send';
    final finalAmount = isSend ? -amount : amount;

    final tx = TransactionModel(
      id: "",
      senderId: isSend ? user.uid : "",
      recipientId: isSend ? "" : user.uid,
      recipientName: name,
      amount: finalAmount,
      currency: currency,
      tax: 0.0,
      note: note,
      category: category,
      date: date,
      status: "success",
      createdAt: Timestamp.now(),
    );

    try {
      // 1. Attempt Firestore write with timeout
      await _repository.addTransaction(tx).timeout(const Duration(seconds: 5));
    } on TimeoutException catch (e) {
      debugPrint("Firebase timeout: $e");
      // 2. Offline Queue Fallback — wrap separately so isSaving is always reset
      try {
        await OfflineQueueService.savePending(tx.toMap());
        ErrorHandler.showSuccess("Saved locally. Will sync later.", title: "Offline");
        isSaving.value = false;
        return true;
      } catch (queueError) {
        debugPrint("Offline queue error: $queueError");
        ErrorHandler.showError("Failed to save transaction. Please retry.");
        isSaving.value = false;
        return false;
      }
    } catch (e) {
      _handleFirestoreError(e, "Failed to save transaction");
      isSaving.value = false;
      return false;
    }

    // 3. Local Backup
    if (user.email != null) {
      LocalBackupService.backupUserTransactions(user.email!);
    }

    // 4. Budget Check (Side Effect)
    if (isSend && user.email != null) {
      BudgetService.checkBudgetExceeded(
        userId: user.email!,
        category: category,
        newAmount: amount, // Positive amount for budget check
      );
    }

    // 5. Update cached sorted categories
    fetchSortedCategories();

    // 6. Update spending streak
    if (user.email != null) _updateStreak(user.email!);

    isSaving.value = false;
    return true;
  }

  Future<void> _updateStreak(String email) async {
    try {
      final db = FirebaseFirestore.instance;
      final doc = await db.collection('users').doc(email).get();
      final data = doc.data() ?? {};
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final lastTs = data['lastStreakDate'] as Timestamp?;
      final lastDate = lastTs != null
          ? DateTime(lastTs.toDate().year, lastTs.toDate().month, lastTs.toDate().day)
          : null;
      final count = (data['streakCount'] as int?) ?? 0;

      if (lastDate == null || lastDate.isBefore(today.subtract(const Duration(days: 1)))) {
        // Streak broken or new — reset to 1
        await db.collection('users').doc(email).set({
          'streakCount': 1,
          'lastStreakDate': Timestamp.fromDate(today),
        }, SetOptions(merge: true));
        streakCount.value = 1;
      } else if (_isSameDay(lastDate, today.subtract(const Duration(days: 1)))) {
        // Consecutive — increment
        final newCount = count + 1;
        await db.collection('users').doc(email).set({
          'streakCount': newCount,
          'lastStreakDate': Timestamp.fromDate(today),
        }, SetOptions(merge: true));
        streakCount.value = newCount;
        if ([7, 30, 100].contains(newCount)) {
          ErrorHandler.showSuccess(
            '$newCount day streak! Keep it up!',
            title: 'Streak Milestone',
          );
        }
      }
      // If lastDate == today, no-op (already tracked today)
    } catch (e) {
      debugPrint('Streak update error: $e');
    }
  }

  Future<bool> deleteTransaction(TransactionModel tx) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      await _repository
          .deleteTransaction(tx.id)
          .timeout(const Duration(seconds: 5));

      // Local Backup
      if (user.email != null) {
        LocalBackupService.backupUserTransactions(user.email!);
      }
      return true;
    } on TimeoutException {
      // Offline fallback
      final deleteJson = {
        "operation": "delete",
        "transactionId": tx.id,
        "user": user.email,
      };
      await OfflineQueueService.savePending(deleteJson);

      // Optimistic update
      transactions.removeWhere((t) => t.id == tx.id);

      ErrorHandler.showSuccess("Delete queued (Offline)", title: "Offline");
      return true;
    } catch (e) {
      _handleFirestoreError(e, "Failed to delete transaction");
      return false;
    }
  }

  void _handleFirestoreError(dynamic e, String defaultMessage) {
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          ErrorHandler.showError(
            "You don't have permission to perform this action.",
          );
          break;
        case 'unavailable':
          ErrorHandler.showNetworkError();
          break;
        case 'not-found':
          ErrorHandler.showError("The requested item was not found.");
          break;
        default:
          ErrorHandler.showError("$defaultMessage: ${e.message}");
      }
    } else {
      ErrorHandler.showError("$defaultMessage. Please try again.");
      debugPrint("Error: $e");
    }
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
