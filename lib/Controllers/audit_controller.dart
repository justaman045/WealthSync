import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Models/audit_models.dart';
import 'package:money_control/Services/audit_service.dart';
import 'package:money_control/Services/import_service.dart';
import 'package:money_control/Services/recurring_service.dart';

class AuditController extends GetxController {
  var duplicateGroups = <DuplicateGroup>[].obs;
  var signErrors = <SignError>[].obs;
  var orphanedRecurring = <OrphanedRecurring>[].obs;
  var bankMatched = <BankComparisonRow>[].obs;
  var bankOnlyRows = <BankComparisonRow>[].obs;
  var ledgerEntries = <LedgerEntry>[].obs;
  var isLoading = false.obs;
  var totalIssues = 0.obs;
  var openingBalance = 0.0.obs;

  Future<void> runFullAudit() async {
    isLoading.value = true;
    try {
      final txController = Get.find<TransactionController>();
      final txs = txController.transactions;
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      duplicateGroups.value = AuditService.detectDuplicates(txs);
      signErrors.value = AuditService.detectSignErrors(txs, uid);
      try {
        final recurringService = RecurringService();
        final payments = await recurringService.getPaymentsOnce();
        orphanedRecurring.value = AuditService.detectOrphanedRecurring(payments, txs);
      } catch (e) {
        debugPrint('Orphaned recurring detection error: $e');
      }
      totalIssues.value = duplicateGroups.length + signErrors.length + orphanedRecurring.length;

      ledgerEntries.value = AuditService.buildLedger(txs, openingBalance.value, uid);
    } catch (e) {
      debugPrint('Audit error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> importBankCsv() async {
    final csvData = await ImportService.pickAndParseCSV();
    if (csvData == null || csvData.isEmpty) return;

    isLoading.value = true;
    try {
      final txController = Get.find<TransactionController>();
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      final headerRow = csvData.first;
      final columnMap = _autoDetectColumns(headerRow);

      final dataRows = csvData.skip(1).toList();
      final results = AuditService.compareBankStatement(
        dataRows,
        txController.transactions,
        columnMap,
        uid,
      );
      bankMatched.value = results['matched'] ?? [];
      bankOnlyRows.value = results['bank-only'] ?? [];
    } catch (e) {
      debugPrint('Bank comparison error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void updateOpeningBalance(double value) {
    openingBalance.value = value;
    runFullAudit();
  }

  Map<String, int> _autoDetectColumns(List<dynamic> headers) {
    final map = <String, int>{};
    for (var i = 0; i < headers.length; i++) {
      final h = headers[i].toString().toLowerCase();
      if (h.contains('amount') || h.contains('debit') || h.contains('credit')) {
        map.putIfAbsent('amount', () => i);
      }
      if (h.contains('date')) map.putIfAbsent('date', () => i);
      if (h.contains('merchant') || h.contains('description') || h.contains('narration')) {
        map.putIfAbsent('merchant', () => i);
      }
    }
    return map;
  }
}
