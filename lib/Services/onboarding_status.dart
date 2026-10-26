import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where a completed sign-in must land.
enum PostAuthDestination { home, onboarding }

/// The single routing decision for every auth path.
///
/// The root widget in `main.dart` asks the same question of the same
/// [OnboardingStatus] check, so an explicit sign-in and a restored session can
/// never disagree about whether setup is still pending. Pure so the mapping is
/// testable without a widget tree (see `test/onboarding_routing_test.dart`).
PostAuthDestination postAuthDestination({required bool needsOnboarding}) =>
    needsOnboarding ? PostAuthDestination.onboarding : PostAuthDestination.home;

/// Whether [email] still needs onboarding.
///
/// `is_onboarded` lives in SharedPreferences, which is device-wide rather than
/// per-account, so a second person signing in on the same device used to
/// inherit it and be waved straight past setup. The pref is therefore stamped
/// with the email that owns it and is only trusted for that same email. A pref
/// with no stamp predates this and keeps the old behaviour, which is what lets
/// an existing install avoid being re-onboarded.
///
/// Lives here rather than in `main.dart` because the auth screens have to ask
/// the same question before choosing a destination.
class OnboardingStatus {
  OnboardingStatus._();

  static Future<bool> isOnboardedFor(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final owner = prefs.getString('is_onboarded_email');
    final prefIsOurs = owner == null || owner == email;
    bool prefValue() => prefIsOurs && (prefs.getBool('is_onboarded') ?? false);

    // On web, skip the Firestore .get() to avoid triggering the JS SDK
    // WatchChangeAggregator ca9/b815 assertion bug. Use SharedPreferences only.
    if (kIsWeb) {
      return prefValue();
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(email)
          .get();
      if (doc.exists && doc.data()?['is_onboarded'] == true) {
        await prefs.setBool('is_onboarded', true);
        await prefs.setString('is_onboarded_email', email);
        return true;
      }
    } catch (e) {
      debugPrint("Onboarding check failed: $e");
    }
    return prefValue();
  }
}
