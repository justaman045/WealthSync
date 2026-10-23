import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Config/app_strings.dart';
import 'package:money_control/Screens/subscription_screen.dart';

class ProLockWidget extends StatelessWidget {
  final String title;
  final String description;

  const ProLockWidget({
    super.key,
    this.title = "Pro Feature",
    this.description = "Upgrade to Pro to unlock this feature.",
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Get.isDarkMode;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 80.sp, color: AppColors.primary),
            SizedBox(height: 24.h),
            Text(
              title,
              style: AppType.headlineSmall(isDark ? Colors.white : AppColors.lightTextPrimary),
            ),
            SizedBox(height: 12.h),
            Text(
              description,
              textAlign: TextAlign.center,
              style: AppType.bodyLarge(isDark ? Colors.white70 : AppColors.lightTextSecondary),
            ),
            SizedBox(height: 32.h),
            ElevatedButton(
              onPressed: () {
                Get.to(() => const SubscriptionScreen());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                AppStrings.upgradeToPro,
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
