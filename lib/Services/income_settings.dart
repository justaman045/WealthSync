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

  static final Rx<IncomeMode> mode = IncomeMode.autoBlend.obs;
  static final RxDouble manualMonthly = 0.0.obs; // 0.0 = not set

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

  static String modeLabel([IncomeMode? m]) {
    switch (m ?? mode.value) {
      case IncomeMode.manual:
        return 'Manual';
      case IncomeMode.autoBlend:
        return 'Auto – Blend (3-month average)';
      case IncomeMode.autoSalaryWindow:
        return 'Auto – Salary window (current month first week or previous month last working day)';
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