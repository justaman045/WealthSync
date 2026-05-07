import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';
import 'package:money_control/Services/notification_service.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BudgetService {
  /// Check if the new amount added to a category exceeds the user's set budget
  /// Triggers a notification if 100% is exceeded (Critical) or 90% is reached (Warning)
  /// Deduplicates: only notifies once per category per hour to avoid spam.
  static Future<void> checkBudgetExceeded({
    required String userId,
    required String category,
  }) async {
    try {
      // Deduplication: skip if notified within the last hour
      final prefs = await SharedPreferences.getInstance();
      final dedupeKey = 'budget_notified_${userId}_$category';
      final lastNotified = prefs.getInt(dedupeKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastNotified < const Duration(hours: 1).inMilliseconds) return;

      // 1. Fetch the user's Budget for this specific category
      final budgetDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('budgets')
          .doc(category)
          .get();

      if (!budgetDoc.exists) return; // No budget set for this category

      final double budgetLimit = (budgetDoc.data()?['amount'] ?? 0).toDouble();
      if (budgetLimit <= 0) return; // Budget is 0, ignore

      // 2. Fetch Total Spend for this category for current month
      final nowDt = DateTime.now();
      final startOfMonth = DateTime(nowDt.year, nowDt.month, 1);
      final endOfMonth = DateTime(
        nowDt.year,
        nowDt.month + 1,
        1,
      ).subtract(const Duration(seconds: 1));

      final txSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .where('category', isEqualTo: category)
          .get();

      double totalSpent = 0.0;
      for (var doc in txSnap.docs) {
        final amount = (doc.data()['amount'] ?? 0).toDouble();
        // Only negative amounts are expenses (sign convention: expense = negative, income = positive)
        if (amount < 0) totalSpent += amount.abs();
      }

      final symbol = CurrencyController.to.currencySymbol.value;

      if (totalSpent > budgetLimit) {
        const title = "🚨 Budget Exceeded!";
        final body =
            "You've spent $symbol${totalSpent.toStringAsFixed(0)} of your $symbol${budgetLimit.toStringAsFixed(0)} $category budget.";

        await NotificationService.showNotification(
          title: title,
          body: body,
          channelId: 'budget_alerts',
          channelName: 'Budget Alerts',
        );
        await prefs.setInt(dedupeKey, now);
      } else if (totalSpent >= (budgetLimit * 0.9)) {
        const title = "⚠️ Approaching Limit";
        final body =
            "You've used ${(totalSpent / budgetLimit * 100).toStringAsFixed(0)}% of your $category budget.";

        await NotificationService.showNotification(
          title: title,
          body: body,
          channelId: 'budget_alerts',
          channelName: 'Budget Alerts',
        );
        await prefs.setInt(dedupeKey, now);
      }
    } catch (e) {
      log("Error checking budget: $e");
    }
  }

}
