import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:money_control/Controllers/transaction_controller.dart';

class AnalyticsController extends GetxController {
  final RxBool isLoading = true.obs;
  final RxBool hasError = false.obs;
  final RxDouble incomeSoFar = 0.0.obs;
  final RxDouble expenseSoFar = 0.0.obs;
  final RxDouble forecastIncome = 0.0.obs;
  final RxDouble forecastExpense = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    loadMonthTransactions();
  }

  Future<void> loadMonthTransactions() async {
    isLoading.value = true;
    hasError.value = false;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      isLoading.value = false;
      return;
    }

    try {
      final TransactionController txController = Get.find();

      // Wait for transactions to be loaded if they aren't yet
      if (txController.isLoading.value) {
        await Future.delayed(const Duration(milliseconds: 500));
        // Simple retry/wait mechanism or we could listen.
        // But usually Home loads first.
      }

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(
        now.year,
        now.month + 1,
        1,
      ).subtract(const Duration(seconds: 1));
      final daysInMonth = DateTime(
        now.year,
        now.month + 1,
        0,
      ).day; // Correct last day

      final allTx = txController.transactions;

      // Filter Current Month
      final monthlyTx = allTx.where((tx) {
        return tx.date.isAfter(
              startOfMonth.subtract(const Duration(seconds: 1)),
            ) &&
            tx.date.isBefore(endOfMonth.add(const Duration(seconds: 1)));
      });

      Map<String, double> dailyIncome = {};
      Map<String, double> dailyExpense = {};

      for (var tx in monthlyTx) {
        final txDateStr = DateFormat('yyyy-MM-dd').format(tx.date);

        if (tx.recipientId == user.uid) {
          dailyIncome[txDateStr] =
              (dailyIncome[txDateStr] ?? 0) + tx.amount.abs();
        } else if (tx.senderId == user.uid) {
          dailyExpense[txDateStr] =
              (dailyExpense[txDateStr] ?? 0) + tx.amount.abs();
        }
      }

      // SUM totals till today
      incomeSoFar.value = dailyIncome.values.fold(0, (a, b) => a + b);
      expenseSoFar.value = dailyExpense.values.fold(0, (a, b) => a + b);

      // --- HISTORY: All past complete months (no date cutoff) ---
      final currentKey = now.year * 100 + now.month;
      Map<int, double> monthlyIncome = {};
      Map<int, double> monthlyExpense = {};

      for (var tx in allTx) {
        final k = tx.date.year * 100 + tx.date.month;
        if (k == currentKey) continue;
        if (tx.recipientId == user.uid) {
          monthlyIncome[k] = (monthlyIncome[k] ?? 0) + tx.amount.abs();
        } else if (tx.senderId == user.uid) {
          monthlyExpense[k] = (monthlyExpense[k] ?? 0) + tx.amount.abs();
        }
      }

      // Sort descending (most recent first) for linear-decay weighting
      final sortedKeys = {...monthlyIncome.keys, ...monthlyExpense.keys}
          .toList()
        ..sort((a, b) => b.compareTo(a));

      // Linear-decay weighted average: most recent month gets weight N, oldest gets 1
      double totalWeight = 0, weightedInc = 0, weightedExp = 0;
      for (int i = 0; i < sortedKeys.length; i++) {
        final w = (sortedKeys.length - i).toDouble();
        weightedInc += (monthlyIncome[sortedKeys[i]] ?? 0) * w;
        weightedExp += (monthlyExpense[sortedKeys[i]] ?? 0) * w;
        totalWeight += w;
      }
      final historicalMonthlyIncome =
          totalWeight > 0 ? weightedInc / totalWeight : 0.0;
      final historicalMonthlyExpense =
          totalWeight > 0 ? weightedExp / totalWeight : 0.0;

      // Progress-based blend: early in month → trust history more; late → trust current pace
      int daysPassed = now.day;
      if (daysPassed < 1) daysPassed = 1;

      final double progress = daysPassed / daysInMonth;
      final double histW = (1.0 - progress * 0.8).clamp(0.2, 1.0);
      final double currW = 1.0 - histW;

      final currentPacedIncome =
          (incomeSoFar.value / daysPassed) * daysInMonth;
      final currentPacedExpense =
          (expenseSoFar.value / daysPassed) * daysInMonth;

      final projectedIncome = sortedKeys.isNotEmpty
          ? historicalMonthlyIncome * histW + currentPacedIncome * currW
          : currentPacedIncome;
      final projectedExpense = sortedKeys.isNotEmpty
          ? historicalMonthlyExpense * histW + currentPacedExpense * currW
          : currentPacedExpense;

      // Projected remaining = projected month-end total minus what's already in
      forecastIncome.value =
          (projectedIncome - incomeSoFar.value).clamp(0, double.infinity);
      forecastExpense.value =
          (projectedExpense - expenseSoFar.value).clamp(0, double.infinity);

      isLoading.value = false;
    } catch (e) {
      debugPrint("Forecast error: $e");
      hasError.value = true;
      isLoading.value = false;
    }
  }
}
