import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Controllers/privacy_controller.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Utils/responsive.dart';

/// Shows a live mock of the Android home-screen widget plus setup instructions.
/// Reachable from Settings → General → Appearance → Home Widget.
class HomeWidgetPreviewScreen extends StatefulWidget {
  const HomeWidgetPreviewScreen({super.key});

  @override
  State<HomeWidgetPreviewScreen> createState() =>
      _HomeWidgetPreviewScreenState();
}

class _HomeWidgetPreviewScreenState extends State<HomeWidgetPreviewScreen> {
  late final TransactionController _transactionController;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<TransactionController>()) {
      Get.put(TransactionController());
    }
    _transactionController = Get.find<TransactionController>();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Home Widget"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : AppColors.lightTextPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 18.sp,
        ),
      ),
      body: Container(
        height: double.infinity,
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: Responsive.contentMaxWidth(context),
                ),
                child: Column(
                  children: [
                    SizedBox(height: 10.h),
                    _buildWidgetPreview(),
                    SizedBox(height: 28.h),
                    _buildStep(
                      step: "1",
                      title: "Add the widget",
                      body:
                          "Long-press your home screen, tap Widgets, "
                          "search for “WealthSync”, then drag it onto your "
                          "home screen.",
                      icon: Icons.add_box_outlined,
                    ),
                    _buildStep(
                      step: "2",
                      title: "Tap to add a transaction",
                      body:
                          "Tapping the widget opens the Send / Add "
                          "transaction screen.",
                      icon: Icons.login_rounded,
                    ),
                    _buildStep(
                      step: "3",
                      title: "Always up to date",
                      body:
                          "Your balance refreshes automatically every time "
                          "you add, import or edit a transaction — no manual "
                          "setup needed.",
                      icon: Icons.auto_awesome_rounded,
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWidgetPreview() {
    final currency = CurrencyController.to.currencySymbol.value;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.darkBackground,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "💰 WealthSync",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11.sp,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 4.h),
          PrivacyText(
            "$currency${_transactionController.totalBalance.toStringAsFixed(2)}",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              Text(
                "Total Balance",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10.sp,
                ),
              ),
              const Spacer(),
              Text(
                "+ Add",
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required String step,
    required String title,
    required String body,
    required IconData icon,
    bool isLast = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : AppColors.lightBorder.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 20.sp),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$step. $title",
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  body,
                  style: TextStyle(
                    color: isDark
                        ? Colors.white54
                        : AppColors.lightTextSecondary,
                    fontSize: 12.sp,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
