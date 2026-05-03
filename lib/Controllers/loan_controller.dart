import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:money_control/Models/loan_model.dart';
import 'package:money_control/Models/recurring_payment_model.dart';
import 'package:money_control/Repositories/loan_repository.dart';
import 'package:money_control/Services/error_handler.dart';
import 'package:money_control/Services/recurring_service.dart';
import 'package:money_control/Services/wealth_service.dart';

class LoanController extends GetxController {
  static LoanController get to => Get.find();

  final _repo = LoanRepository();
  final _recurringService = RecurringService();
  StreamSubscription<List<LoanModel>>? _sub;

  RxList<LoanModel> loans = <LoanModel>[].obs;
  RxBool isLoading = true.obs;
  RxBool isSaving = false.obs;

  double get totalOutstanding =>
      loans.fold(0, (sum, l) => sum + l.outstandingBalance);

  double get totalMonthlyEmi => loans.fold(0, (sum, l) => sum + l.emiAmount);

  @override
  void onInit() {
    super.onInit();
    _bindLoans();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  void _bindLoans() {
    try {
      _sub = _repo.getLoansStream().listen(
        (list) {
          loans.value = list;
          isLoading.value = false;
          _syncToWealth();
        },
        onError: (_) => isLoading.value = false,
      );
    } catch (_) {
      isLoading.value = false;
    }
  }

  Future<void> _syncToWealth() async {
    try {
      await WealthService.updateAsset('loans', totalOutstanding);
    } catch (_) {}
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
      if (loan?.linkedRecurringPaymentId != null) {
        await _recurringService.deletePayment(loan!.linkedRecurringPaymentId!);
      }
      await _repo.deleteLoan(id);
      return true;
    } catch (_) {
      ErrorHandler.showError("Failed to remove loan.");
      return false;
    }
  }
}
