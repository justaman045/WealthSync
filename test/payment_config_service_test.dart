import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Services/payment_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PaymentConfigService', () {
    test('instance is accessible', () {
      final service = PaymentConfigService();
      expect(service, isNotNull);
    });
  });
}
