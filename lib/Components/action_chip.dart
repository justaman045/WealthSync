import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ActionCChip extends StatelessWidget {
  final Color color;
  final String label;
  final IconData icon;
  final Function onTap;
  const ActionCChip({super.key, required this.color, required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(),
        child: Container(
          height: 40.h,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18.sp),
              SizedBox(width: 6.w),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13.sp)),
            ],
          ),
        ),
      ),
    );
  }
}