import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:developer';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // Added import
import 'package:get/get.dart';
import 'package:money_control/Screens/analysis.dart';
import 'package:money_control/Screens/wealth_builder.dart';

import 'package:money_control/Screens/homescreen.dart';
import 'package:money_control/Screens/analytics.dart';
import 'package:money_control/Screens/settings.dart';
import 'package:money_control/Screens/transaction_details.dart';
import 'package:money_control/Screens/edit_profile.dart'; // Added import
import 'package:money_control/Services/offline_queue.dart';

Curve curve = Curves.easeOutCubic;
Transition transition = Transition.cupertino;
Duration duration = const Duration(milliseconds: 250);

Future<void> gotoScreen(int index, int currentIndex) async {
  if (index == currentIndex) return;

  switch (index) {
    case 0:
      Get.offAll(
        () => const BankingHomeScreen(),
        curve: curve,
        transition: transition,
        duration: duration,
      );
      break;

    case 1:
      Get.offAll(
        () => const AnalyticsScreen(),
        curve: curve,
        transition: transition,
        duration: duration,
      );
      break;

    case 2:
      Get.offAll(
        () => const AIInsightsScreen(),
        curve: curve,
        transition: transition,
        duration: duration,
      );
      break;

    case 3:
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.email)
              .get();

          final age = doc.data()?['age'];

          if (age == null || (age is int && age <= 0)) {
            if (Get.context != null) {
              await showGeneralDialog(
                context: Get.context!,
                barrierDismissible: true,
                barrierLabel: "Dismiss",
                barrierColor: Colors.black.withValues(alpha: 0.8),
                transitionDuration: const Duration(milliseconds: 300),
                pageBuilder: (context, anim1, anim2) {
                  return Center(
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: 320.w,
                        padding: EdgeInsets.all(24.w),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2E1A47), Color(0xFF1A1A2E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28.r),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: EdgeInsets.all(16.w),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF00E5FF,
                                ).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person_rounded,
                                color: const Color(0xFF00E5FF),
                                size: 32.sp,
                              ),
                            ),
                            SizedBox(height: 20.h),
                            Text(
                              "Setup Required",
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              "To use the Wealth Builder, we need your age to calculate financial targets.",
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.white70,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 28.h),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text(
                                      "Cancel",
                                      style: TextStyle(color: Colors.white54),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      Get.to(() => const EditProfileScreen());
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00E5FF),
                                      foregroundColor: Colors.black,
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12.h,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      "Set Age",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                transitionBuilder: (context, anim1, anim2, child) {
                  return Transform.scale(
                    scale: Curves.easeOutBack.transform(anim1.value),
                    child: child,
                  );
                },
              );
            }
            return;
          }
        } catch (e) {
          debugPrint("Error checking age: $e");
          // Optionally allow access on error or show error
        }
      }

      Get.offAll(
        () => const WealthBuilderScreen(),
        curve: curve,
        transition: transition,
        duration: duration,
      );
      break;

    case 4:
      Get.offAll(
        () => const SettingsScreen(),
        curve: curve,
        transition: transition,
        duration: duration,
      );
      break;
  }
}

void gotoPage(Widget page) {
  Get.to(() => page, curve: curve, transition: transition, duration: duration);
}

void goBack() {
  if (Get.key.currentContext != null &&
      Navigator.canPop(Get.key.currentContext!)) {
    Navigator.pop(Get.key.currentContext!);
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
      return TransactionResultType.inProgress;
  }
}

Future<void> syncPendingTransactions() async {
  final pending = await OfflineQueueService.loadPending();
  if (pending.isEmpty) return;

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  for (var tx in pending) {
    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.email)
          .collection("transactions")
          .add(tx);
    } catch (e) {
      // still no internet → stop syncing
      return;
    }
  }

  // Clear only after successful sync
  await OfflineQueueService.clearPending();
  log("Pending transactions synced");
}
