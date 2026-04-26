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
        // Device not supported, assume authenticated or handle gracefully
        return true;
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
      final success = await authenticate();
      if (!success) {
        // If failed, close app or show full screen error?
        // For now, we will handle it in the UI (e.g. show a "Unlock" button overlay)
        SystemNavigator.pop(); // Close app if critical failure, or let specific UI handle it
      }
    } else {
      isAuthenticated.value = true;
    }
  }
}
