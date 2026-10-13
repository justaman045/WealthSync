import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Services/cache_service.dart';

void main() {
  group('LocalCacheService.hiveSafe', () {
    test('converts a top-level Timestamp to an ISO string', () {
      final map = LocalCacheService.hiveSafe({
        'createdAt': Timestamp.fromDate(DateTime(2026, 8, 3, 10, 30)),
      });

      expect(map['createdAt'], isA<String>());
      expect(
        DateTime.parse(map['createdAt'] as String),
        DateTime(2026, 8, 3, 10, 30),
      );
    });

    test('recurses into a nested list of maps (lent-money repayments shape)', () {
      final map = LocalCacheService.hiveSafe({
        'dateLent': Timestamp.fromDate(DateTime(2026, 8, 3)),
        'repayments': [
          {
            'amount': 2500.0,
            'date': Timestamp.fromDate(DateTime(2026, 8, 4)),
            'note': 'First',
          },
        ],
      });

      final repayment = (map['repayments'] as List).first as Map;
      expect(repayment['date'], isA<String>());
      expect(
        DateTime.parse(repayment['date'] as String),
        DateTime(2026, 8, 4),
      );

      // A nested Timestamp previously made this throw.
      expect(() => jsonEncode(map), returnsNormally);
    });

    test('replaces Firestore sentinels with null', () {
      final map = LocalCacheService.hiveSafe({
        'createdAt': FieldValue.serverTimestamp(),
        'repayments': [
          {'date': FieldValue.serverTimestamp()},
        ],
      });

      expect(map['createdAt'], isNull);
      expect(((map['repayments'] as List).first as Map)['date'], isNull);
      expect(() => jsonEncode(map), returnsNormally);
    });

    test('leaves primitives untouched', () {
      final map = LocalCacheService.hiveSafe({
        'friendName': 'Rahul',
        'amount': 5000.0,
        'isSettled': false,
        'note': null,
        'tags': ['a', 'b'],
      });

      expect(map['friendName'], 'Rahul');
      expect(map['amount'], 5000.0);
      expect(map['isSettled'], false);
      expect(map['note'], isNull);
      expect(map['tags'], ['a', 'b']);
    });
  });

  group('LocalCacheService.hiveRestore', () {
    test('converts a top-level ISO string back to a Timestamp', () {
      final restored = LocalCacheService.hiveRestore({
        'createdAt': '2026-08-03T10:30:00.000',
        'friendName': 'Rahul',
      });

      expect(restored['createdAt'], isA<Timestamp>());
      expect(restored['friendName'], 'Rahul');
    });
  });
}
