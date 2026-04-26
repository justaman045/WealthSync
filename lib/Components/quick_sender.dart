import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:money_control/Components/cateogary_initial_icon.dart';
import 'package:money_control/Components/methods.dart';
import 'package:money_control/Screens/add_transaction.dart';

class QuickSender extends StatelessWidget {
  final CategoryInitialsIcon asset;           // Image asset or URL
  final String name;            // Contact name
  final Color? textColor;
  final VoidCallback? onTap;   // Optional custom tap handler

  const QuickSender({
    required this.asset,
    required this.name,
    this.textColor,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap ??
              () {
            // Navigate to PaymentScreen without recipientId
            gotoPage(
              PaymentScreen(
                type: PaymentType.send,
                cateogary: name,
              ),
            );
          },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(18.r),
            ),
            clipBehavior: Clip.antiAlias,
            child: asset
          ),
          SizedBox(height: 8.h),
          Text(
            name,
            style: TextStyle(
              fontSize: 12.sp,
              color: textColor ?? scheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
