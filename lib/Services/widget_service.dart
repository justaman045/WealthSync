import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:money_control/Platform/widget_platform.dart';
import 'package:money_control/Services/feature_flag_service.dart';

class WidgetService {
  static const String _appGroupId = 'group.app.vercel.justaman045.money_control';
  static const String _androidWidgetName = 'MoneyControlWidget';

  static Future<void> updateBalance(
    double balance,
    String currencySymbol, {
    bool masked = false,
  }) async {
    if (kIsWeb) return;
    // Kill-switch: a `hidden` home_widget flag halts foreground balance pushes
    // too. The background worker gates its own push at the caller (this
    // isolate has no GetX, so the guard is skipped there).
    if (Get.isRegistered<FeatureFlagService>() &&
        FeatureFlagService.to.isHidden('home_widget')) {
      return;
    }
    try {
      // Privacy mode must never leak the live balance onto the OS widget.
      final formatted =
          masked ? '••••' : '$currencySymbol${balance.toStringAsFixed(2)}';
      await HomeWidget.saveWidgetData<String>('mc_balance', formatted);
      await HomeWidget.updateWidget(androidName: _androidWidgetName);
    } catch (e) {
      debugPrint('Widget update error: $e');
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
