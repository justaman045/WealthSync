import 'package:money_control/Utils/wealth_math.dart';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';


/// SharedPreferences-backed income configuration used by the AI Insights
/// daily limit.
///
/// Precedence: if [mode] == [IncomeMode.manual] and [manualMonthly] > 0, the
/// manual value is used. Otherwise the selected auto mode is used. [manualMonthly]
/// is treated as "not set" when <= 0.
class IncomeSettings {
  IncomeSettings._();

  static const String modeKey = 'income_mode';
  static const String manualKey = 'income_manual_monthly'; // stored as double

  /// Whether the user has seen the income-mode chooser. Until they have, the
  /// AI Insights screen opens it once: the daily limit is otherwise derived
  /// from a mode the user never picked or had explained.
  static const String confirmedKey = 'income_mode_confirmed';

  static final Rx<IncomeMode> mode = IncomeMode.autoBlend.obs;
  static final RxDouble manualMonthly = 0.0.obs; // 0.0 = not set
  static final RxBool confirmed = false.obs;

  static String _modeToString(IncomeMode m) {
    switch (m) {
      case IncomeMode.manual:
        return 'manual';
      case IncomeMode.autoBlend:
        return 'auto_blend';
      case IncomeMode.autoSalaryWindow:
        return 'auto_salary_window';
    }
  }

  static IncomeMode _modeFromString(String? s) {
    switch (s) {
      case 'manual':
        return IncomeMode.manual;
      case 'auto_salary_window':
        return IncomeMode.autoSalaryWindow;
      case 'auto_blend':
      default:
        return IncomeMode.autoBlend;
    }
  }

  /// Loads the persisted income settings into [mode] and [manualMonthly].
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedMode = prefs.getString(modeKey);
    mode.value = _modeFromString(storedMode);

    final storedManual = prefs.getDouble(manualKey);
    if (storedManual == null || storedManual <= 0) {
      manualMonthly.value = 0.0;
    } else {
      manualMonthly.value = storedManual;
    }

    confirmed.value = prefs.getBool(confirmedKey) ?? false;
  }

  /// Clears the persisted + in-memory income configuration (call on signOut).
  ///
  /// The prefs keys and the static [mode]/[manualMonthly] observables are
  /// device-global, so without this a shared device would leave the previous
  /// account's manual monthly income applied to the next account's AI limit.
  static Future<void> reset() async {
    mode.value = IncomeMode.autoBlend;
    manualMonthly.value = 0.0;
    confirmed.value = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(modeKey);
    await prefs.remove(manualKey);
    await prefs.remove(confirmedKey);
  }

  /// Records that the user has been shown (and answered) the mode chooser, so
  /// it is not reopened on every visit.
  static Future<void> markConfirmed() async {
    confirmed.value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(confirmedKey, true);
  }

  static Future<void> setMode(IncomeMode m) async {
    mode.value = m;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(modeKey, _modeToString(m));
  }

  /// Sets the manual monthly income. Values <= 0 are treated as "not set".
  static Future<void> setManual(double v) async {
    final clamped = v;
    if (clamped <= 0 || !clamped.isFinite) {
      manualMonthly.value = 0.0;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(manualKey, 0.0);
      return;
    }
    manualMonthly.value = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(manualKey, clamped);
  }
}