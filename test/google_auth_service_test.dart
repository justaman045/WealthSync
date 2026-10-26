import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Pins the two properties that fixed "Google always signs in the same
/// account", plus the single-client rule that keeps them from drifting:
///
/// 1. There is exactly one `GoogleSignIn` instance in `lib/`.
/// 2. `obtainCredential()` calls `signOut()` before `signIn()`.
///
/// (2) is not cosmetic. `signIn()` dispatches with `canSkipCall: true`, so while
/// the client holds a cached account it returns that account without ever
/// calling the platform; on web the remembered credential makes Google skip the
/// chooser via `prompt: ''` + `login_hint`. Clearing first is the only thing
/// that makes an explicit "Sign in with Google" tap ask which account to use.
/// This is a source scan because both failure modes pass every behavioural test
/// (the suite has no real Google account to drive the system picker).
void main() {
  final serviceFile = File('lib/Services/google_auth_service.dart');
  final libDartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('exactly one GoogleSignIn client is constructed in lib/', () {
    final constructions = <String>[];
    for (final file in libDartFiles) {
      final count = RegExp(
        r'GoogleSignIn\(',
      ).allMatches(file.readAsStringSync()).length;
      if (count > 0) constructions.add('${file.path} x$count');
    }
    expect(
      constructions,
      ['lib/Services/google_auth_service.dart x1'],
      reason: 'A second instance has its own cached account and its own '
          'signOut(), so one flow keeps reusing an account the other cleared.',
    );
  });

  test('the picker is forced: signOut() runs before signIn()', () {
    final source = serviceFile.readAsStringSync();
    final signOutCall = source.indexOf('await signOut();');
    final signInCall = source.indexOf('_client.signIn()');
    expect(signOutCall, isNonNegative);
    expect(signInCall, isNonNegative);
    expect(
      signOutCall,
      lessThan(signInCall),
      reason: 'Clearing the cached account after signIn() would be a no-op: '
          'signIn() already returned it without showing the picker.',
    );
  });

  test('credentials are built in the service only', () {
    final withCredential = libDartFiles
        .where(
          (f) => f.readAsStringSync().contains('GoogleAuthProvider.credential'),
        )
        .map((f) => f.path)
        .toList();
    expect(withCredential, ['lib/Services/google_auth_service.dart']);
  });

  test('both auth screens go through the service', () {
    for (final path in [
      'lib/Controllers/auth_controller.dart',
      'lib/Screens/signup.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        contains('GoogleAuthService.instance'),
        reason: '$path must use the shared client.',
      );
      expect(
        source,
        isNot(contains('google_sign_in')),
        reason: '$path must not import the plugin directly.',
      );
    }
  });
}
