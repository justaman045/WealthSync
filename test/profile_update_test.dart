import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Utils/profile_update.dart';

void main() {
  Map<String, dynamic> update({DateTime? dob, int? age}) =>
      buildProfileUpdate(
        firstName: '  Ada ',
        lastName: ' Lovelace  ',
        phone: ' 1234567890 ',
        address: ' 1 Analytical Way ',
        gender: 'female',
        dob: dob,
        age: age,
      );

  test('trims the text fields and keeps the ones the form owns', () {
    final fields = update();
    expect(fields['firstName'], 'Ada');
    expect(fields['lastName'], 'Lovelace');
    expect(fields['phone'], '1234567890');
    expect(fields['address'], '1 Analytical Way');
    expect(fields['gender'], 'female');
  });

  test('an empty birth date never writes age/dob', () {
    // Regression: writing `age: null` here locked a user out of the Wealth
    // Builder's age gate (`main_shell.dart` `_checkAgeGate`) on any profile
    // edit, because merge+null clears the stored value.
    final fields = update();
    expect(fields.containsKey('age'), isFalse);
    expect(fields.containsKey('dob'), isFalse);
  });

  test('a birth date writes both dob (Timestamp) and age', () {
    final dob = DateTime(1990, 5, 17);
    final fields = update(dob: dob, age: 36);
    expect(fields['age'], 36);
    expect(fields['dob'], isA<Timestamp>());
    expect((fields['dob'] as Timestamp).toDate(), dob);
  });
}
