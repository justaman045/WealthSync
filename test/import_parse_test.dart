import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Services/import_service.dart';

void main() {
  group('import date disambiguation', () {
    test('a first component above 12 can only be a day', () {
      final d = ImportService.debugTryParseDate('13/02/2026');
      expect(d, isNotNull);
      expect(d!.day, 13);
      expect(d.month, 2);
      expect(d.year, 2026);
    });

    test('a second component above 12 can only be a month', () {
      final d = ImportService.debugTryParseDate('02/13/2026');
      expect(d, isNotNull);
      expect(d!.month, 2);
      expect(d.day, 13);
      expect(d.year, 2026);
    });

    test('ISO dates are never read as day-first', () {
      final d = ImportService.debugTryParseDate('2026-01-15');
      expect(d, isNotNull);
      expect(d!.year, 2026);
      expect(d.month, 1);
      expect(d.day, 15);
    });

    test('an ambiguous numeric date prefers dd/MM', () {
      final d = ImportService.debugTryParseDate('05/06/2026');
      expect(d, isNotNull);
      expect(d!.day, 5);
      expect(d.month, 6);
    });

    test('dashes and two-digit years are handled', () {
      final dashed = ImportService.debugTryParseDate('28-01-26');
      expect(dashed, isNotNull);
      expect(dashed!.day, 28);
      expect(dashed.month, 1);
      expect(dashed.year, 2026);
    });

    test('named months still parse', () {
      final d = ImportService.debugTryParseDate('15-Jan-2026');
      expect(d, isNotNull);
      expect(d!.day, 15);
      expect(d.month, 1);
    });

    test('garbage returns null rather than today', () {
      expect(ImportService.debugTryParseDate('not a date'), isNull);
      expect(ImportService.debugTryParseDate(''), isNull);
    });
  });

  group('import direction column', () {
    test('a debit/credit column overrides a positive amount', () {
      expect(ImportService.debugDirection('Debit', 500), isTrue);
      expect(ImportService.debugDirection('DR', 500), isTrue);
      expect(ImportService.debugDirection('expense', 500), isTrue);
      expect(ImportService.debugDirection('Payment', 500), isTrue);
    });

    test('a credit column marks income', () {
      expect(ImportService.debugDirection('Credit', 500), isFalse);
      expect(ImportService.debugDirection('CR', 500), isFalse);
      expect(ImportService.debugDirection('Refund', 500), isFalse);
      expect(ImportService.debugDirection('deposit', 500), isFalse);
    });

    test('an unmapped type value falls back to the amount sign', () {
      expect(ImportService.debugDirection('', -500), isTrue);
      expect(ImportService.debugDirection('', 500), isFalse);
    });

    test('a descriptive type value falls back to the amount sign', () {
      expect(ImportService.debugDirection('ATM Withdrawal', 500), isFalse);
      expect(ImportService.debugDirection('UPI transfer', -500), isTrue);
    });
  });
}
