import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:money_control/Models/challenge_model.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Repositories/challenge_repository.dart';
import 'package:money_control/Services/cache_service.dart';
import 'package:money_control/Services/error_handler.dart';

class ChallengesController extends GetxController {
  static ChallengesController get to => Get.find();

  final _repo = ChallengeRepository();
  final _auth = FirebaseAuth.instance;

  String? get _userEmail => _auth.currentUser?.email;
  String get _cacheKey => 'challenges_${_userEmail ?? ''}';

  RxList<SavingsChallengeModel> challenges = <SavingsChallengeModel>[].obs;
  RxBool isLoading = true.obs;
  RxBool isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadFromCache();
    _fetchFromFirestore();
  }

  void _loadFromCache() {
    final cached = LocalCacheService.get(_cacheKey);
    if (cached is List) {
      challenges.value = cached.map((e) {
        final map = LocalCacheService.hiveRestore(Map<String, dynamic>.from(e as Map));
        final id = map.remove('_id') as String? ?? '';
        return SavingsChallengeModel.fromMap(id, map);
      }).toList();
      isLoading.value = false;
    }
  }

  Future<void> _fetchFromFirestore() async {
    try {
      final list = await _repo.getChallenges();
      challenges.value = list;
      if (_userEmail != null) {
        final cacheData = list.map((t) {
          final map = t.toMap();
          map['_id'] = t.id;
          return LocalCacheService.hiveSafe(map);
        }).toList();
        LocalCacheService.put(_cacheKey, cacheData, ttl: LocalCacheService.slow5m);
      }
    } catch (e) {
      debugPrint('ChallengesController._fetchFromFirestore error: $e');
    } finally {
      isLoading.value = false;
    }
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
    if (isSaving.value) return false;
    isSaving.value = true;
    try {
      await _repo.addChallenge(challenge);
      LocalCacheService.invalidate(_cacheKey);
      _fetchFromFirestore();
      return true;
    } catch (e) {
      debugPrint('Challenge error: $e');
      ErrorHandler.showError("Failed to save challenge.");
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> deleteChallenge(String id) async {
    if (isSaving.value) return false;
    isSaving.value = true;
    try {
      await _repo.deleteChallenge(id);
      LocalCacheService.invalidate(_cacheKey);
      _fetchFromFirestore();
      return true;
    } catch (e) {
      debugPrint('Challenge error: $e');
      ErrorHandler.showError("Failed to delete challenge.");
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> markComplete(SavingsChallengeModel c) async {
    try {
      await _repo.updateChallenge(c.copyWith(isCompleted: true));
      LocalCacheService.invalidate(_cacheKey);
      _fetchFromFirestore();
    } catch (e) {
      debugPrint('Failed to mark challenge complete: $e');
      ErrorHandler.showError("Failed to save progress.");
    }
  }
}
