import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:money_control/Components/colors.dart';

class CAnimatedWidget extends StatelessWidget {
  const CAnimatedWidget({
    super.key,
    this.title,
    this.style,
    this.textAlign,
    this.image,
  });

  final String? title;
  final TextStyle? style;
  final TextAlign? textAlign;
  final String? image;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: image != null
          ? Image.asset(image!, key: ValueKey(image), height: 250.h)
          : title != null
              ? Text(
                  title!,
                  key: ValueKey(title),
                  style: style ?? AppType.bodyLarge(Colors.white70),
                  textAlign: textAlign ?? TextAlign.left,
                )
              : const SizedBox.shrink(),
    );
  }
}
