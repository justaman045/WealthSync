import 'dart:developer';
import 'package:get/get.dart';
import 'package:money_control/Models/lent_money_model.dart';
import 'package:money_control/Repositories/lent_money_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:money_control/Services/cache_service.dart';
import 'package:money_control/Services/error_handler.dart';
import 'dart:async';

class LentMoneyController extends GetxController {
  final LentMoneyRepository _repository = LentMoneyRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userEmail => _auth.currentUser?.email;
  String get _cacheKey => 'lent_money_${_userEmail ?? ''}';

  var entries = <LentMoneyModel>[].obs;
  var isLoading = false.obs;
  var isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadFromCache();
    _fetchFromFirestore();
  }

  void _loadFromCache() {
    final cached = LocalCacheService.get(_cacheKey);
    if (cached is List) {
      entries.value = cached.map((e) {
        final map = LocalCacheService.hiveRestore(Map<String, dynamic>.from(e as Map));
        final id = map.remove('_id') as String? ?? '';
        return LentMoneyModel.fromMap(id, map);
      }).toList();
    }
  }

  Future<void> fetchEntries() => _fetchFromFirestore();

  Future<void> _fetchFromFirestore() async {
    try {
      final list = await _repository.getEntries();
      entries.value = list;
      if (_userEmail != null) {
        final cacheData = list.map((t) {
          final map = t.toMap();
          map['_id'] = t.id;
          return LocalCacheService.hiveSafe(map);
        }).toList();
        LocalCacheService.put(_cacheKey, cacheData, ttl: LocalCacheService.slow5m);
      }
    } catch (e) {
      log('LentMoneyController._fetchFromFirestore error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  double get totalPendingReceivables {
    double total = 0.0;
    for (var entry in entries) {
      if (!entry.isSettled && entry.type == 'lent') {
        total += entry.amount;
      }
    }
    return total;
  }

  double get totalPendingPayables {
    double total = 0.0;
    for (var entry in entries) {
      if (!entry.isSettled && entry.type == 'borrowed') {
        total += entry.amount;
      }
    }
    return total;
  }

  double get netBalance {
    return totalPendingReceivables - totalPendingPayables;
  }

  Future<bool> addEntry({
    required String friendName,
    required double amount,
    required String note,
    required DateTime dateLent,
    required String type, // 'lent' or 'borrowed'
  }) async {
    if (isSaving.value) return false;
    isSaving.value = true;

    if (_auth.currentUser == null) {
      isSaving.value = false;
      return false;
    }

    if (amount <= 0) {
      ErrorHandler.showError("Enter a valid amount");
      isSaving.value = false;
      return false;
    }
    if (friendName.isEmpty) {
      ErrorHandler.showError("Enter a friend's name");
      isSaving.value = false;
      return false;
    }

    final entry = LentMoneyModel(
      id: "",
      friendName: friendName,
      amount: amount,
      note: note,
      dateLent: dateLent,
      isSettled: false,
      type: type,
      createdAt: Timestamp.now(),
    );

    try {
      await _repository.addEntry(entry).timeout(const Duration(seconds: 5));
      LocalCacheService.invalidate(_cacheKey);
      _fetchFromFirestore();
      isSaving.value = false;
      return true;
    } catch (e) {
      ErrorHandler.showError("Failed to add entry: $e");
      isSaving.value = false;
      return false;
    }
  }

  Future<bool> editEntry({
    required String id,
    required String friendName,
    required double amount,
    required String note,
    required DateTime dateLent,
    required String type,
    required bool isSettled,
    required Timestamp? createdAt,
  }) async {
    if (isSaving.value) return false;
    isSaving.value = true;

    if (amount <= 0 || friendName.isEmpty) {
      ErrorHandler.showError("Invalid details");
      isSaving.value = false;
      return false;
    }

    final updatedEntry = LentMoneyModel(
      id: id,
      friendName: friendName,
      amount: amount,
      note: note,
      dateLent: dateLent,
      isSettled: isSettled,
      type: type,
      createdAt: createdAt,
    );

    try {
      await _repository.updateEntry(updatedEntry);
      LocalCacheService.invalidate(_cacheKey);
      _fetchFromFirestore();
      isSaving.value = false;
      return true;
    } catch (e) {
      ErrorHandler.showError("Failed to update entry: $e");
      isSaving.value = false;
      return false;
    }
  }

  Future<bool> markAsSettled(LentMoneyModel entry) async {
    try {
      final updatedEntry = LentMoneyModel(
        id: entry.id,
        friendName: entry.friendName,
        amount: entry.amount,
        note: entry.note,
        dateLent: entry.dateLent,
        isSettled: true,
        type: entry.type,
        createdAt: entry.createdAt,
      );
      await _repository.updateEntry(updatedEntry);
      LocalCacheService.invalidate(_cacheKey);
      _fetchFromFirestore();
      return true;
    } catch (e) {
      ErrorHandler.showError("Failed to mark as settled: $e");
      return false;
    }
  }

  Future<bool> deleteEntry(String id) async {
    try {
      await _repository.deleteEntry(id);
      LocalCacheService.invalidate(_cacheKey);
      _fetchFromFirestore();
      return true;
    } catch (e) {
      ErrorHandler.showError("Failed to delete entry: $e");
      return false;
    }
  }
}
