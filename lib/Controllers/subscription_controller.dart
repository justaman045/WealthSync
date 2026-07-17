import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:money_control/Platform/iap_platform.dart';
import 'package:money_control/main.dart';
import 'package:money_control/Services/error_handler.dart';
import 'package:money_control/Services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SubscriptionStatus { free, pending, pro }

class SubscriptionController extends GetxController {
  static SubscriptionController get to => Get.find();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get _userEmail => _auth.currentUser?.email;

  StreamSubscription? _statusSub;
  StreamSubscription? _authSub;

  Rx<SubscriptionStatus> subscriptionStatus = SubscriptionStatus.free.obs;
  RxBool isAdmin = false.obs;
  Rx<DateTime?> expiryDate = Rx<DateTime?>(null);
  Rx<DateTime?> trialEndDate = Rx<DateTime?>(null);
  RxBool trialUsed = false.obs;
  RxString planType = ''.obs;

  bool get isTrial {
    final end = trialEndDate.value;
    if (end == null) return false;
    return subscriptionStatus.value == SubscriptionStatus.free &&
        DateTime.now().isBefore(end);
  }

  bool get trialActive {
    final end = trialEndDate.value;
    return end != null && DateTime.now().isBefore(end);
  }

  int get daysLeftInTrial {
    final end = trialEndDate.value;
    if (end == null) return 0;
    return end.difference(DateTime.now()).inDays.clamp(0, 30);
  }

  bool get isPro =>
      subscriptionStatus.value == SubscriptionStatus.pro || isTrial;
  bool get isPending => subscriptionStatus.value == SubscriptionStatus.pending;

  @override
  void onInit() {
    super.onInit();
    checkSubscriptionStatus();
  }

  @override
  void onClose() {
    _statusSub?.cancel();
    _authSub?.cancel();
    super.onClose();
  }

  void checkSubscriptionStatus() {
    _statusSub?.cancel();
    _statusSub = null;
    final user = _auth.currentUser;
    final email = _userEmail;
    if (user != null && email != null) {
      _statusSub = _firestore.collection('users').doc(email).snapshots().listen((
        snapshot,
      ) {
        _onSubscriptionSnapshot(snapshot, email);
      }, onError: (e) {
        debugPrint('SubscriptionController stream error: $e');
      });
    } else {
      subscriptionStatus.value = SubscriptionStatus.free;
      isAdmin.value = false;
      expiryDate.value = null;
      _authSub = _auth.authStateChanges().listen((user) {
        if (user != null) {
          _authSub?.cancel();
          _authSub = null;
          checkSubscriptionStatus();
        } else {
          subscriptionStatus.value = SubscriptionStatus.free;
          isAdmin.value = false;
          expiryDate.value = null;
        }
      });
    }
  }

