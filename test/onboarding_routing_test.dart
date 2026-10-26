import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Services/onboarding_status.dart';

/// Guards the one routing decision every auth path goes through.
///
/// Both login paths used to hardcode `MainShell` and sign-up hardcoded
/// `OnboardingScreen`. Neither matched the root widget, which decides from the
/// `users/{email}.is_onboarded` flag — so a new account skipped setup and then
/// met it on the next cold start, while an existing account tapping "Sign up
/// with Google" was sent through setup again, which merge-writes
/// `monthly_budget` to 0. The destination is now a pure function of that one
/// check, and this test asserts both the mapping and that no screen routes
/// around it.
void main() {
  group('postAuthDestination', () {
    test('an account that still needs setup goes to onboarding', () {
      expect(
        postAuthDestination(needsOnboarding: true),
        PostAuthDestination.onboarding,
      );
    });

    test('an onboarded account goes straight home', () {
      expect(
        postAuthDestination(needsOnboarding: false),
        PostAuthDestination.home,
      );
    });
  });

  group('the onboarding check is web-safe', () {
    test('the kIsWeb branch returns before the Firestore read', () {
      final source = File(
        'lib/Services/onboarding_status.dart',
      ).readAsStringSync();
      final webBranch = source.indexOf('if (kIsWeb)');
      final firestoreRead = source.indexOf(".collection('users')");
      expect(webBranch, isNonNegative);
      expect(firestoreRead, isNonNegative);
      expect(
        webBranch,
        lessThan(firestoreRead),
        reason: 'A Firestore .get() on web re-triggers the JS SDK b815 '
            'assertion; the pref-only branch must come first.',
      );
      expect(
        source,
        contains('is_onboarded_email'),
        reason: 'The pref must stay stamped per account — it is device-wide.',
      );
    });
  });

  group('every auth path uses the shared decision', () {
    test('login routes through routeAfterSignIn', () {
      final source = File(
        'lib/Controllers/auth_controller.dart',
      ).readAsStringSync();
      expect(
        RegExp(r'await routeAfterSignIn\(user\);').allMatches(source).length,
        2,
        reason: 'email login and Google login must both delegate.',
      );
      expect(
        source,
        isNot(contains('Get.offAll(() => const MainShell())')),
        reason: 'A hardcoded MainShell is how a new account skipped setup.',
      );
      expect(
        source,
        isNot(contains('Get.offAll(() => const OnboardingScreen())')),
        reason: 'Only routeAfterSignIn may pick the setup screen.',
      );
      expect(source, contains('postAuthDestination('));
    });

    test('Google sign-up routes through routeAfterSignIn', () {
      final source = File('lib/Screens/signup.dart').readAsStringSync();
      expect(source, contains('AuthController.to.routeAfterSignIn(user)'));
      expect(
        source,
        isNot(contains('Get.offAll(')),
        reason: 'Sign-up must not pick its own destination: an existing '
            'account tapping it was re-onboarded.',
      );
    });

    test('the root widget asks the same question', () {
      final source = File('lib/main.dart').readAsStringSync();
      expect(source, contains('OnboardingStatus.isOnboardedFor(email)'));
      expect(
        source,
        isNot(contains("'is_onboarded'")),
        reason: 'The check was extracted so the screens and the root cannot '
            'drift; a second copy of the flag logic in main.dart is how they '
            'diverged.',
      );
    });
  });
}
