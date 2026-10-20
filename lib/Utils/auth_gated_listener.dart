import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Subscribes to a Firestore stream once — but only while a user is signed in.
///
/// Phase-1 services are registered before login (`main.dart`), and `app_config`
/// is `allow read: if request.auth != null` (`firestore.rules`). Opening the
/// listener immediately therefore fires an unauthenticated read that Firestore
/// answers with `PERMISSION_DENIED`, which every cold start logged as
/// `using defaults (permission-denied)`. The services recovered on the next
/// emission, so this was noise rather than a bug — but it read like a failure
/// in every log.
///
/// This waits for the first authenticated emission before subscribing, so the
/// denied read never happens. Sign-in state is observed rather than read once,
/// because a fast cold start can deliver a restored session a frame later; and
/// the subscription is torn down on sign-out (the token is gone, so a live
/// listener would start failing again).
class AuthGatedListener<T> {
  AuthGatedListener({required this.label});

  /// Used only in debug diagnostics.
  final String label;

  /// The auth-state stream to observe. Overridable so tests can drive the gate
  /// without a real [FirebaseAuth] instance.
  @visibleForTesting
  Stream<User?> authStream() => FirebaseAuth.instance.authStateChanges();

  StreamSubscription<User?>? _authSub;
  StreamSubscription<T>? _dataSub;

  /// True while auth is being watched or a data listener is live.
  bool get isActive => _dataSub != null || _authSub != null;

  /// True once the data listener is attached (i.e. a user was signed in).
  bool get isSubscribed => _dataSub != null;

  /// Watches auth, then subscribes to [factory] once signed in and forwards
  /// every event to [onData], every error to [onError].
  ///
  /// [factory] is invoked *after* authentication, so the resulting
  /// `Query.snapshots()` is created with a valid token.
  void start({
    required Stream<T> Function() factory,
    required void Function(T event) onData,
    void Function(Object error)? onError,
  }) {
    stop();
    _authSub = authStream().listen((user) {
      if (user == null) {
        _dataSub?.cancel();
        _dataSub = null;
        return;
      }
      if (_dataSub != null) return;
      try {
        _dataSub = factory().listen(
          onData,
          onError: (Object e) {
            debugPrint('$label: listener error ($e)');
            onError?.call(e);
          },
        );
      } catch (e) {
        debugPrint('$label: subscribe failed ($e)');
      }
    }, onError: (Object e) {
      debugPrint('$label: auth state error ($e)');
    });
  }

  /// Cancels the data listener but keeps waiting for a future sign-in.
  void pause() {
    _dataSub?.cancel();
    _dataSub = null;
  }

  /// Cancels everything.
  void stop() {
    _dataSub?.cancel();
    _dataSub = null;
    _authSub?.cancel();
    _authSub = null;
  }
}
