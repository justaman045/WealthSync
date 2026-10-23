import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:developer';
import 'package:get/get.dart';
import 'package:money_control/Screens/main_shell.dart';
import 'package:money_control/Screens/transaction_details.dart';
import 'package:money_control/Services/offline_queue.dart';

Curve curve = Curves.easeOutCubic;
Transition transition = Transition.cupertino;
Duration duration = const Duration(milliseconds: 250);

Future<void> gotoScreen(String name) async {
  Get.offAll(
    () => MainShell(initialName: name),
    curve: curve,
    transition: transition,
    duration: duration,
  );
}

void gotoPage(Widget page) {
  Get.to(() => page, curve: curve, transition: transition, duration: duration);
}

void goBack() {
  final ctx = Get.key.currentContext;
  if (ctx != null && Navigator.canPop(ctx)) {
    Navigator.pop(ctx);
  } else {
    Get.back();
  }
}

TransactionResultType getTransactionTypeFromStatus(String? status) {
  switch (status?.toLowerCase()) {
    case 'success':
    case 'completed':
    case 'paid':
      return TransactionResultType.success;
    case 'pending':
    case 'in_progress':
    case 'processing':
      return TransactionResultType.inProgress;
    case 'failed':
    case 'declined':
    case 'cancelled':
      return TransactionResultType.failed;
    default:
      return TransactionResultType.failed;
  }
}

Future<void> syncPendingTransactions() async {
  final pending = await OfflineQueueService.loadPending();
  if (pending.isEmpty) return;

  final user = FirebaseAuth.instance.currentUser;
  if (user == null || user.email == null) return;

  final currentEmail = user.email!;
  final currentUid = user.uid;

  final txCollection = FirebaseFirestore.instance
      .collection("users")
      .doc(currentEmail)
      .collection("transactions");

  for (var tx in pending) {
    try {
      final ownerEmail = tx['ownerEmail'] as String?;
      final ownerUid = tx['ownerUid'] as String?;
      if ((ownerEmail != null && ownerEmail != currentEmail) ||
          (ownerUid != null && ownerUid != currentUid)) {
        await OfflineQueueService.removeFirst();
        continue;
      }
      final operation = tx['_operation'] as String? ?? 'add';
      final id = tx['id'] as String?;

      if (operation == 'delete' && id != null) {
        await txCollection.doc(id).delete();
      } else {
        // Remove internal metadata fields before writing to Firestore.
        final data = Map<String, dynamic>.from(tx)
          ..remove('_operation')
          ..remove('id');
        if (id != null) {
          await txCollection.doc(id).set(data);
        } else {
          // A save that timed out may have already landed server-side; the
          // queue re-write would then duplicate the transaction. Skip adds
          // whose createdAt already exists in Firestore.
          final createdAt = data['createdAt'];
          if (createdAt is Timestamp) {
            final existing = await txCollection
                .where('createdAt', isEqualTo: createdAt)
                .limit(1)
                .get();
            if (existing.docs.isNotEmpty) {
              await OfflineQueueService.removeFirst();
              continue;
            }
          }
          await txCollection.add(data);
        }
      }
      await OfflineQueueService.removeFirst();
    } catch (e) {
      // Still no internet — stop syncing; remaining items stay in queue.
      return;
    }
  }

  log("Pending transactions synced");
}
