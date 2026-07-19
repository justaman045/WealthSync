import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class PaymentConfigService extends GetxController {
  static PaymentConfigService get to => Get.find();

  final RxString paymentMode = 'google_play'.obs;
  final RxString upiId = ''.obs;

  StreamSubscription? _sub;
  Timer? _webPollTimer;

  @override
  void onInit() {
    super.onInit();
    if (!kIsWeb) {
      _sub = FirebaseFirestore.instance
          .collection('app_config')
          .doc('payment_settings')
          .snapshots(includeMetadataChanges: true)
          .listen((snap) {
        final exists = snap.exists && snap.data() != null;
        if (exists) {
          final data = snap.data()!;
          paymentMode.value = data['paymentMode'] as String? ?? 'google_play';
          upiId.value = data['upiId'] as String? ?? '';
        }
      }, onError: (e) {
        debugPrint('PaymentConfigService: using defaults ($e)');
      });
    }
    // On web, Firestore is NOT accessed during Phase 1 to avoid triggering
    // the JS SDK WatchChangeAggregator ca9/b815 assertion bug.
    // Call startPolling() after login instead.
  }

  /// Start periodic polling for payment config. Called after login on web.
  void startPolling() {
    if (!kIsWeb) return;
    _fetchOnce();
    _webPollTimer?.cancel();
    _webPollTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _fetchOnce(),
    );
  }

  Future<void> _fetchOnce() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('payment_settings')
          .get();
      final exists = snap.exists && snap.data() != null;
      if (exists) {
        final data = snap.data()!;
        paymentMode.value = data['paymentMode'] as String? ?? 'google_play';
        upiId.value = data['upiId'] as String? ?? '';
      }
    } catch (e) {
      debugPrint('PaymentConfigService: using defaults ($e)');
    }
  }

  @override
  void onClose() {
    _sub?.cancel();
    _webPollTimer?.cancel();
    super.onClose();
  }

  Future<void> save({required String mode, required String upi}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('PaymentConfigService: cannot save, not authenticated');
      return;
    }
    await FirebaseFirestore.instance
        .collection('app_config')
        .doc('payment_settings')
        .set({'paymentMode': mode, 'upiId': upi}, SetOptions(merge: true));
  }
}
