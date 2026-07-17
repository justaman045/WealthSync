import 'dart:async';
import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:money_control/Models/goal_model.dart';
import 'package:money_control/Repositories/goals_repository.dart';
import 'package:money_control/Services/cache_service.dart';
import 'package:money_control/Services/error_handler.dart';

class GoalsController extends GetxController {
  static GoalsController get to => Get.find();

  final _repo = GoalsRepository();
  final _auth = FirebaseAuth.instance;

  String? get _userEmail => _auth.currentUser?.email;
  String get _cacheKey => 'goals_${_userEmail ?? ''}';

  RxList<GoalModel> goals = <GoalModel>[].obs;
  RxBool isLoading = true.obs;
  RxBool isSaving = false.obs;

  int get activeGoalCount => goals.where((g) => !g.isCompleted).length;
  int get completedGoalCount => goals.where((g) => g.isCompleted).length;

  @override
  void onInit() {
    super.onInit();
    _loadFromCache();
    _fetchFromFirestore();
  }

  void _loadFromCache() {
    final cached = LocalCacheService.get(_cacheKey);
    if (cached is List) {
      goals.value = cached.map((e) {
        final map = LocalCacheService.hiveRestore(Map<String, dynamic>.from(e as Map));
        final id = map.remove('_id') as String? ?? '';
        return GoalModel.fromMap(id, map);
      }).toList();
      isLoading.value = false;
    }
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
        LocalCacheService.put(_cacheKey, cacheData, ttl: LocalCacheService.slow5m);
      }
    } catch (e) {
      log('GoalsController._fetchFromFirestore error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> addGoal({
    required String name,
    required double targetAmount,
    String? description,
    DateTime? targetDate,
    String emoji = '🎯',
  }) async {
    if (name.trim().isEmpty || targetAmount <= 0) return false;
    isSaving.value = true;
    try {
      final goal = GoalModel(
        id: '',
        name: name.trim(),
        targetAmount: targetAmount,
        description: description?.trim().isEmpty == true ? null : description?.trim(),
        targetDate: targetDate,
        emoji: emoji,
      );
      await _repo.addGoal(goal);
      LocalCacheService.invalidate(_cacheKey);
      _fetchFromFirestore();
      return true;
    } catch (e) {
      debugPrint('Goal error: $e');
      ErrorHandler.showError("Failed to save goal. Please try again.");
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

  Future<bool> deleteGoal(String id) async {
    if (isSaving.value) return false;
    isSaving.value = true;
    try {
      await _repo.deleteGoal(id);
      LocalCacheService.invalidate(_cacheKey);
      _fetchFromFirestore();
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
