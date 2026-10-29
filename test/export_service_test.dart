import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Services/export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExportService', () {
    test('instance is accessible', () {
      final service = ExportService();
      expect(service, isNotNull);
    });
  });
}
