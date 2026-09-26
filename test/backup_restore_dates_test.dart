import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Services/local_backup_service.dart';

void main() {
  group('backup restore date conversion', () {
    test('converts known date fields', () {
      final data = <String, dynamic>{
        'date': '2026-01-15T10:30:00.000Z',
        'createdAt': '2026-01-15T10:30:00.000Z',
        'nextDueDate': '2026-02-01T00:00:00.000Z',
        'trialEndDate': '2026-03-01T00:00:00.000Z',
        'timestamp': '2026-01-15T10:30:00.000Z',
      };

      LocalBackupService.debugRestoreDates(data);

      for (final key in data.keys) {
        expect(data[key], isA<Timestamp>(), reason: '$key should be a Timestamp');
      }
      expect((data['date'] as Timestamp).toDate().year, 2026);
    });

    test('suffixed date fields are converted', () {
      final data = <String, dynamic>{
        'maturityDate': '2026-06-30T00:00:00.000Z',
        'lastPaymentDate': '2026-05-01T00:00:00.000Z',
        'parsedTimestamp': '2026-05-01T00:00:00.000Z',
      };

      LocalBackupService.debugRestoreDates(data);

      expect(data['maturityDate'], isA<Timestamp>());
      expect(data['lastPaymentDate'], isA<Timestamp>());
      expect(data['parsedTimestamp'], isA<Timestamp>());
    });

    test('leaves free text alone even when it embeds a timestamp', () {
      // The data-loss case: a note that merely contains an ISO string.
      final data = <String, dynamic>{
        'note': '2026-01-15T10:00 was the party',
        'title': 'Dinner 2026-01-15T10:00:00.000Z',
        'description': 'starts 2026-02-01T00:00:00.000Z',
        'merchant': 'Store 2026-01-15T10:00',
        'name': '2026-01-15T10:00',
        'reason': 'refund 2026-01-15T10:00',
        'comment': 'x 2026-01-15T10:00',
        'message': 'y 2026-01-15T10:00',
        'body': 'z 2026-01-15T10:00',
        'label': 'l 2026-01-15T10:00',
      };

      LocalBackupService.debugRestoreDates(data);

      data.forEach((key, value) {
        expect(value, isA<String>(), reason: '$key must stay text');
      });
      expect(data['note'], '2026-01-15T10:00 was the party');
      expect(data['title'], 'Dinner 2026-01-15T10:00:00.000Z');
    });

    test('a non-date string that looks like a date is not converted', () {
      final data = <String, dynamic>{
        'category': '2026-01-15T10:00:00.000Z',
        'status': '2026-01-15T10:00:00.000Z',
        'someHash': '2026-01-15T10:00:00.000Z',
      };

      LocalBackupService.debugRestoreDates(data);

      data.forEach((key, value) {
        expect(value, isA<String>(), reason: '$key is not a date field');
      });
    });

    test('recurses into nested maps', () {
      final data = <String, dynamic>{
        'payment': <String, dynamic>{
          'nextDueDate': '2026-02-01T00:00:00.000Z',
          'note': '2026-01-15T10:00 was the party',
        },
      };

      LocalBackupService.debugRestoreDates(data);

      final payment = data['payment'] as Map<String, dynamic>;
      expect(payment['nextDueDate'], isA<Timestamp>());
      expect(payment['note'], isA<String>());
    });

    test('bare ISO strings in a list are not converted', () {
      final data = <String, dynamic>{
        'tags': ['2026-01-15T10:00:00.000Z', 'a note'],
        'dueDates': ['2026-02-01T00:00:00.000Z'],
      };

      LocalBackupService.debugRestoreDates(data);

      expect((data['tags'] as List)[0], isA<String>());
      expect((data['tags'] as List)[1], 'a note');
      expect((data['dueDates'] as List)[0], isA<Timestamp>());
    });

    test('recurses into maps nested inside lists', () {
      // Decoded JSON nests Map<String, dynamic>, which is the real shape.
      final data = <String, dynamic>{
        'installments': [
          <String, dynamic>{
            'dueDate': '2026-04-01T00:00:00.000Z',
            'note': '2026-01-15T10:00 was the party',
          },
        ],
      };

      LocalBackupService.debugRestoreDates(data);

      final first = (data['installments'] as List)[0] as Map<String, dynamic>;
      expect(first['dueDate'], isA<Timestamp>());
      expect(first['note'], isA<String>());
    });

    test('a string-pinned map is skipped instead of crashing', () {
      // Dart infers this literal as Map<String, String>, which passes an
      // `is Map<String, dynamic>` test but throws when a Timestamp is stored.
      final pinned = {
        'dueDate': '2026-04-01T00:00:00.000Z',
        'note': '2026-01-15T10:00 was the party',
      };
      final data = <String, dynamic>{'installments': [pinned]};

      expect(
        () => LocalBackupService.debugRestoreDates(data),
        returnsNormally,
      );
      expect(pinned['dueDate'], '2026-04-01T00:00:00.000Z');
      expect(pinned['note'], '2026-01-15T10:00 was the party');
    });

    test('non-ISO strings in date fields are untouched', () {
      final data = <String, dynamic>{'date': '15-01-2026', 'note': '2026'};
      LocalBackupService.debugRestoreDates(data);
      expect(data['date'], '15-01-2026');
      expect(data['note'], '2026');
    });

    test('numeric and boolean values are never touched', () {
      final data = <String, dynamic>{
        'amount': 1500.0,
        'isPro': true,
        'date': 20260115,
      };
      LocalBackupService.debugRestoreDates(data);
      expect(data['amount'], 1500.0);
      expect(data['isPro'], true);
      expect(data['date'], 20260115);
    });
  });
}
