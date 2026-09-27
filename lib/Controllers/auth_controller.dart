import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:money_control/main.dart';
import 'package:money_control/Screens/main_shell.dart';
import 'package:money_control/Screens/splashscreen.dart';

import 'package:money_control/Services/error_handler.dart';
import 'package:money_control/Services/referral_service.dart';
import 'package:money_control/Services/sms_service.dart';
import 'package:money_control/Services/recurring_service.dart';
import 'package:money_control/Services/cache_service.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Controllers/profile_controller.dart';
import 'package:money_control/Controllers/analytics_controller.dart';
import 'package:money_control/Controllers/budget_controller.dart';
import 'package:money_control/Controllers/goals_controller.dart';
import 'package:money_control/Controllers/loan_controller.dart';
import 'package:money_control/Controllers/challenges_controller.dart';
import 'package:money_control/Controllers/lent_money_controller.dart';
import 'package:money_control/Controllers/recurring_payment_controller.dart';
import 'package:money_control/Controllers/audit_controller.dart';
import 'package:money_control/Controllers/subscription_controller.dart';

class AuthController extends GetxController {
  static AuthController get to => Get.find();

  /// True while an email signup is completing its authenticated setup work.
  ///
  /// `createUserWithEmailAndPassword` signs the new account in immediately,
  /// which fires the auth-state stream. `main.dart`'s `_handleAuthChange` sees
  /// an unverified account and signs it straight back out — while the signup
  /// screen is still calling `updateDisplayName`, `sendEmailVerification` and
  /// the `users/{email}` Firestore write on that now-dead session. The signup
  /// flow sets this flag so the app's teardown does not race it, then clears
  /// it and performs its own `signOut()` once the setup work is done.
  static bool signupInProgress = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  var isLoading = false.obs;
  var errorMessage = ''.obs;

  Future<void> loginWithEmail(String email, String password) async {
    if (isLoading.value) return;
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = credential.user;
      if (user == null) throw Exception('User not found');

      if (!user.emailVerified) {
        await user.sendEmailVerification();
        await _auth.signOut();
        errorMessage.value =
            'Please verify your email. A verification link has been sent.';
        isLoading.value = false;
        return;
      }

      await _updateUserData(user, 'email');

      Get.offAll(() => const MainShell());
    } on FirebaseAuthException catch (e) {
      errorMessage.value = _getFriendlyErrorMessage(e);
    } catch (e) {
      // Credentials were accepted, so the user IS signed in — but the profile
      // write or referral-code bootstrap failed. Leaving them here is the worst
      // outcome: the auth stream has already moved the app forward while this
      // screen shows "unexpected error", and the user is stuck signed in with no
      // way to retry. Sign them back out so the state is consistent and they
      // can just try again.
      debugPrint('Post-login setup failed, signing out: $e');
      try {
        await _auth.signOut();
      } catch (signOutError) {
        debugPrint('Sign out after failed login: $signOutError');
      }
      errorMessage.value =
          'Could not finish setting up your account. Please try again.';
      ErrorHandler.showError(errorMessage.value);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loginWithGoogle() async {
    if (isLoading.value) return;
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the picker
        isLoading.value = false;
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        await _updateUserData(user, 'google');
        Get.offAll(() => const MainShell());
      }
    } on FirebaseAuthException catch (e) {
      errorMessage.value = _getFriendlyErrorMessage(e);
      ErrorHandler.showError(errorMessage.value);
    } catch (e) {
      debugPrint("Google Sign In Error: $e");
      errorMessage.value = 'Google Sign-In failed. Please try again.';
      ErrorHandler.showError(errorMessage.value);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _updateUserData(User user, String provider) async {
    await _firestore.collection('users').doc(user.email).set({
      'email': user.email,
      'provider': provider,
      'lastLogin': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await ReferralService.ensureReferralCode();
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      // Tearing down user-scoped state while the session is still live would
      // delete the controllers the *current* session is still using and leave
      // the app on an authenticated screen with nothing behind it. Abort
      // instead and report it.
      debugPrint('Firebase signOut error: $e');
      final message = 'Sign out failed. Please try again.';
      errorMessage.value = message;
      ErrorHandler.showError(message);
      isLoading.value = false;
      return;
    }
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Google signOut error: $e');
    }
    _disposeUserScopedState();
    // Reset to the dark-first default so the next user does not inherit the
    // previous user's preference; resubscribe() also cancels their listener.
    if (Get.isRegistered<ThemeController>()) {
      final theme = Get.find<ThemeController>();
      theme.resubscribe();
      theme.currentTheme.value = ThemeMode.dark;
      Get.changeThemeMode(ThemeMode.dark);
    }
    // Re-arm the auth listener so the next login triggers a fresh
    // subscription status check (cancels the old user's Firestore listener).
    if (Get.isRegistered<SubscriptionController>()) {
      SubscriptionController.to.checkSubscriptionStatus();
    }
    Get.offAll(() => const AnimatedSplashScreen());
  }

  /// Deletes all user-scoped controllers and clears user-scoped caches so a
  /// later login can never reuse the previous account's in-memory state.
  ///
  /// Shared by the explicit sign-out path here AND by `main.dart`'s
  /// `_handleAuthChange` teardown. The two lists used to be maintained by
  /// hand and had already drifted: only this one included `AuditController`,
  /// so a sign-out triggered by the auth stream leaked the previous account's
  /// audit state into the next session. One list, one owner.
  static Future<void> disposeUserScopedState() async {
    if (Get.isRegistered<TransactionController>()) {
      Get.delete<TransactionController>(force: true);
    }
    if (Get.isRegistered<ProfileController>()) {
      Get.delete<ProfileController>(force: true);
    }
    if (Get.isRegistered<AnalyticsController>()) {
      Get.delete<AnalyticsController>(force: true);
    }
    if (Get.isRegistered<BudgetController>()) {
      Get.delete<BudgetController>(force: true);
    }
    if (Get.isRegistered<GoalsController>()) {
      Get.delete<GoalsController>(force: true);
    }
    if (Get.isRegistered<LoanController>()) {
      Get.delete<LoanController>(force: true);
    }
    if (Get.isRegistered<ChallengesController>()) {
      Get.delete<ChallengesController>(force: true);
    }
    if (Get.isRegistered<LentMoneyController>()) {
      Get.delete<LentMoneyController>(force: true);
    }
    if (Get.isRegistered<RecurringPaymentController>()) {
      Get.delete<RecurringPaymentController>(force: true);
    }
    if (Get.isRegistered<AuditController>()) {
      Get.delete<AuditController>(force: true);
    }
    SmsService.resetCache();
    RecurringService.resetCache();
    // Awaited: an unawaited clear could land AFTER a fast re-login had already
    // written the new account's cache, silently wiping it.
    await LocalCacheService.clearAll();
  }

  void _disposeUserScopedState() => unawaited(disposeUserScopedState());

  String _getFriendlyErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Operation not allowed. Please contact support.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'credential-already-in-use':
        return 'This email is already associated with another account.';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }
}
