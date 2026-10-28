import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Captures the authenticated session at the moment an async operation
/// starts and verifies it is still current before mutating state or caches.
/// Prevents cross-account cache contamination when a user signs out/signs
/// in quickly or a request from account A resolves after switching to B.
class SessionGuard {
  SessionGuard() {
    final user = FirebaseAuth.instance.currentUser;
    email = user?.email;
    uid = user?.uid;
  }

  String? email;
  String? uid;

  bool get isValid {
    final user = FirebaseAuth.instance.currentUser;
    if (email == null && uid == null) return user == null;
    if (user == null) return false;
    if (uid != null && user.uid == uid) return true;
    if (email != null && user.email == email) return true;
    return false;
  }

  void assertOrDiscard(void Function() action) {
    if (!isValid) {
      debugPrint('[SessionGuard] Discarding result for stale session');
      return;
    }
    action();
  }
}

mixin SessionGuardMixin {
  String? _sessionEmail;
  String? _sessionUid;

  void captureSession() {
    final user = FirebaseAuth.instance.currentUser;
    _sessionEmail = user?.email;
    _sessionUid = user?.uid;
  }

  bool isSessionCurrent() {
    final user = FirebaseAuth.instance.currentUser;
    if (_sessionEmail == null && _sessionUid == null) return user == null;
    if (user == null) return false;
    if (_sessionUid != null && user.uid == _sessionUid) return true;
    if (_sessionEmail != null && user.email == _sessionEmail) return true;
    return false;
  }
}
