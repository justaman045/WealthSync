import 'package:cloud_firestore/cloud_firestore.dart';

/// The `users/{email}` fields the Edit Profile form owns.
///
/// `dob` and `age` are emitted **only when a date of birth is known**. The form
/// owns those *fields* but not necessarily their values: onboarding can capture
/// an age without a stored `dob`, and the Wealth Builder's age gate
/// (`main_shell.dart` `_checkAgeGate`) refuses to open without one. The old save
/// wrote `age: null` (and `dob: null`) whenever the picker was empty, so simply
/// renaming yourself silently locked the Wealth Builder out. Omitting the keys
/// under `SetOptions(merge: true)` leaves whatever is stored untouched.
///
/// Pure so the key set is unit-testable without a widget tree.
Map<String, dynamic> buildProfileUpdate({
  required String firstName,
  required String lastName,
  required String phone,
  required String address,
  required String? gender,
  required DateTime? dob,
  required int? age,
}) {
  return {
    'firstName': firstName.trim(),
    'lastName': lastName.trim(),
    'phone': phone.trim(),
    'address': address.trim(),
    'gender': gender,
    if (dob != null) 'dob': Timestamp.fromDate(dob),
    if (dob != null) 'age': age,
  };
}
