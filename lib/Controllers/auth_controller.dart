import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:money_control/Screens/homescreen.dart';

import 'package:money_control/Services/error_handler.dart';

class AuthController extends GetxController {
  static AuthController get to => Get.find();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  var isLoading = false.obs;
  var errorMessage = ''.obs;

  Future<void> loginWithEmail(String email, String password) async {
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

      Get.offAll(() => const BankingHomeScreen());
    } on FirebaseAuthException catch (e) {
      errorMessage.value = _getFriendlyErrorMessage(e);
    } catch (e) {
      errorMessage.value = 'Unexpected error occurred';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loginWithGoogle() async {
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
        Get.offAll(() => const BankingHomeScreen());
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
  }

  Future<void> logout() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

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
