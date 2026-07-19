import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Models/audit_models.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Services/audit_service.dart';
import 'package:money_control/Services/import_service.dart';
import 'package:money_control/Services/recurring_service.dart';
import 'package:money_control/Services/error_handler.dart';
import 'package:money_control/Services/local_backup_service.dart';

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
      if (!Get.isRegistered<TransactionController>()) return;
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

  // ---------------------------------------------------------------------------
  // Resolution: Duplicates
  // ---------------------------------------------------------------------------

  /// Delete all transactions in [group] except the one at [keepIndex].
  Future<int> resolveDuplicate(DuplicateGroup group, {required int keepIndex}) async {
    if (!Get.isRegistered<TransactionController>()) return 0;
    final txController = Get.find<TransactionController>();
    var deleted = 0;
    for (var i = 0; i < group.transactions.length; i++) {
      if (i == keepIndex) continue;
      final ok = await txController.deleteTransaction(group.transactions[i]);
      if (ok) deleted++;
    }
    duplicateGroups.removeWhere((g) => g.id == group.id);
    _recalcTotal();
    return deleted;
  }

  // ---------------------------------------------------------------------------
  // Resolution: Sign Errors
  // ---------------------------------------------------------------------------

  /// Auto-correct the sign of a transaction with wrong convention.
  Future<bool> resolveSignError(SignError error) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final tx = error.transaction;
    final correctedAmount = -tx.amount;

    final updated = TransactionModel(
      id: tx.id,
      senderId: tx.senderId,
      recipientId: tx.recipientId,
      recipientName: tx.recipientName,
      amount: correctedAmount,
      currency: tx.currency,
      tax: tx.tax,
      note: tx.note,
      category: tx.category,
      date: tx.date,
      attachmentUrl: tx.attachmentUrl,
      status: tx.status,
      createdAt: tx.createdAt,
      recurringPaymentId: tx.recurringPaymentId,
      smsDedupeKey: tx.smsDedupeKey,
    );

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email)
          .collection('transactions')
          .doc(tx.id)
          .update(updated.toMap())
          .timeout(const Duration(seconds: 5));

      final email = user.email;
      if (email != null) LocalBackupService.backupUserTransactions(email);

      signErrors.removeWhere((s) => s.id == error.id);
      _recalcTotal();
      return true;
    } catch (e) {
      debugPrint('Sign fix error: $e');
      ErrorHandler.showError('Failed to fix sign: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Resolution: Orphaned Recurring
  // ---------------------------------------------------------------------------

  /// Create a missing transaction for an orphaned recurring payment and advance
  /// the due date.
  Future<bool> resolveOrphan(OrphanedRecurring orphan) async {
    try {
      await RecurringService().markAsPaid(orphan.payment, createTransaction: true);

      orphanedRecurring.removeWhere((o) => o.id == orphan.id);
      _recalcTotal();
      return true;
    } catch (e) {
      debugPrint('Orphan resolve error: $e');
      ErrorHandler.showError('Failed to create transaction: $e');
      return false;
    }
  }

  /// Skip this cycle: advance nextDueDate without creating a transaction.
  Future<bool> skipOrphan(OrphanedRecurring orphan) async {
    try {
      await RecurringService().markAsPaid(orphan.payment, createTransaction: false);

      orphanedRecurring.removeWhere((o) => o.id == orphan.id);
      _recalcTotal();
      return true;
    } catch (e) {
      debugPrint('Orphan skip error: $e');
      ErrorHandler.showError('Failed to skip cycle: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Dismiss
  // ---------------------------------------------------------------------------

  void dismissIssue(String id) {
    duplicateGroups.removeWhere((g) => g.id == id);
    signErrors.removeWhere((s) => s.id == id);
    orphanedRecurring.removeWhere((o) => o.id == id);
    _recalcTotal();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _recalcTotal() {
    totalIssues.value = duplicateGroups.length + signErrors.length + orphanedRecurring.length;
  }

  Future<void> importBankCsv() async {
    final csvData = await ImportService.pickAndParseCSV();
    if (csvData == null || csvData.isEmpty) return;

    isLoading.value = true;
    try {
      if (!Get.isRegistered<TransactionController>()) return;
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
