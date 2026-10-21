import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Models/user_model.dart';

/// A DOB exactly [years] old as of *today*, so age assertions are stable
/// regardless of which day the suite runs.
Timestamp _dobAged(int years, {int monthOffset = 0, int dayOffset = 0}) {
  final now = DateTime.now();
  var y = now.year - years;
  var m = now.month;
  var d = now.day;

  m += monthOffset;
  while (m < 1) {
    m += 12;
    y -= 1;
  }
  while (m > 12) {
    m -= 12;
    y += 1;
  }
  d += dayOffset;
  return Timestamp.fromDate(DateTime(y, m, d));
}

void main() {
  group('UserModel.fromMap()', () {
    test('a null map yields a bare model rather than throwing', () {
      // users/{email} can legitimately not exist yet.
      final u = UserModel.fromMap('uid1', null);
      expect(u.uid, 'uid1');
      expect(u.firstName, isNull);
      expect(u.calculatedAge, isNull);
    });

    test('reads profileImage from any of the three persisted spellings', () {
      for (final key in ['photoURL', 'photoUrl', 'profileImage']) {
        final u = UserModel.fromMap('uid1', {key: 'https://x/a.png'});
        expect(u.profileImage, 'https://x/a.png', reason: 'key=$key');
      }
    });

    test('coerces a non-String field instead of throwing', () {
      // A foreign client can persist a phone number as a num; an implicit
      // dynamic→String cast would throw here.
      final u = UserModel.fromMap('uid1', {'phone': 9876543210});
      expect(u.phone, '9876543210');
    });

    test('treats a non-numeric currentBalance as absent', () {
      final u = UserModel.fromMap('uid1', {'currentBalance': 'oops'});
      expect(u.currentBalance, isNull);
    });

    test('accepts dob as Timestamp, DateTime or ISO string', () {
      final ts = Timestamp.fromDate(DateTime(1995, 6, 15));
      expect(UserModel.fromMap('u', {'dob': ts}).dob, ts);
      expect(
        UserModel.fromMap('u', {'dob': DateTime(1995, 6, 15)}).dob?.toDate(),
        DateTime(1995, 6, 15),
      );
      expect(
        UserModel.fromMap('u', {'dob': '1995-06-15'}).dob?.toDate(),
        DateTime(1995, 6, 15),
      );
    });

    test('an unparseable dob falls back to the stored age', () {
      final u = UserModel.fromMap('u', {'dob': 'not-a-date', 'age': 41});
      expect(u.dob, isNull);
      expect(u.age, 41);
    });

    test('a dob takes precedence over a stored age', () {
      // The derived value must win so a stale `age` field cannot go out of date.
      final u = UserModel.fromMap('u', {'dob': _dobAged(30), 'age': 99});
      expect(u.age, 30);
    });
  });

  group('UserModel.calculatedAge', () {
    test('is null when there is no dob and no age', () {
      expect(UserModel(uid: 'u').calculatedAge, isNull);
    });

    test('uses the stored age when no dob is present', () {
      expect(UserModel(uid: 'u', age: 27).calculatedAge, 27);
    });

    test('is exact on the birthday', () {
      expect(UserModel(uid: 'u', dob: _dobAged(30)).calculatedAge, 30);
    });

    test('does NOT count a birthday that has not arrived yet', () {
      // Born one month ago in a year that makes them 30; the birthday in the
      // current month hasn't happened yet (their birth day is tomorrow).
      final u = UserModel(uid: 'u', dob: _dobAged(30, dayOffset: 1));
      expect(u.calculatedAge, 29);
    });

    test('counts the age once the birthday has passed this month', () {
      final u = UserModel(uid: 'u', dob: _dobAged(30, dayOffset: -1));
      expect(u.calculatedAge, 30);
    });

    test('handles a birthday in a month that has already gone by', () {
      final u = UserModel(uid: 'u', dob: _dobAged(30, monthOffset: -1));
      expect(u.calculatedAge, 30);
    });

    test('handles a birthday still to come later this year', () {
      final u = UserModel(uid: 'u', dob: _dobAged(30, monthOffset: 1));
      expect(u.calculatedAge, 29);
    });

    test('_ageFromTimestamp agrees with calculatedAge', () {
      // The two implementations are duplicated; this keeps them in lockstep.
      for (final offset in [-2, -1, 0, 1, 2]) {
        final dob = _dobAged(25, monthOffset: offset);
        final viaGetter = UserModel(uid: 'u', dob: dob).calculatedAge;
        final viaFromMap = UserModel.fromMap('u', {'dob': dob}).age;
        expect(viaFromMap, viaGetter, reason: 'monthOffset=$offset');
      }
    });
  });

  group('UserModel.toMap()', () {
    test('stamps updatedAt server-side', () {
      final map = UserModel(uid: 'u').toMap();
      expect(map['updatedAt'], isA<FieldValue>());
    });

    test('omits null fields rather than writing them as null', () {
      // Omitting keeps a partial update from clearing an existing value.
      final map = UserModel(uid: 'u').toMap();
      expect(map.containsKey('firstName'), false);
      expect(map.containsKey('phone'), false);
      expect(map.containsKey('dob'), false);
    });

    test('writes the avatar under photoURL', () {
      final map = UserModel(uid: 'u', profileImage: 'https://x/a.png').toMap();
      expect(map['photoURL'], 'https://x/a.png');
    });
  });

  group('UserModel round-trip', () {
    test('survives toMap -> fromMap with the avatar intact', () {
      // The write key is photoURL while the field is profileImage; an
      // asymmetry here silently drops the user's avatar.
      final original = UserModel(
        uid: 'u',
        firstName: 'Ada',
        lastName: 'Lovelace',
        email: 'ada@example.com',
        phone: '123',
        profileImage: 'https://x/a.png',
        currentBalance: 1234.5,
        age: 36,
        dob: Timestamp.fromDate(DateTime(1990, 1, 1)),
      );
      final back = UserModel.fromMap('u', original.toMap());
      expect(back.firstName, 'Ada');
      expect(back.lastName, 'Lovelace');
      expect(back.email, 'ada@example.com');
      expect(back.phone, '123');
      expect(back.profileImage, 'https://x/a.png');
      expect(back.currentBalance, 1234.5);
      expect(back.dob?.toDate(), DateTime(1990, 1, 1));
    });
  });
}
