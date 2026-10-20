import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Utils/auth_gated_listener.dart';

/// A stand-in for `FirebaseAuth.instance.authStateChanges()` so the gate can be
/// driven without Firebase.
class _FakeAuth {
  final _controller = StreamController<User?>.broadcast();
  Stream<User?> get stream => _controller.stream;
  void emit(User? user) => _controller.add(user);
  Future<void> close() => _controller.close();
}

/// Minimal [User] stub — only identity is ever read by the gate.
class _FakeUser implements User {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  String get uid => 'test-uid';
}

void main() {
  // AuthGatedListener reads FirebaseAuth.instance directly, so these tests only
  // exercise the parts that don't need a real stream: construction, teardown and
  // the no-op paths. The behavioural guarantee that matters (never subscribing
  // while unauthenticated) is asserted through the fake-auth harness below.
  group('AuthGatedListener', () {
    test('is inactive before start()', () {
      final gate = AuthGatedListener<void>(label: 'test');
      expect(gate.isActive, isFalse);
      expect(gate.isSubscribed, isFalse);
    });

    test('stop() is idempotent and leaves the gate inactive', () {
      final gate = AuthGatedListener<void>(label: 'test');
      gate.stop();
      gate.stop();
      expect(gate.isActive, isFalse);
      expect(gate.isSubscribed, isFalse);
    });

    test('pause() on an idle gate is safe', () {
      final gate = AuthGatedListener<void>(label: 'test');
      gate.pause();
      expect(gate.isActive, isFalse);
    });
  });

  // The real contract: the factory must NOT be invoked until a user exists.
  // This mirrors the production bug — Phase-1 services subscribing before login
  // produced `PERMISSION_DENIED` on `app_config` (auth-only readable).
  group('AuthGatedListener gate contract', () {
    test('does not build the data stream before authentication', () async {
      final auth = _FakeAuth();
      var factoryCalls = 0;
      final gate = _TestableGate(auth.stream);

      gate.start(
        factory: () {
          factoryCalls++;
          return const Stream<int>.empty();
        },
        onData: (_) {},
      );

      // No user yet — the factory must not have run.
      await Future<void>.delayed(Duration.zero);
      expect(factoryCalls, 0, reason: 'must not subscribe while unauthenticated');

      // A null emission (signed out) still must not subscribe.
      auth.emit(null);
      await Future<void>.delayed(Duration.zero);
      expect(factoryCalls, 0);

      // Now signed in — exactly one subscription.
      auth.emit(_FakeUser());
      await Future<void>.delayed(Duration.zero);
      expect(factoryCalls, 1);

      // Additional auth emissions must not re-subscribe.
      auth.emit(_FakeUser());
      await Future<void>.delayed(Duration.zero);
      expect(factoryCalls, 1, reason: 'auth churn must not leak listeners');

      gate.stop();
      await auth.close();
    });

    test('re-subscribes after sign-out then sign-in', () async {
      final auth = _FakeAuth();
      var factoryCalls = 0;
      final gate = _TestableGate(auth.stream);

      gate.start(
        factory: () {
          factoryCalls++;
          return const Stream<int>.empty();
        },
        onData: (_) {},
      );

      auth.emit(_FakeUser());
      await Future<void>.delayed(Duration.zero);
      expect(factoryCalls, 1);

      // Sign out tears the data listener down (the token is gone, so a live
      // listener would start erroring again)...
      auth.emit(null);
      await Future<void>.delayed(Duration.zero);
      expect(gate.isSubscribed, isFalse);

      // ...and signing back in re-establishes it.
      auth.emit(_FakeUser());
      await Future<void>.delayed(Duration.zero);
      expect(factoryCalls, 2);

      gate.stop();
      await auth.close();
    });

    test('forwards data and errors to the callbacks', () async {
      final auth = _FakeAuth();
      final received = <int>[];
      final errors = <Object>[];
      final gate = _TestableGate(auth.stream);

      gate.start(
        factory: () async* {
          yield 1;
          yield 2;
          throw StateError('boom');
        },
        onData: received.add,
        onError: errors.add,
      );

      auth.emit(_FakeUser());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(received, [1, 2]);
      expect(errors, hasLength(1));
      expect(errors.first, isA<StateError>());

      gate.stop();
      await auth.close();
    });

    test('a throwing factory does not crash the gate', () async {
      final auth = _FakeAuth();
      final gate = _TestableGate(auth.stream);

      gate.start(
        factory: () => throw StateError('no firestore'),
        onData: (_) {},
      );

      auth.emit(_FakeUser());
      await Future<void>.delayed(Duration.zero); // must not throw

      expect(gate.isSubscribed, isFalse);
      gate.stop();
      await auth.close();
    });
  });
}

/// Drives [AuthGatedListener] from an injected auth stream instead of the real
/// `FirebaseAuth.instance`, so the gate contract is testable without Firebase.
class _TestableGate extends AuthGatedListener<int> {
  _TestableGate(this._authStream) : super(label: 'testable');

  final Stream<User?> _authStream;

  @override
  Stream<User?> authStream() => _authStream;
}
