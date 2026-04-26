import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
          ? Image.asset(image!, key: ValueKey(image), height: 250.r)
          : Text(
              title!,
              key: ValueKey(title),
              style: style ?? TextStyle(color: Colors.white70, fontSize: 15.r),
              textAlign: textAlign ?? TextAlign.left,
            ),
    );
  }
}
