import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:money_control/Controllers/subscription_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SubscriptionController polling', () {
    test('can be instantiated', () {
      Get.put(SubscriptionController());
      final controller = Get.find<SubscriptionController>();
      expect(controller, isNotNull);
      Get.delete<SubscriptionController>();
    });
  });
}
