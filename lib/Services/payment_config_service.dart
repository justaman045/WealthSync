import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class PaymentConfigService extends GetxController {
  static PaymentConfigService get to => Get.find();

  final RxString paymentMode = 'google_play'.obs;
  final RxString upiId = ''.obs;

  StreamSubscription? _sub;

  @override
  void onInit() {
    super.onInit();
    _sub = FirebaseFirestore.instance
        .collection('app_config')
        .doc('payment_settings')
        .snapshots()
        .listen((snap) {
      final data = snap.data() ?? {};
      paymentMode.value = data['paymentMode'] as String? ?? 'google_play';
      upiId.value = data['upiId'] as String? ?? '';
    });
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  Future<void> save({required String mode, required String upi}) async {
    await FirebaseFirestore.instance
        .collection('app_config')
        .doc('payment_settings')
        .set({'paymentMode': mode, 'upiId': upi}, SetOptions(merge: true));
  }
}
