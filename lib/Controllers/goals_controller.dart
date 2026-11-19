import 'dart:async';
import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Models/goal_model.dart';
import 'package:money_control/Repositories/goals_repository.dart';
import 'package:money_control/Services/cache_service.dart';
import 'package:money_control/Services/error_handler.dart';
import 'package:money_control/Services/income_settings.dart';
import 'package:money_control/Services/savings_settings.dart';
import 'package:money_control/Utils/wealth_math.dart';

class GoalsController extends GetxController {
  static GoalsController get to => Get.find();

  final _repo = GoalsRepository();
  final _auth = FirebaseAuth.instance;

  String? get _userEmail => _auth.currentUser?.email;
  String get _cacheKey => 'goals_${_userEmail ?? ''}';

  RxList<GoalModel> goals = <GoalModel>[].obs;
  RxBool isLoading = true.obs;
  RxBool isSaving = false.obs;

  GoalSummary get summary => summarizeGoals(goals);
  int get activeGoalCount => summary.activeCount;
  int get completedGoalCount => summary.completedCount;

  /// Returns the emergency fund goal if one exists, otherwise null.
  GoalModel? get emergencyFundGoal => goals.firstWhereOrNull((g) => g.isEmergencyFund);

  /// Suggested monthly savings split across active goals, computed from this
  /// month's expected income × savings rate. Null until first computed.
  final Rx<GoalSavingsPlan?> _savingsPlan = Rx<GoalSavingsPlan?>(null);
  GoalSavingsPlan? get savingsPlan => _savingsPlan.value;

  /// Total the user has allotted to goals through the Add Progress sheet in
  /// the current calendar month. Backs the "Available to allot" label; reading
  /// it from the reactive [goals] list keeps that label live after a deposit.
  double get monthlyAllotted => goals.fold<double>(
        0.0,
        (sum, g) => sum + g.allotmentFor(DateTime.now()),
      );

  @override
  void onInit() {
    super.onInit();
    _loadFromCache();
    _fetchFromFirestore();
    _computeSavingsPlan();
  }

  Future<void> _computeSavingsPlan() async {
    await IncomeSettings.load();

    final txCtrl = Get.isRegistered<TransactionController>()
        ? Get.find<TransactionController>()
        : null;
    if (txCtrl == null) return;

    final allTx = txCtrl.transactions;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final result = computeExpectedIncome(
      allTx: allTx,
      uid: uid,
      mode: IncomeSettings.mode.value,
      manualMonthly: IncomeSettings.manualMonthly.value,
    );

    _savingsPlan.value = computeGoalSavingsPlan(
      monthlyIncome: result.expectedIncome,
      savingsRate: SavingsSettings.rate,
      // Include completed goals: their Add Progress deposits still consumed
      // this month's pot, so "Available to allot" and the plan stay in sync.
      goals: goals.map((g) {
        return GoalSavingsInput(
          id: g.id,
          target: g.targetAmount,
          current: g.currentAmount,
          isEmergencyFund: g.isEmergencyFund,
          targetDate: g.targetDate,
          monthlyAllocation: g.allotmentFor(DateTime.now()),
        );
      }).toList(),
      emergencyFundGoalId: emergencyFundGoal?.id,
    );
  }

  void _loadFromCache() {
    final cached = LocalCacheService.get(_cacheKey);
    if (cached is List) {
      goals.value = cached.whereType<Map>().map((e) {
        final map = LocalCacheService.hiveRestore(Map<String, dynamic>.from(e));
        final id = map.remove('_id')?.toString() ?? '';
        return GoalModel.fromMap(id, map);
      }).toList();
      isLoading.value = false;
    }
    LocalCacheService.invalidate(_cacheKey);
  }

  Future<void> _fetchFromFirestore() async {
    try {
      final list = await _repo.getGoals();
      goals.value = list;
      if (_userEmail != null) {
        final cacheData = list.map((t) {
          final map = t.toMap();
          map['_id'] = t.id;
          return LocalCacheService.hiveSafe(map);
        }).toList();
        await LocalCacheService.put(_cacheKey, cacheData, ttl: LocalCacheService.slow5m);
      }
    } catch (e) {
      log('GoalsController._fetchFromFirestore error: $e');
    } finally {
      isLoading.value = false;
      _computeSavingsPlan();
    }
  }

