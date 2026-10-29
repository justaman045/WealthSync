import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Services/iap_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IapService', () {
    test('instance is accessible', () {
      final service = IapService();
      expect(service, isNotNull);
    });
  });
}
