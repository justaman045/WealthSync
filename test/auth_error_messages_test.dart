import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Utils/auth_error_messages.dart';

FirebaseAuthException _err(String code, {String? message}) =>
    FirebaseAuthException(code: code, message: message);

void main() {
  group('friendlyAuthError', () {
    test('maps the unified invalid-credential code to a friendly message', () {
      expect(
        friendlyAuthError(_err('invalid-credential',
            message:
                'The supplied auth credential is incorrect, malformed or has expired.')),
        'Incorrect email or password.',
      );
    });

    test('maps legacy wrong-password and user-not-found', () {
      expect(friendlyAuthError(_err('wrong-password')), isNotEmpty);
      expect(friendlyAuthError(_err('user-not-found')), isNotEmpty);
    });

    test('maps email-already-in-use for the signup path', () {
      expect(
        friendlyAuthError(_err('email-already-in-use')),
        'An account already exists with this email.',
      );
    });

    test('never leaks the raw backend message for unknown codes', () {
      const raw = 'Some internal backend detail that must not be shown';
      final out = friendlyAuthError(_err('some-new-code', message: raw));
      expect(out, isNot(contains(raw)));
      expect(out, 'Authentication failed. Please try again.');
    });
  });
}
