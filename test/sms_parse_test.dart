import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Services/sms_service.dart';

SmsTransaction? parse(String body) =>
    SmsService.parseMessage(body, 'VK-OTP', DateTime(2026, 1, 15));

void main() {
  group('balance alerts are not transactions', () {
    // Each of these reaches parseMessage: isBankSms() accepts anything with
    // "alert", and the manual import screen calls parseMessage directly.
    test('rejects a plain available-balance alert', () {
      expect(parse('Balance alert: Avl Bal Rs. 12,345.67'), isNull);
      expect(parse('Your available balance is 5000'), isNull);
      expect(parse('A/c balance as on 15-Jan-2026: Rs. 9,999'), isNull);
    });

    test('rejects a closing-balance statement line', () {
      expect(parse('Closing balance: 15,000.00'), isNull);
      expect(parse('Total balance Rs 1,20,000'), isNull);
    });

    test('still parses a real txn quoted alongside a balance', () {
      // The first amount is the transaction, so the balance must not win.
      final t = parse(
        'Rs. 500.00 debited by SWIGGY on 15-01-26. Avl Bal 12,345.67',
      );
      expect(t, isNotNull);
      expect(t!.amount, 500.0);
      expect(t.isDebit, isTrue);
    });

    test('still parses a credit that mentions the balance', () {
      final t = parse('Rs. 2000 credited to your account. Total balance 5000');
      expect(t, isNotNull);
      expect(t!.amount, 2000.0);
      expect(t.isDebit, isFalse);
    });
  });

  group('bare numbers need a movement signal', () {
    test('rejects an OTP with no movement wording', () {
      expect(parse('123456 is your OTP for the transaction'), isNull);
    });

    test('rejects delivery/order narration', () {
      expect(parse('Your order 4471 has been shipped'), isNull);
    });

    test('still finds a bare amount when a signal is present', () {
      // No Rs/INR prefix, but "withdrawn" is a movement signal.
      final t = parse('You have withdrawn 150 today at ATM');
      expect(t, isNotNull);
      expect(t!.amount, 150.0);
      expect(t.isDebit, isTrue);
    });

    test('a 4-digit bare run is still skipped as a card-number candidate', () {
      // Pre-existing heuristic, documented so the signal gate is not mistaken
      // for a regression.
      expect(parse('You have withdrawn 1500 today at ATM'), isNull);
    });
  });

  group('regression: existing parsing still works', () {
    test('UPI debit without a currency prefix', () {
      final t = parse('debited by 86.00 from your account');
      expect(t, isNotNull);
      expect(t!.amount, 86.0);
      expect(t.isDebit, isTrue);
    });

    test('credited by is a credit', () {
      final t = parse('credited by 5000.00 to your account');
      expect(t, isNotNull);
      expect(t!.amount, 5000.0);
      expect(t.isDebit, isFalse);
    });

    test('refund wins over debit wording', () {
      final t = parse('Rs 300 refunded to your card');
      expect(t, isNotNull);
      expect(t!.isDebit, isFalse);
    });

    test('received by a merchant is a debit', () {
      final t = parse('Rs 450 received by AMAZON on 15-01-26');
      expect(t, isNotNull);
      expect(t!.isDebit, isTrue);
    });

    test('received by you is a credit', () {
      final t = parse('Rs 450 received by you on 15-01-26');
      expect(t, isNotNull);
      expect(t!.isDebit, isFalse);
    });

    test('a comma-grouped amount parses', () {
      final t = parse('Rs. 1,25,000.50 debited from your account');
      expect(t, isNotNull);
      expect(t!.amount, 125000.50);
    });

    test('a message with no amount is rejected', () {
      expect(parse('Your statement is ready'), isNull);
    });

    test('an OTP is still not a bank SMS', () {
      expect(SmsService.isBankSms('123456 is your OTP'), isFalse);
      expect(SmsService.isBankSms('Rs 500 debited by X'), isTrue);
      // "alert" is why balance alerts used to slip through the gate.
      expect(SmsService.isBankSms('Balance alert: Avl Bal 5000'), isTrue);
    });
  });
}
