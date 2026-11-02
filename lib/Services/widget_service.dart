import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:money_control/Platform/widget_platform.dart';
import 'package:money_control/Services/feature_flag_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WidgetService {
  static const String _appGroupId = 'group.app.vercel.justaman045.money_control';
  static const String _androidWidgetName = 'MoneyControlWidget';

  /// Whether the widget shows its `+ Add` shortcut. Stored in shared
  /// preferences (the app's source of truth) and mirrored into the widget's
  /// own data store, because the Android RemoteViews has to apply it without
  /// waking Flutter.
  static const String showQuickAddKey = 'widget_show_quick_add';

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

  /// The user's widget preferences, read back from the device.
  static Future<bool> showQuickAdd() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(showQuickAddKey) ?? true;
  }

  /// Persists the widget preferences and pushes them onto the OS widget.
  ///
  /// The preference is written first: the widget data update can fail (no
  /// widget placed, plugin unavailable) and the value must survive that, or
  /// the switch in settings would silently revert on the next launch.
  static Future<void> updateSettings({required bool showQuickAdd}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(showQuickAddKey, showQuickAdd);
    if (kIsWeb) return;
    if (Get.isRegistered<FeatureFlagService>() &&
        FeatureFlagService.to.isHidden('home_widget')) {
      return;
    }
    try {
      await HomeWidget.saveWidgetData<bool>('mc_show_quick_add', showQuickAdd);
      await HomeWidget.updateWidget(androidName: _androidWidgetName);
    } catch (e) {
      debugPrint('Widget settings update error: $e');
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
