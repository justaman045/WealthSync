import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `AuthController.loginWithEmail` must reject blank credentials BEFORE it
/// reaches `signInWithEmailAndPassword`.
///
/// The native Firebase Auth bridge throws a raw
/// `IllegalArgumentException: Given String is empty or null` for a blank
/// email/password — NOT a `FirebaseAuthException`. Without an up-front guard
/// that exception falls through to the controller's generic `catch`, which
/// assumes the credentials were accepted, signs the (never-authenticated) user
/// back out, and reports the misleading "Could not finish setting up your
/// account". This shipped and was caught by running the release APK: tapping
/// "Sign In" on the empty form logged the raw exception and showed the wrong
/// message.
///
/// `flutter analyze` cannot see this and there is no way to unit-test a
/// controller that talks to `FirebaseAuth.instance` directly, so this is a
/// deliberate source scan (same rationale as `early_return_guard_test.dart`
/// and `signout_teardown_test.dart`).
String _extractFunctionBody(String source, String signature) {
  final start = source.indexOf(signature);
  if (start < 0) return '';
  final open = source.indexOf('{', start);
  if (open < 0) return '';
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final c = source[i];
    if (c == '{') {
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0) return source.substring(open, i + 1);
    }
  }
  return '';
}

void main() {
  test('loginWithEmail guards blank credentials before the sign-in call', () {
    final source =
        File('lib/Controllers/auth_controller.dart').readAsStringSync();
    final body = _extractFunctionBody(
      source,
      'Future<void> loginWithEmail(String email, String password)',
    );
    expect(body, isNotEmpty, reason: 'could not locate loginWithEmail');

    final guardIndex = body.indexOf('isEmpty');
    final callIndex = body.indexOf('signInWithEmailAndPassword');

    expect(
      guardIndex,
      isNot(-1),
      reason: 'loginWithEmail must check for blank email/password',
    );
    expect(
      callIndex,
      isNot(-1),
      reason: 'loginWithEmail should still call signInWithEmailAndPassword',
    );
    expect(
      guardIndex < callIndex,
      isTrue,
      reason: 'the blank-credential guard must run BEFORE the sign-in call, '
          'otherwise the raw IllegalArgumentException escapes to the generic '
          'catch and misreports a successful setup failure',
    );
  });
}
