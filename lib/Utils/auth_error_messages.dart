import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Maps a [FirebaseAuthException] to copy that is safe to show a user.
///
/// The raw `e.message` is a backend string that (a) can leak internal detail
/// and (b) is not actionable ("The supplied auth credential is incorrect,
/// malformed or has expired."). Callers used to fall back to `e.message`, so a
/// plain wrong password surfaced that sentence verbatim in the release build.
///
/// Modern Firebase Auth collapses `user-not-found` + `wrong-password` into the
/// single `invalid-credential` code to avoid account enumeration, so both the
/// legacy and the unified codes are handled. Unrecognised codes get a generic
/// message; the real code/message is written to the logs for diagnosis.
String friendlyAuthError(FirebaseAuthException e) {
  switch (e.code) {
    case 'user-not-found':
      return 'No user found with this email.';
    case 'wrong-password':
    case 'invalid-credential':
    case 'invalid-login-credentials':
      return 'Incorrect email or password.';
    case 'invalid-email':
      return 'The email address is invalid.';
    case 'user-disabled':
      return 'This user account has been disabled.';
    case 'email-already-in-use':
      return 'An account already exists with this email.';
    case 'weak-password':
      return 'The password is too weak.';
    case 'too-many-requests':
      return 'Too many attempts. Please try again later.';
    case 'operation-not-allowed':
      return 'Operation not allowed. Please contact support.';
    case 'network-request-failed':
      return 'Network error. Please check your connection.';
    case 'credential-already-in-use':
      return 'This email is already associated with another account.';
    default:
      debugPrint('Unhandled auth error [${e.code}]: ${e.message}');
      return 'Authentication failed. Please try again.';
  }
}
