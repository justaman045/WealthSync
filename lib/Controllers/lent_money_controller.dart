import 'package:get/get.dart';
import 'package:money_control/Models/lent_money_model.dart';
import 'package:money_control/Repositories/lent_money_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:money_control/Services/error_handler.dart';
import 'dart:async';

class LentMoneyController extends GetxController {
  final LentMoneyRepository _repository = LentMoneyRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  var entries = <LentMoneyModel>[].obs;
  var isLoading = false.obs;
  var isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    bindEntries();
  }

  void bindEntries() {
    entries.bindStream(_repository.getEntriesStream());
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
      return true;
    } catch (e) {
      ErrorHandler.showError("Failed to mark as settled: $e");
      return false;
    }
  }

  Future<bool> deleteEntry(String id) async {
    try {
      await _repository.deleteEntry(id);
      return true;
    } catch (e) {
      ErrorHandler.showError("Failed to delete entry: $e");
      return false;
    }
  }
}
