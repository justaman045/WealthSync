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

class PrivacyBlur extends StatelessWidget {
  final Widget child;
  final bool enabled;
  final double sigma;

  const PrivacyBlur({
    super.key,
    required this.child,
    this.enabled = true,
    this.sigma = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<PrivacyController>()
        ? Get.find<PrivacyController>()
        : null;

    return Obx(() {
      if (controller == null || !controller.isPrivacyMode.value || !enabled) {
        return child;
      }

      // Instead of ImageFilter.blur which can be expensive or glitchy on some text,
      // we can use a simpler replacement strategy or a blur shader.
      // For "Ultra-Premium", a nice star replacement or shatter effect is cool,
      // but blur gives a "hidden" vibe.
      // However, wrapping text in ImageFiltered can cause layout issues.
      // A common pattern is to show "••••" or similar.
      // But the user asked to "blur balances".
      // Let's use a ShaderMask or simple opacity switch.

      return ShaderMask(
        shaderCallback: (bounds) {
          return const LinearGradient(
            colors: [Colors.grey, Colors.grey],
          ).createShader(bounds);
        },
        blendMode: BlendMode.srcATop,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Opacity(
            opacity: 0,
            child: child,
          ),
        ),
      );
    });
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
