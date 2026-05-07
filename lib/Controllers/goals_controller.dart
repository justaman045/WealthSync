import 'dart:async';
import 'package:get/get.dart';
import 'package:money_control/Models/goal_model.dart';
import 'package:money_control/Repositories/goals_repository.dart';
import 'package:money_control/Services/error_handler.dart';

class GoalsController extends GetxController {
  static GoalsController get to => Get.find();

  final _repo = GoalsRepository();
  StreamSubscription<List<GoalModel>>? _goalsSub;

  RxList<GoalModel> goals = <GoalModel>[].obs;
  RxBool isLoading = true.obs;
  RxBool isSaving = false.obs;

  int get activeGoalCount => goals.where((g) => !g.isCompleted).length;
  int get completedGoalCount => goals.where((g) => g.isCompleted).length;

  @override
  void onInit() {
    super.onInit();
    _bindGoals();
  }

  @override
  void onClose() {
    _goalsSub?.cancel();
    super.onClose();
  }

  void _bindGoals() {
    try {
      _goalsSub = _repo.getGoalsStream().listen(
        (list) {
          goals.value = list;
          isLoading.value = false;
        },
        onError: (_) => isLoading.value = false,
      );
    } catch (_) {
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
      return true;
    } catch (_) {
      ErrorHandler.showError("Failed to save goal. Please try again.");
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> updateProgress(String id, double addAmount) async {
    if (addAmount <= 0) return false;
    isSaving.value = true;
    try {
      final updated = await _repo.addProgress(id, addAmount);
      if (updated == null) return false;
      if (updated.isCompleted) {
        ErrorHandler.showSuccess("Goal achieved! 🎉");
      }
      return true;
    } catch (_) {
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
      return true;
    } catch (_) {
      ErrorHandler.showError("Failed to delete goal.");
      return false;
    } finally {
      isSaving.value = false;
    }
  }
}
