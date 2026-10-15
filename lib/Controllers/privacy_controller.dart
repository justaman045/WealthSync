import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:money_control/Services/feature_flag_service.dart';

class PrivacyController extends GetxController {
  static const String _prefKey = 'privacy_mode_enabled';
  RxBool isPrivacyMode = false.obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    isPrivacyMode.value = prefs.getBool(_prefKey) ?? false;
  }

  Future<void> togglePrivacy() async {
    isPrivacyMode.value = !isPrivacyMode.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, isPrivacyMode.value);
  }

  /// Flag-aware toggle: no-ops when an admin has hidden the feature, so the
  /// balance-card tap and the settings switch can never re-enable masking the
  /// instant `privacy_mode` is `hidden`.
  void toggle() {
    if (FeatureFlagService.to.isHidden('privacy_mode')) return;
    togglePrivacy();
  }
}

/// A simplified widget to wrap Text that needs to be hidden
class PrivacyText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final String mask;

  const PrivacyText(this.text, {super.key, this.style, this.mask = "••••"});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<PrivacyController>()
        ? Get.find<PrivacyController>()
        : null;
    return Obx(() {
      return Text(controller != null && controller.isPrivacyMode.value ? mask : text, style: style);
    });
  }
}
