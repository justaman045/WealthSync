import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService', () {
    test('instance is accessible', () {
      final service = NotificationService();
      expect(service, isNotNull);
    });
  });
}
