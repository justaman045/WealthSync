import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/main.dart';

/// Snackbars via the global [rootScaffoldMessengerKey] — never mix
/// GetX snackbars with Flutter dialogs/navigation (crashes the app).
class ErrorHandler {
  static void showError(
    String message, {
    String title = "Error",
    SnackBarAction? action,
    Duration? duration,
  }) {
    _show(
      message,
      title: title,
      icon: Icons.error_outline,
      backgroundColor: AppColors.error,
      action: action,
      duration: duration,
    );
  }

  static void showSuccess(String message, {String title = "Success"}) {
    _show(
      message,
      title: title,
      icon: Icons.check_circle_outline,
      backgroundColor: AppColors.success,
      duration: const Duration(seconds: 2),
    );
  }

  static void showInfo(String message, {String title = "Info"}) {
    _show(
      message,
      title: title,
      icon: Icons.info_outline,
      backgroundColor: const Color(0xFFF57C00),
    );
  }

  static void _show(
    String message, {
    required String title,
    required IconData icon,
    required Color backgroundColor,
    SnackBarAction? action,
    Duration? duration,
  }) {
    final state = rootScaffoldMessengerKey.currentState;
    if (state == null) return;
    state.clearSnackBars();
    state.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20.sp),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                title == "Error" ? message : "$title: $message",
                style: TextStyle(color: Colors.white, fontSize: 14.sp),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16.w),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        duration: duration ?? const Duration(seconds: 3),
        dismissDirection: DismissDirection.horizontal,
        action: action,
      ),
    );
  }

  static void showNetworkError() {
    showError("Please check your internet connection.", title: "Network Error");
  }
}
