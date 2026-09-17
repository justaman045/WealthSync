import 'package:flutter/services.dart';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:money_control/Platform/biometric_platform.dart';
import 'package:money_control/Services/feature_flag_service.dart';

class BiometricService extends GetxController {
  final LocalAuthentication? auth = kIsWeb ? null : LocalAuthentication();
  RxBool isBiometricEnabled = false.obs;
  RxBool isAuthenticated = false.obs;

  /// Effective lock state: the user's preference AND the feature not being
  /// disabled by an admin kill-switch. Reads the RxBool so Obx call sites
  /// stay reactive to both the toggle and the flag.
  bool get lockActive =>
      isBiometricEnabled.value &&
      !FeatureFlagService.to.isHidden('biometric_app_lock');

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
    // No local-auth backend (web, or platform without the plugin): auto-unlock
    // instead of permanently locking the user out of the app.
    if (kIsWeb || auth == null) {
      _fallbackUnlock();
      return true;
    }
    try {
      final bool canAuthenticateWithBiometrics = await auth!.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await auth!.isDeviceSupported();

      if (!canAuthenticate) {
        // Device dropped biometric/PIN support since the pref was set.
        // Auto-unlock (persisted off) so the app stays reachable; a purely
        // device-initiated failure must not be a permanent lockout.
        _fallbackUnlock();
        return true;
      }

      final bool didAuthenticate = await auth!.authenticate(
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

  /// Unlocks the app when local auth is unavailable, and persists the pref
  /// back off so the Settings toggle reflects reality on the next launch.
  Future<void> _fallbackUnlock() async {
    isAuthenticated.value = true;
    isBiometricEnabled.value = false;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('biometric_enabled') ?? false) {
      await prefs.setBool('biometric_enabled', false);
    }
  }

  Future<void> checkBiometricOnLaunch() async {
    await _loadSettings();
    if (lockActive) {
      isAuthenticated.value = false;
      // Authentication result is handled by the UI overlay (lock screen widget in RootApp).
      // Do not pop the navigator — the user can retry via the lock screen.
      await authenticate();
    } else {
      isAuthenticated.value = true;
    }
  }
}
