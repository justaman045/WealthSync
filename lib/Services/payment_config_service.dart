import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:money_control/Utils/auth_gated_listener.dart';
import 'package:money_control/Utils/payment_config_fields.dart';

class PaymentConfigService extends GetxController {
  static PaymentConfigService get to => Get.find();

  final RxString paymentMode = 'google_play'.obs;
  final RxString upiId = ''.obs;

  /// Audit trail of the last save, shown on the admin screen. `null` until the
  /// document has actually been written by a build that records it.
  final Rxn<DateTime> updatedAt = Rxn<DateTime>();
  final RxString updatedBy = ''.obs;

  Timer? _webPollTimer;

  /// Auth-gated native listener (see [AuthGatedListener]). This service is
  /// registered in Phase 1, before login, so subscribing directly produced an
  /// unauthenticated `PERMISSION_DENIED` read on every cold start.
  final AuthGatedListener<DocumentSnapshot<Map<String, dynamic>>> _gated =
      AuthGatedListener(label: 'PaymentConfigService');

  @override
  void onInit() {
    super.onInit();
    if (!kIsWeb) {
      _gated.start(
        factory: () => FirebaseFirestore.instance
            .collection('app_config')
            .doc('payment_settings')
            .snapshots(includeMetadataChanges: true),
        onData: _applyDoc,
      );
    }
    // On web, Firestore is NOT accessed during Phase 1 to avoid triggering
    // the JS SDK WatchChangeAggregator ca9/b815 assertion bug.
    // Call startPolling() after login instead.
  }

  /// Applies an `app_config/payment_settings` doc to the reactive fields.
  void _applyDoc(DocumentSnapshot<Map<String, dynamic>> snap) {
    final exists = snap.exists && snap.data() != null;
    if (!exists) return;
    final data = snap.data()!;
    paymentMode.value = normalizePaymentMode(data['paymentMode']);
    upiId.value = normalizeUpiId(data['upiId']);
    updatedBy.value = (data['updatedBy'] as String?)?.trim() ?? '';
    final rawUpdatedAt = data['updatedAt'];
    updatedAt.value = rawUpdatedAt is Timestamp
        ? rawUpdatedAt.toDate()
        : rawUpdatedAt is DateTime
        ? rawUpdatedAt
        : null;
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
      _applyDoc(snap);
    } catch (e) {
      debugPrint('PaymentConfigService: using defaults ($e)');
    }
  }

  @override
  void onClose() {
    _gated.stop();
    _webPollTimer?.cancel();
    super.onClose();
  }

  /// Persists the payment config and records who changed it.
  ///
  /// The write is a merge so it cannot drop keys this build does not know about.
  /// `updatedAt` uses a server timestamp so two admins on skewed phones cannot
  /// write a "last updated" in the future.
  Future<void> saveConfig({required String mode, required String upi}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('PaymentConfigService: cannot save, not authenticated');
      return;
    }
    await FirebaseFirestore.instance
        .collection('app_config')
        .doc('payment_settings')
        .set(
          paymentConfigPayload(
            mode: mode,
            upi: upi,
            updatedBy: user.email ?? user.uid,
            updatedAt: FieldValue.serverTimestamp(),
          ),
          SetOptions(merge: true),
        );
  }
}
