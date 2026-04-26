import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PrivacyController extends GetxController {
  RxBool isPrivacyMode = false.obs;

  void togglePrivacy() {
    isPrivacyMode.value = !isPrivacyMode.value;
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
    final controller = Get.put(PrivacyController());

    return Obx(() {
      if (!controller.isPrivacyMode.value || !enabled) {
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
    final controller = Get.put(PrivacyController());
    return Obx(() {
      return Text(controller.isPrivacyMode.value ? mask : text, style: style);
    });
  }
}
