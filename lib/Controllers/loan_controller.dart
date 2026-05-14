import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:money_control/Models/loan_model.dart';
import 'package:money_control/Models/recurring_payment_model.dart';
import 'package:money_control/Repositories/loan_repository.dart';
import 'package:money_control/Services/cache_service.dart';
import 'package:money_control/Services/error_handler.dart';
import 'package:money_control/Services/recurring_service.dart';
import 'package:flutter/foundation.dart';
import 'package:money_control/Services/wealth_service.dart';

class LoanController extends GetxController {
  static LoanController get to => Get.find();

  final _repo = LoanRepository();
  final _recurringService = RecurringService();
  final _auth = FirebaseAuth.instance;

  String? get _userEmail => _auth.currentUser?.email;
  String get _cacheKey => 'loans_${_userEmail ?? ''}';

  RxList<LoanModel> loans = <LoanModel>[].obs;
  RxBool isLoading = true.obs;
  RxBool isSaving = false.obs;

  double get totalOutstanding =>
      loans.fold(0, (sum, l) => sum + l.outstandingBalance);

  double get totalMonthlyEmi => loans.fold(0, (sum, l) => sum + l.emiAmount);

  @override
  void onInit() {
    super.onInit();
    _loadFromCache();
    _fetchFromFirestore();
  }

  void _loadFromCache() {
    final cached = LocalCacheService.get(_cacheKey);
    if (cached != null) {
      loans.value = (cached as List).map((e) {
        final map = LocalCacheService.hiveRestore(Map<String, dynamic>.from(e as Map));
        final id = map.remove('_id') as String? ?? '';
        return LoanModel.fromMap(id, map);
      }).toList();
      isLoading.value = false;
    }
  }

  Future<void> _fetchFromFirestore() async {
    try {
      final list = await _repo.getLoans();
      loans.value = list;
      if (_userEmail != null) {
        final cacheData = list.map((t) {
          final map = t.toMap();
          map['_id'] = t.id;
          return LocalCacheService.hiveSafe(map);
        }).toList();
        LocalCacheService.put(_cacheKey, cacheData, ttl: LocalCacheService.slow5m);
      }
      _syncToWealth();
    } catch (_) {
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _syncToWealth() async {
    try {
      await WealthService.updateAsset('loans', totalOutstanding);
    } catch (e) {
      debugPrint('LoanController: _syncToWealth failed: $e');
    }
  }

  Future<bool> addLoan({
    required String name,
    required LoanType loanType,
    required double principalAmount,
    required double interestRate,
    required int tenureMonths,
    required DateTime startDate,
    bool createRecurring = false,
  }) async {
    if (name.trim().isEmpty || principalAmount <= 0 || tenureMonths <= 0) {
      return false;
    }
    isSaving.value = true;
    try {
      final emi = LoanModel.calcEmi(principalAmount, interestRate, tenureMonths);
      final loan = LoanModel(
        id: '',
        name: name.trim(),
        loanType: loanType,
        principalAmount: principalAmount,
        interestRate: interestRate,
        emiAmount: emi,
        tenureMonths: tenureMonths,
        startDate: startDate,
      );
      final docRef = await _repo.addLoan(loan);
      LocalCacheService.invalidate(_cacheKey);
      _fetchFromFirestore();

      if (createRecurring) {
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final recurringId = const Uuid().v4();
        final payment = RecurringPayment(
          id: recurringId,
          userId: uid,
          title: '${loan.name} EMI',
          amount: emi,
          category: 'EMI',
          frequency: RecurringFrequency.monthly,
          startDate: startDate,
          nextDueDate: startDate,
          isActive: true,
        );
        await _recurringService.addPayment(payment);
        // Link recurring ID back to loan
        await _repo.updateLoan(
          LoanModel.fromMap(docRef.id, {
            ...loan.toMap(),
            'linkedRecurringPaymentId': recurringId,
          }),
        );
      }
      return true;
    } catch (_) {
      ErrorHandler.showError("Failed to save loan. Please try again.");
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> deleteLoan(String id) async {
    try {
      final loan = loans.firstWhereOrNull((l) => l.id == id);
      await _repo.deleteLoan(id);
      LocalCacheService.invalidate(_cacheKey);
      _fetchFromFirestore();
      if (loan?.linkedRecurringPaymentId != null) {
        await _recurringService.deletePayment(loan!.linkedRecurringPaymentId!);
      }
      return true;
    } catch (_) {
      ErrorHandler.showError("Failed to remove loan.");
      return false;
    }
  }
}
