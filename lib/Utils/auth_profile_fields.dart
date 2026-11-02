import 'package:money_control/Utils/display_name.dart';

/// Fields written to `users/{email}` from the Google sign-up screen.
///
/// "Sign up with Google" and "sign in with Google" are the same Firebase call:
/// tapping sign-up with an account that already exists simply signs it in. So
/// writing `createdAt` unconditionally rewrote an existing user's creation time,
/// and `provider: 'google'` re-labelled an email/password account.
///
/// `UserCredential.additionalUserInfo.isNewUser` is the only thing that
/// separates the two cases, so it is the only thing allowed to gate those keys.
/// Kept pure (no Firebase types) so the rule is unit-testable — see
/// `test/google_signup_profile_test.dart`.
///
/// `firstName`/`lastName` are derived from `displayName` for the same reason:
/// Google supplies one string, but the profile form edits the two parts
/// separately. Deriving them on every sign-in would overwrite a rename, so a
/// returning user keeps whatever the profile screen stored.
Map<String, Object?> googleSignupProfileFields({
  required String? email,
  required String? displayName,
  required String? photoUrl,
  required bool isNewUser,
  required Object createdAt,
  required Object lastLogin,
}) {
  final split = splitDisplayName(displayName);
  return <String, Object?>{
    'email': email,
    'name': displayName ?? 'Google User',
    'photoUrl': photoUrl,
    'lastLogin': lastLogin,
    if (isNewUser) ...<String, Object?>{
      'provider': 'google',
      'createdAt': createdAt,
      // Only write a part when the display name actually provided one, so a
      // nameless account is not labelled "Google User" / "".
      if (split.firstName.isNotEmpty) 'firstName': split.firstName,
      if (split.lastName.isNotEmpty) 'lastName': split.lastName,
    },
  };
}
