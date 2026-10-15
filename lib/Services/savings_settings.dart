import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:money_control/Utils/wealth_math.dart';

/// SharedPreferences-backed savings target used by the AI Insights daily limit.
///
/// The rate is stored as a whole percentage (0–50). [percent] is a live
/// observable so the daily-limit card updates the moment the user changes the
/// target in Settings — the AI Insights page is kept alive across tab switches,
/// so it would otherwise not recompute until an app restart.
class SavingsSettings {
  SavingsSettings._();

  static const String rateKey = 'ai_savings_rate';
  static const int minPercent = 0;
  static const int maxPercent = 50;
  static final int defaultPercent = (kDefaultSavingsRate * 100).round();

  /// Live savings percentage (0–50), observed by the daily-limit card.
  static final RxInt percent = defaultPercent.obs;

  /// 0–1 fraction for [computeDailyLimit].
  static double get rate => percent.value / 100.0;

  /// Loads the persisted percentage into [percent]; safe to call repeatedly.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(rateKey);
    percent.value = (stored ?? defaultPercent).clamp(minPercent, maxPercent);
  }

  /// Clears the persisted + in-memory savings target (call on signOut).
  ///
  /// [rateKey] and the static [percent] observable are device-global, so without
  /// this the next account inherits the previous account's savings rate.
  static Future<void> reset() async {
    percent.value = defaultPercent;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(rateKey);
  }

  static Future<void> setPercent(int value) async {
    final clamped = value.clamp(minPercent, maxPercent);
    percent.value = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(rateKey, clamped);
  }
}
