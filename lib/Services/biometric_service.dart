import 'package:flutter/services.dart';
import 'dart:developer';
import 'package:local_auth/local_auth.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService extends GetxController {
  final LocalAuthentication auth = LocalAuthentication();
  RxBool isBiometricEnabled = false.obs;
  RxBool isAuthenticated = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    isBiometricEnabled.value = prefs.getBool('biometric_enabled') ?? false;
  }

  Future<void> toggleBiometric(bool value) async {
    // If enabling, verify first
    if (value) {
      final success = await authenticate(
        reason: "Verify identity to enable biometric lock",
      );
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('biometric_enabled', true);
        isBiometricEnabled.value = true;
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', false);
      isBiometricEnabled.value = false;
    }
  }

  Future<bool> authenticate({
    String reason = 'Please authenticate to access Finance Control',
  }) async {
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) {
        return false;
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN/Pattern fallback
        ),
      );

      isAuthenticated.value = didAuthenticate;
      return didAuthenticate;
    } on PlatformException catch (e) {
      log("Biometric Error: $e");
      return false;
    }
  }

  Future<void> checkBiometricOnLaunch() async {
    await _loadSettings();
    if (isBiometricEnabled.value) {
      isAuthenticated.value = false;
      // Authentication result is handled by the UI overlay (lock screen widget in RootApp).
      // Do not pop the navigator — the user can retry via the lock screen.
      await authenticate();
    } else {
      isAuthenticated.value = true;
    }
  }
}
