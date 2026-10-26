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
Map<String, Object?> googleSignupProfileFields({
  required String? email,
  required String? displayName,
  required String? photoUrl,
  required bool isNewUser,
  required Object createdAt,
  required Object lastLogin,
}) {
  return <String, Object?>{
    'email': email,
    'name': displayName ?? 'Google User',
    'photoUrl': photoUrl,
    'lastLogin': lastLogin,
    if (isNewUser) ...<String, Object?>{
      'provider': 'google',
      'createdAt': createdAt,
    },
  };
}
