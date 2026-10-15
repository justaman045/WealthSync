import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Utils/upi_response.dart';

/// The UPI `pay` MethodChannel response mapping is the difference between
/// "payment failed" and a silently-dismissed dialog. The subscription screen
/// previously required a non-empty txn id for SUCCESS and only matched
/// `FAILURE` (native sends `FAILED`), so both outcomes were silent. Pin the
/// exact native contract here.
void main() {
  group('parseUpiPaymentResponse', () {
    test('native RESULT_OK with no payload is a success', () {
      // MainActivity emits exactly this when the app confirms success but
      // returns no response — it has no txnId and must still be a success.
      final result = parseUpiPaymentResponse('Status=SUCCESS');
      expect(result.isSuccess, isTrue);
      expect(result.txnId, isEmpty);
    });

    test('success with txnId / txnRef / approvalRefNo is parsed', () {
      final result = parseUpiPaymentResponse(
        'Status=SUCCESS&txnId=TX123&txnRef=REF9&approvalRefNo=APP7',
      );
      expect(result.isSuccess, isTrue);
      expect(result.txnId, 'TX123');
      expect(result.approvalRef, 'APP7');
    });

    test('lowercase keys work too', () {
      final result = parseUpiPaymentResponse('status=success&txnid=abc');
      expect(result.isSuccess, isTrue);
      expect(result.txnId, 'abc');
    });

    test('SUBMITTED is pending, not success or failure', () {
      final result = parseUpiPaymentResponse('Status=SUBMITTED&txnId=Q');
      expect(result.isPending, isTrue);
      expect(result.isSuccess, isFalse);
      expect(result.isFailed, isFalse);
    });

    test('native FAILED result code is a failure', () {
      // MainActivity emits this for any non-OK/non-CANCELED result code.
      final result = parseUpiPaymentResponse('Status=FAILED&responseCode=2');
      expect(result.isFailed, isTrue);
      expect(result.txnId, isEmpty);
    });

    test('empty response (user backed out) is cancelled, not failed', () {
      expect(parseUpiPaymentResponse('').isCancelled, isTrue);
      expect(parseUpiPaymentResponse(null).isCancelled, isTrue);
      expect(parseUpiPaymentResponse('   ').isCancelled, isTrue);
    });

    test('an unknown status is treated as a failure', () {
      final result = parseUpiPaymentResponse('Status=WHATEVER');
      expect(result.isFailed, isTrue);
      expect(result.status, 'WHATEVER');
    });
  });
}