  void _onSubscriptionSnapshot(DocumentSnapshot snapshot, String email) {
    try {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>?;
        if (data != null) {
          SubscriptionStatus newStatus = SubscriptionStatus.free;

          final adminFlag = data['isAdmin'] == true;
          isAdmin.value = adminFlag;

          if (adminFlag) {
            newStatus = SubscriptionStatus.pro;
          } else if (data.containsKey('subscriptionStatus')) {
            newStatus = _parseStatus((data['subscriptionStatus'] as String?) ?? '');
          } else if (data.containsKey('isPro') && data['isPro'] == true) {
            newStatus = SubscriptionStatus.pro;
          }

          if (data.containsKey('planType')) {
            planType.value = data['planType'] as String? ?? '';
          }

          if (!adminFlag &&
              newStatus == SubscriptionStatus.pro &&
              data.containsKey('expiryDate')) {
            final expiry = (data['expiryDate'] as Timestamp?)?.toDate();
            if (expiry != null) {
              expiryDate.value = expiry;
              if (DateTime.now().isAfter(expiry)) {
                newStatus = SubscriptionStatus.free;
                expiryDate.value = null;
                _expireSubscription(email);
              }
            }
          } else if (!adminFlag) {
            expiryDate.value = null;
          }

          if (!adminFlag && newStatus == SubscriptionStatus.free) {
            _handleTrialLogic(data, email);
          } else {
            trialEndDate.value = null;
          }

          _persistStatus(newStatus, email);
          subscriptionStatus.value = newStatus;
        }
      } else {
        subscriptionStatus.value = SubscriptionStatus.free;
        isAdmin.value = false;
        expiryDate.value = null;
      }
    } catch (e) {
      debugPrint('SubscriptionController listener error: $e');
    }
  }

  void _handleTrialLogic(Map<String, dynamic> data, String email) {
    if (!data.containsKey('trialEndDate')) {
      final isReferred = data.containsKey('referredBy') && data['referredBy'] != null;
      final trialDays = isReferred ? 30 : 7;
      final trialEnd = DateTime.now().add(Duration(days: trialDays));
      _firestore.collection('users').doc(email).set({
        'trialEndDate': Timestamp.fromDate(trialEnd),
      }, SetOptions(merge: true)).then((_) {
        trialEndDate.value = trialEnd;
        trialUsed.value = true;
      }).catchError((e) {
        debugPrint('Failed to save trial end date: $e');
        ErrorHandler.showError("Failed to activate trial. Please try again.");
      });
    } else {
      trialUsed.value = true;
      final end = (data['trialEndDate'] as Timestamp?)?.toDate();
      trialEndDate.value = (end != null && DateTime.now().isBefore(end)) ? end : null;
    }
  }

  Future<void> _persistStatus(SubscriptionStatus newStatus, String email) async {
    final prefs = await SharedPreferences.getInstance();
    final prefKey = 'last_sub_status_$email';
    final lastStatusStr = prefs.getString(prefKey);
    final lastStatus = lastStatusStr != null
        ? _parseStatus(lastStatusStr)
        : SubscriptionStatus.free;

    if (newStatus != lastStatus) {
      if (lastStatusStr != null || newStatus != SubscriptionStatus.free) {
        _handleStatusChange(lastStatus, newStatus);
      }
      await prefs.setString(prefKey, newStatus.name);
    }
  }

  Future<void> _expireSubscription(String email) async {
    await _firestore.collection('users').doc(email).set({
      'subscriptionStatus': 'free',
      'isPro': false,
      'expiredAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    NotificationService.showNotification(
      title: "Subscription Expired",
      body: "Your Pro plan has expired. Renew now to restore access.",
    );
  }

  void _handleStatusChange(
    SubscriptionStatus oldStatus,
    SubscriptionStatus newStatus,
  ) {
    if (oldStatus == SubscriptionStatus.pending &&
        newStatus == SubscriptionStatus.pro) {
      NotificationService.showNotification(
        title: "Upgrade Approved! 🎉",
        body: "Congratulations! You are now a Pro member.",
      );
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text(
            "Upgrade Approved! 🎉\nCongratulations! You are now a Pro member.",
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 5),
        ),
      );
    } else if (oldStatus == SubscriptionStatus.pending &&
        newStatus == SubscriptionStatus.free) {
      NotificationService.showNotification(
        title: "Request Rejected",
        body: "Your upgrade request was rejected. Contact support for help.",
      );
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text("Your upgrade request was rejected."),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 5),
        ),
      );
    } else if (newStatus == SubscriptionStatus.pro) {
      NotificationService.showNotification(
        title: "You are now Pro! 💎",
        body: "Your subscription status has been updated to Pro.",
      );
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text("You are now Pro! 💎"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
    } else if (oldStatus == SubscriptionStatus.pro &&
        newStatus == SubscriptionStatus.free) {
      NotificationService.showNotification(
        title: "Subscription Ended ⚠️",
        body: "Your Pro subscription has ended. You are now on the Free plan.",
      );
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text(
            "Subscription Ended ⚠️\nYou are now on the Free plan.",
          ),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  SubscriptionStatus _parseStatus(String status) {
    switch (status) {
      case 'pro':
        return SubscriptionStatus.pro;
      case 'pending':
        return SubscriptionStatus.pending;
      default:
        return SubscriptionStatus.free;
    }
  }

  /// User requests an upgrade (sets status to pending)
  Future<void> requestUpgrade(String transactionId, String plan) async {
    final email = _userEmail;
    if (email == null) return;
    try {
      // Client-side rate limit: block requests within 60 seconds of previous
      final doc = await _firestore.collection('users').doc(email).get();
      if (doc.exists) {
        final lastReq = doc.data()?['lastUpgradeRequest'] as Timestamp?;
        if (lastReq != null) {
          final secondsSince = DateTime.now().difference(lastReq.toDate()).inSeconds;
          if (secondsSince < 60) {
            Get.snackbar(
              'Too Many Requests',
              'Please wait a moment before trying again.',
              backgroundColor: Colors.orangeAccent,
              colorText: Colors.white,
            );
            return;
          }
        }
      }

      await _firestore.collection('users').doc(email).set({
        'subscriptionStatus': 'pending',
        'lastUpgradeRequest': FieldValue.serverTimestamp(),
        'transactionId': transactionId,
        'requestedPlan': plan,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('requestUpgrade error: $e');
      ErrorHandler.showError("Failed to request upgrade. Please try again.");
    }
  }

  /// Admin approves an upgrade
  Future<void> approveUpgrade(String email) async {
    try {
      final doc = await _firestore.collection('users').doc(email).get();
      String plan = 'Monthly';
      final data = doc.data();
      if (doc.exists && data != null && data.containsKey('requestedPlan')) {
        plan = (data['requestedPlan'] as String?) ?? 'Monthly';
      }

      final DateTime now = DateTime.now();
      // Use calendar arithmetic with clamping to handle month overflow
      final int targetMonth = now.month + (plan == 'Yearly' ? 12 : 1);
      final int targetYear = now.year + (targetMonth - 1) ~/ 12;
      final int clampedMonth = ((targetMonth - 1) % 12) + 1;
      final lastDayOfMonth = DateTime(targetYear, clampedMonth + 1, 0).day;
      final int clampedDay = now.day.clamp(1, lastDayOfMonth);
      final DateTime expiry = DateTime(targetYear, clampedMonth, clampedDay);

      await _firestore.collection('users').doc(email).set({
        'subscriptionStatus': 'pro',
        'isPro': true,
        'proSince': FieldValue.serverTimestamp(),
        'planType': plan,
        'expiryDate': Timestamp.fromDate(expiry),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('approveUpgrade error: $e');
      ErrorHandler.showError("Failed to approve upgrade. Please try again.");
    }
  }

  /// Admin rejects an upgrade
  Future<void> rejectUpgrade(String email) async {
    try {
      await _firestore.collection('users').doc(email).set({
        'subscriptionStatus': 'free',
        'isPro': false,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('rejectUpgrade error: $e');
      ErrorHandler.showError("Failed to reject upgrade. Please try again.");
    }
  }

  /// User cancels their own subscription (or ends their free trial)
  Future<void> cancelSubscription() async {
    final email = _userEmail;
    if (email == null) return;
    try {
      trialEndDate.value = null;
      await _firestore.collection('users').doc(email).set({
        'subscriptionStatus': 'free',
        'isPro': false,
        'cancelledAt': FieldValue.serverTimestamp(),
        'expiryDate': FieldValue.delete(),
        'planType': FieldValue.delete(),
        'trialEndDate': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(seconds: 1)),
        ),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('cancelSubscription error: $e');
      ErrorHandler.showError("Failed to cancel subscription. Please try again.");
    }
  }

  /// Activates Pro after a successful Google Play Billing purchase
  Future<void> activateGooglePlaySubscription(PurchaseDetails purchase) async {
    final email = _userEmail;
    if (email == null) return;

    try {
      final isMonthly = purchase.productID == 'money_control_monthly';
      final now = DateTime.now();
      final int targetMonth = now.month + (isMonthly ? 1 : 12);
      final int targetYear = now.year + (targetMonth - 1) ~/ 12;
      final int clampedMonth = ((targetMonth - 1) % 12) + 1;
      final lastDayOfMonth = DateTime(targetYear, clampedMonth + 1, 0).day;
      final int clampedDay = now.day.clamp(1, lastDayOfMonth);
      final expiry = DateTime(targetYear, clampedMonth, clampedDay);

      await _firestore.collection('users').doc(email).set({
        'subscriptionStatus': 'pro',
        'isPro': true,
        'planType': isMonthly ? 'Monthly' : 'Yearly',
        'expiryDate': Timestamp.fromDate(expiry),
        'proSince': FieldValue.serverTimestamp(),
        'purchaseToken': purchase.verificationData.serverVerificationData,
        'orderId': purchase.purchaseID,
        'purchaseSource': 'google_play',
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('activateGooglePlaySubscription error: $e');
      ErrorHandler.showError("Failed to activate subscription. Please contact support.");
    }
  }

  /// Manually set pro status (for testing / admin use)
  Future<void> setProStatus(bool status) async {
    final email = _userEmail;
    if (email == null) return;
    try {
      await _firestore.collection('users').doc(email).set({
        'subscriptionStatus': status ? 'pro' : 'free',
        'isPro': status,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('setProStatus error: $e');
      ErrorHandler.showError("Failed to update status.");
    }
  }
}
