import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:money_control/Utils/responsive.dart';

/// Pairs two form-field widgets side-by-side on landscape tablets,
/// and stacks them vertically otherwise.
class ResponsiveFormRow extends StatelessWidget {
  final Widget left;
  final Widget right;

  const ResponsiveFormRow({
    super.key,
    required this.left,
    required this.right,
  });

  @override
  Widget build(BuildContext context) {
    if (Responsive.isWideForm(context)) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          SizedBox(width: 16.w),
          Expanded(child: right),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [left, right],
    );
  }
}
