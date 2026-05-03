import 'dart:async';
import 'package:get/get.dart';
import 'package:money_control/Models/challenge_model.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Repositories/challenge_repository.dart';
import 'package:money_control/Services/error_handler.dart';

class ChallengesController extends GetxController {
  static ChallengesController get to => Get.find();

  final _repo = ChallengeRepository();
  StreamSubscription<List<SavingsChallengeModel>>? _sub;

  RxList<SavingsChallengeModel> challenges = <SavingsChallengeModel>[].obs;
  RxBool isLoading = true.obs;
  RxBool isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    _bind();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  void _bind() {
    _sub = _repo.getChallengesStream().listen(
      (list) {
        challenges.value = list;
        isLoading.value = false;
      },
      onError: (_) => isLoading.value = false,
    );
  }

  double computeProgress(
    SavingsChallengeModel challenge,
    List<TransactionModel> transactions,
    String uid,
  ) {
    final relevant = transactions.where((tx) {
      final d = tx.date;
      return !d.isBefore(challenge.startDate) && !d.isAfter(challenge.endDate);
    });

    if (challenge.trackingType == 'no_spend_category') {
      final cat = challenge.trackedCategory;
      if (cat == null) return 0;
      final spent = relevant
          .where((tx) => tx.senderId == uid && tx.category == cat)
          .fold(0.0, (s, tx) => s + tx.amount.abs());
      return spent;
    }

    // 'savings' type: net savings = income - expenses
    double income = 0;
    double expenses = 0;
    for (final tx in relevant) {
      if (tx.recipientId == uid) income += tx.amount.abs();
      if (tx.senderId == uid) expenses += tx.amount.abs();
    }
    return (income - expenses).clamp(0, double.infinity);
  }

  Future<bool> addChallenge(SavingsChallengeModel challenge) async {
    isSaving.value = true;
    try {
      await _repo.addChallenge(challenge);
      return true;
    } catch (_) {
      ErrorHandler.showError("Failed to save challenge.");
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> deleteChallenge(String id) async {
    try {
      await _repo.deleteChallenge(id);
      return true;
    } catch (_) {
      ErrorHandler.showError("Failed to delete challenge.");
      return false;
    }
  }

  Future<void> markComplete(SavingsChallengeModel c) async {
    try {
      await _repo.updateChallenge(c.copyWith(isCompleted: true));
    } catch (_) {}
  }
}
