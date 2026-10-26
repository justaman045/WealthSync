import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Utils/auth_profile_fields.dart';

/// "Sign up with Google" is the same Firebase call as sign-in with Google:
/// tapping it with an account that already exists simply signs that account in.
/// The profile write used to be unconditional, so it rewrote an existing user's
/// `createdAt` and re-labelled their provider. Only `isNewUser` may gate those
/// two keys — asserted here on the pure builder rather than through a widget
/// tree that needs Firebase.
void main() {
  Map<String, Object?> build({required bool isNewUser}) {
    return googleSignupProfileFields(
      email: 'someone@example.com',
      displayName: 'Someone',
      photoUrl: 'https://example.com/p.png',
      isNewUser: isNewUser,
      createdAt: 'CREATED_AT',
      lastLogin: 'LAST_LOGIN',
    );
  }

  group('a genuinely new Google account', () {
    test('records the provider and the creation time', () {
      final fields = build(isNewUser: true);
      expect(fields['provider'], 'google');
      expect(fields['createdAt'], 'CREATED_AT');
    });

    test('still records the login identity', () {
      final fields = build(isNewUser: true);
      expect(fields['email'], 'someone@example.com');
      expect(fields['name'], 'Someone');
      expect(fields['photoUrl'], 'https://example.com/p.png');
      expect(fields['lastLogin'], 'LAST_LOGIN');
    });
  });

  group('an account that already exists', () {
    test('never rewrites createdAt', () {
      expect(build(isNewUser: false).containsKey('createdAt'), isFalse);
    });

    test('never rewrites the provider', () {
      expect(build(isNewUser: false).containsKey('provider'), isFalse);
    });

    test('still touches lastLogin, so the merge write is useful', () {
      expect(build(isNewUser: false)['lastLogin'], 'LAST_LOGIN');
    });
  });

  test('a missing display name falls back without dropping the write', () {
    final fields = googleSignupProfileFields(
      email: 'someone@example.com',
      displayName: null,
      photoUrl: null,
      isNewUser: true,
      createdAt: 'CREATED_AT',
      lastLogin: 'LAST_LOGIN',
    );
    expect(fields['name'], 'Google User');
  });
}
