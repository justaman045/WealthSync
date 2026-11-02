import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Services/payment_config_service.dart';
import 'package:money_control/Utils/payment_config_fields.dart';

/// The admin payment screen keeps a live Firestore snapshot and a local form at
/// the same time. These pure rules decide what a save writes and whether the
/// form has anything to save; keeping them here means the screen and the
/// service cannot disagree about either without a test failing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PaymentConfigService', () {
    test('instance is accessible', () {
      final service = PaymentConfigService();
      expect(service, isNotNull);
    });
  });

  group('normalizePaymentMode', () {
    test('keeps a known mode', () {
      expect(normalizePaymentMode('upi'), 'upi');
      expect(normalizePaymentMode('google_play'), 'google_play');
    });

    test('falls back to Play Billing for missing or unknown values', () {
      expect(normalizePaymentMode(null), 'google_play');
      expect(normalizePaymentMode(''), 'google_play');
      // The old screen seeded a `cash` mode that was never a real option and
      // would have been written back to Firestore.
      expect(normalizePaymentMode('cash'), 'google_play');
    });
  });

  group('normalizeUpiId', () {
    test('trims padding so an untouched field is not dirty', () {
      expect(normalizeUpiId('  shop@upi '), 'shop@upi');
      expect(normalizeUpiId(null), '');
    });
  });

  group('paymentConfigIsDirty', () {
    test('a clean form is not dirty', () {
      expect(
        paymentConfigIsDirty(
          mode: 'upi',
          upi: 'shop@upi',
          savedMode: 'upi',
          savedUpi: ' shop@upi ',
        ),
        isFalse,
      );
    });

    test('changing the mode makes it dirty', () {
      expect(
        paymentConfigIsDirty(
          mode: 'google_play',
          upi: '',
          savedMode: 'upi',
          savedUpi: '',
        ),
        isTrue,
      );
    });

    test('changing the UPI id makes it dirty', () {
      expect(
        paymentConfigIsDirty(
          mode: 'upi',
          upi: 'new@upi',
          savedMode: 'upi',
          savedUpi: 'old@upi',
        ),
        isTrue,
      );
    });
  });

  group('paymentConfigPayload', () {
    test('writes the mode, the trimmed UPI id and the audit trail', () {
      final payload = paymentConfigPayload(
        mode: 'upi',
        upi: '  shop@upi ',
        updatedBy: 'admin@example.com',
        updatedAt: 'SERVER_TS',
      );
      expect(payload['paymentMode'], 'upi');
      expect(payload['upiId'], 'shop@upi');
      expect(payload['updatedBy'], 'admin@example.com');
      expect(payload['updatedAt'], 'SERVER_TS');
    });

    test('an invalid mode is normalized before it reaches Firestore', () {
      final payload = paymentConfigPayload(
        mode: 'cash',
        upi: '',
        updatedBy: 'admin@example.com',
        updatedAt: 'SERVER_TS',
      );
      expect(payload['paymentMode'], 'google_play');
    });
  });
}
