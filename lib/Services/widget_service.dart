import 'package:flutter/foundation.dart';
import 'package:money_control/Platform/widget_platform.dart';

class WidgetService {
  static const String _appGroupId = 'group.app.vercel.justaman045.money_control';
  static const String _androidWidgetName = 'MoneyControlWidget';

  static Future<void> updateBalance(double balance, String currencySymbol) async {
    if (kIsWeb) return;
    try {
      final formatted = '$currencySymbol${balance.toStringAsFixed(2)}';
      await HomeWidget.saveWidgetData<String>('mc_balance', formatted);
      await HomeWidget.updateWidget(androidName: _androidWidgetName);
    } catch (_) {
      // Widget update is best-effort — never crash the app
    }
  }

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
    } catch (e) {
      debugPrint("HomeWidget init error: $e");
    }
  }
}
