import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Services/geo_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeoService', () {
    test('instance is accessible', () {
      final service = GeoService();
      expect(service, isNotNull);
    });
  });
}
