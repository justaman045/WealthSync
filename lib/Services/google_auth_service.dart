import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// The app's single Google Sign-In client.
///
/// This is a service rather than a field on each screen for three reasons, all
/// of which were real defects in the previous per-screen instances:
///
/// 1. **One client, one cache.** `GoogleSignIn` stores the signed-in account in
///    a per-instance `_currentUser`, and `signIn()` is dispatched internally
///    with `canSkipCall: true`. A second instance therefore holds a second,
///    independent idea of who is signed in, and the explicit logout only cleared
///    one of them.
/// 2. **`signOut()` before `signIn()` is what shows the account chooser.** With
///    `_currentUser` set, `signIn()` returns that same account and never calls
///    the platform at all (Android). On web the client re-authenticates the
///    remembered user with `prompt: ''` + `login_hint` instead of
///    `prompt: 'select_account'`. Either way the app looked like it always
///    signed in the first Google account. Clearing the cache first restores the
///    picker on every explicit tap, on both platforms.
/// 3. **Credential construction lives in one place**, so login and sign-up
///    cannot drift apart in how they exchange tokens.
class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleAuthService instance = GoogleAuthService._();

  final GoogleSignIn _client = GoogleSignIn(scopes: const ['email']);

  /// Runs the Google picker and converts the result into a Firebase credential.
  ///
  /// Returns `null` when the user cancels — callers treat that as a no-op, not
  /// an error. Throws only when the platform reports a genuine failure (no Play
  /// Services, network error), which callers surface as a sign-in error.
  Future<AuthCredential?> obtainCredential() async {
    // Force the account picker; see the class comment. Must happen inside the
    // same instance that calls `signIn()`, or its cache is left untouched.
    await signOut();

    final GoogleSignInAccount? account = await _client.signIn();
    if (account == null) return null; // user cancelled the picker

    final GoogleSignInAuthentication authentication =
        await account.authentication;
    return GoogleAuthProvider.credential(
      accessToken: authentication.accessToken,
      idToken: authentication.idToken,
    );
  }

  /// Clears the local Google session.
  ///
  /// Best-effort on purpose: a device without Play Services, or one that never
  /// signed in, can throw here, and callers are either about to start a fresh
  /// sign-in anyway or have already ended the Firebase session. A failure is
  /// logged rather than thrown so logout can never be blocked by it.
  Future<void> signOut() async {
    try {
      await _client.signOut();
    } catch (e) {
      log('GoogleAuthService.signOut: $e');
    }
  }
}