  Future<bool> addGoal({
    required String name,
    required double targetAmount,
    String? description,
    DateTime? targetDate,
    String emoji = '🎯',
    bool isEmergencyFund = false,
  }) async {
    if (name.trim().isEmpty || targetAmount <= 0) return false;
    if (isSaving.value) return false;
    isSaving.value = true;
    try {
      final goal = GoalModel(
        id: '',
        name: name.trim(),
        targetAmount: targetAmount,
        description: description?.trim().isEmpty == true ? null : description?.trim(),
        targetDate: targetDate,
        emoji: emoji,
        isEmergencyFund: isEmergencyFund,
      );
      await _repo.addGoal(goal);
      LocalCacheService.invalidate(_cacheKey);
      _fetchFromFirestore();
      await _computeSavingsPlan();
      return true;
    } catch (e) {
      debugPrint('Goal error: $e');
      ErrorHandler.showError("Failed to save goal. Please try again.");
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> updateGoal({
    required String id,
    required String name,
    required double targetAmount,
    String? description,
    DateTime? targetDate,
    String emoji = '🎯',
  }) async {
    if (name.trim().isEmpty || targetAmount <= 0) return false;
    if (isSaving.value) return false;
    isSaving.value = true;
    try {
      final idx = goals.indexWhere((g) => g.id == id);
      if (idx == -1) return false;
      final updated = goals[idx].edited(
        name: name.trim(),
        targetAmount: targetAmount,
        description: description?.trim().isEmpty == true ? null : description?.trim(),
        targetDate: targetDate,
        emoji: emoji,
      );
      await _repo.updateGoal(updated);
      LocalCacheService.invalidate(_cacheKey);
      goals[idx] = updated;
      goals.refresh();
      await _computeSavingsPlan();
      return true;
    } catch (e) {
      debugPrint('Goal error: $e');
      ErrorHandler.showError("Failed to update goal. Please try again.");
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> updateProgress(String id, double addAmount) async {
    if (isSaving.value || addAmount <= 0) return false;
    isSaving.value = true;
    try {
      final updated = await _repo.addProgress(id, addAmount);
      if (updated == null) return false;
      // Reflect the new progress in the local list immediately.
      final idx = goals.indexWhere((g) => g.id == id);
      if (idx != -1) {
        goals[idx] = updated;
        goals.refresh();
        await _computeSavingsPlan();
      }
      LocalCacheService.invalidate(_cacheKey);
      if (updated.isCompleted) {
        ErrorHandler.showSuccess("Goal achieved! 🎉");
      }
      return true;
    } catch (e) {
      debugPrint('Goal error: $e');
      ErrorHandler.showError("Failed to update progress.");
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  /// Reduces [currentAmount] by [subtractAmount] — a withdrawal from the goal.
  /// Never goes below zero. Returns false if the goal isn't found, is already
  /// at zero, or the amount is invalid.
  Future<bool> reduceProgress(String id, double subtractAmount) async {
    if (isSaving.value || subtractAmount <= 0) return false;
    isSaving.value = true;
    try {
      final idx = goals.indexWhere((g) => g.id == id);
      if (idx == -1) return false;
      final goal = goals[idx];
      final current = goal.currentAmount;
      if (current <= 0) return false;
      final updated = goal.withWithdrawal(subtractAmount, DateTime.now());
      final newAmount = updated.currentAmount;
      await _repo.updateGoal(updated);
      goals[idx] = updated;
      goals.refresh();
      LocalCacheService.invalidate(_cacheKey);
      await _computeSavingsPlan();
      if (newAmount == 0) {
        ErrorHandler.showSuccess("Withdrawn — ${goal.name} is now empty.");
      } else {
        ErrorHandler.showSuccess("Withdrawn ${CurrencyController.to.currencySymbol.value}${subtractAmount.toStringAsFixed(0)}.");
      }
      return true;
    } catch (e) {
      debugPrint('Goal error: $e');
      ErrorHandler.showError("Failed to withdraw from goal.");
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  /// Sets [currentAmount] directly to [amount], clamped at [targetAmount].
  /// Used by the emergency fund to sync progress against total balance, which
  /// can decrease as well as increase.
  Future<bool> setProgress(String id, double amount) async {
    if (isSaving.value) return false;
    isSaving.value = true;
    try {
      final idx = goals.indexWhere((g) => g.id == id);
      if (idx == -1) return false;
      final goal = goals[idx];
      final clamped = amount.clamp(0.0, goal.targetAmount);
      final updated = goal.copyWith(currentAmount: clamped);
      await _repo.updateGoal(updated);
      goals[idx] = updated;
      goals.refresh();
      await _computeSavingsPlan();
      LocalCacheService.invalidate(_cacheKey);
      if (updated.isCompleted) {
        ErrorHandler.showSuccess("Goal achieved! 🎉");
      }
      return true;
    } catch (e) {
      debugPrint('Goal error: $e');
      ErrorHandler.showError("Failed to update progress.");
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> deleteGoal(String id) async {
    if (isSaving.value) return false;
    isSaving.value = true;
    try {
      await _repo.deleteGoal(id);
      LocalCacheService.invalidate(_cacheKey);
      _fetchFromFirestore();
      await _computeSavingsPlan();
      return true;
    } catch (e) {
      debugPrint('Goal error: $e');
      ErrorHandler.showError("Failed to delete goal.");
      return false;
    } finally {
      isSaving.value = false;
    }
  }
}
