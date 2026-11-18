import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted opt-in/out for the emergency fund feature.
///
/// Defaults to enabled (opt-out). Reset on sign-out so a shared device does not
/// leak the preference to the next account. Mirrors [SavingsSettings].
class EmergencyFundSettings {
  EmergencyFundSettings._();

  static const String enabledKey = 'emergency_fund_enabled';

  /// Live enabled state, observed by the eligibility check and settings UI.
  static final RxBool enabled = true.obs;

  /// Loads the persisted value into [enabled]; safe to call repeatedly.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    enabled.value = prefs.getBool(enabledKey) ?? true;
  }

  /// Persists the new value and updates [enabled].
  static Future<void> setEnabled(bool value) async {
    enabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledKey, value);
  }

  /// Clears the persisted + in-memory value (call on signOut).
  static Future<void> reset() async {
    enabled.value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(enabledKey);
  }
}
