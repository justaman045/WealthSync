import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Controllers/subscription_controller.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Services/iap_service.dart';
import 'package:money_control/Services/payment_config_service.dart';
import 'package:money_control/main.dart' show rootScaffoldMessengerKey;
import 'package:money_control/Components/colors.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  static const _upiChannel = MethodChannel('money_control/upi');

  String _selectedPlan = "Yearly";
  final _txnController = TextEditingController();
  String? _upiTxnId;
  bool _upiSubmitting = false;

  @override
  void dispose() {
    _txnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ...(isDark ? AppColors.darkGradient : AppColors.lightGradient),
            isDark ? const Color(0xFF0F3460) : const Color(0xFFCBD5E1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close, color: isDark ? Colors.white : AppColors.lightTextPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: Obx(() {
            if (SubscriptionController.to.isTrial) {
              final days = SubscriptionController.to.daysLeftInTrial;
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  children: [
                    SizedBox(height: 40.h),
                    Container(
                      padding: EdgeInsets.all(20.w),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(Icons.timer_outlined, size: 60.sp, color: Colors.amber),
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      "Free Trial Active",
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        "$days day${days == 1 ? '' : 's'} remaining",
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      "You have full Pro access during your trial. Subscribe before it ends to keep everything.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15.sp, color: isDark ? Colors.white70 : AppColors.lightTextSecondary, height: 1.5),
                    ),
                    SizedBox(height: 32.h),
                    _buildFeatureRow("Unlimited Transactions", "No monthly limits on your activity.", isDark),
                    _buildFeatureRow("Unlimited Categories", "Create as many categories as you need.", isDark),
                    _buildFeatureRow("AI SMS Tracking", "Automated expense tracking from bank SMS.", isDark),
                    _buildFeatureRow("Smart Budgeting", "Set limits and get alerts before overspending.", isDark),
                    _buildFeatureRow("Data Export", "Download CSV & PDF reports for tax & analysis.", isDark),
                    _buildFeatureRow("Advanced Analytics", "Lifetime history and deep trend insights.", isDark),
                    SizedBox(height: 32.h),
                    SizedBox(
                      width: double.infinity,
                      height: 56.h,
                      child: ElevatedButton(
                        onPressed: _buySubscription,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: Colors.black,
                          elevation: 10,
                          shadowColor: Colors.cyanAccent.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                        child: Text(
                          "Upgrade to Pro Now",
                          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    TextButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          barrierColor: Colors.black.withValues(alpha: 0.8),
                          builder: (ctx) => Center(
                            child: Material(
                              color: Colors.transparent,
                              child: GlassContainer(
                                width: 320.w,
                                padding: EdgeInsets.all(24.w),
                                borderRadius: BorderRadius.circular(24.r),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning_amber_rounded, size: 40.sp, color: Colors.redAccent),
                                    SizedBox(height: 16.h),
                                    Text(
                                      "End Free Trial?",
                                      style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary, fontSize: 20.sp, fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(height: 12.h),
                                    Text(
                                      "You will lose Pro access immediately. This cannot be undone.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: isDark ? Colors.white70 : AppColors.lightTextSecondary, fontSize: 15.sp, height: 1.5),
                                    ),
                                    SizedBox(height: 32.h),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextButton(
                                            onPressed: () async {
                                              Navigator.of(ctx).pop();
                                              await SubscriptionController.to.cancelSubscription();
                                              Get.snackbar(
                                                "Trial Ended",
                                                "Your free trial has been ended.",
                                                backgroundColor: Colors.redAccent.withValues(alpha: 0.85),
                                                colorText: isDark ? Colors.white : Colors.black,
                                              );
                                            },
                                            child: Text("End Trial", style: TextStyle(color: Colors.redAccent, fontSize: 16.sp, fontWeight: FontWeight.w600)),
                                          ),
                                        ),
                                        SizedBox(width: 16.w),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () => Navigator.of(ctx).pop(),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.cyanAccent,
                                              foregroundColor: Colors.black,
                                              padding: EdgeInsets.symmetric(vertical: 14.h),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                                            ),
                                            child: Text("Keep Trial", style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: Text(
                        "End Trial",
                        style: TextStyle(color: isDark ? Colors.white38 : AppColors.lightTextTertiary, fontSize: 14.sp),
                      ),
                    ),
                    SizedBox(height: 40.h),
                  ],
                ),
              );
            }

            if (SubscriptionController.to.isPro) {
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 40.h),
                    Container(
                      padding: EdgeInsets.all(20.w),
                      decoration: BoxDecoration(
                        color: Colors.cyan.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyan.withValues(alpha: 0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.verified_user_rounded,
                        size: 60.sp,
                        color: Colors.cyanAccent,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      "You are a Pro Member!",
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      "Enjoy unlimited access to all premium features.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16.sp, color: isDark ? Colors.white70 : AppColors.lightTextSecondary),
                    ),
                    SizedBox(height: 40.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20.w),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lightBorder.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Current Plan",
                            style: TextStyle(
                              color: isDark ? Colors.white54 : AppColors.lightTextSecondary,
                              fontSize: 14.sp,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Obx(() {
                            final plan =
                                SubscriptionController.to.planType.value;
                            return Text(
                              plan.isNotEmpty ? "Pro ($plan)" : "Pro",
                              style: TextStyle(
                                color: Colors.cyanAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 20.sp,
                              ),
                            );
                          }),
                          SizedBox(height: 8.h),
                          Obx(() {
                            final expiry =
                                SubscriptionController.to.expiryDate.value;
                            final label = expiry != null
                                ? "Renews on: ${expiry.day.toString().padLeft(2, '0')}/${expiry.month.toString().padLeft(2, '0')}/${expiry.year}"
                                : "Renews on: --";
                            return Text(
                              label,
                              style: TextStyle(
                                color: isDark ? Colors.white30 : Colors.black.withValues(alpha: 0.3),
                                fontSize: 12.sp,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    SizedBox(height: 40.h),
                    ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          barrierColor: Colors.black.withValues(alpha: 0.8),
                          builder: (context) => Center(
                            child: Material(
                              color: Colors.transparent,
                              child: GlassContainer(
                                width: 320.w,
                                padding: EdgeInsets.all(24.w),
                                borderRadius: BorderRadius.circular(24.r),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(16.w),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent.withValues(
                                          alpha: 0.1,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.warning_amber_rounded,
                                        size: 40.sp,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                    SizedBox(height: 24.h),
                                    Text(
                                      "Cancel Subscription?",
                                      style: TextStyle(
                                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                        fontSize: 20.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 12.h),
                                    Text(
                                      "Are you sure you want to cancel? You will lose access to Pro features at the end of the billing period.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                                        fontSize: 15.sp,
                                        height: 1.5,
                                      ),
                                    ),
                                    SizedBox(height: 32.h),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextButton(
                                            onPressed: () async {
                                              Navigator.of(context).pop();
                                              await SubscriptionController.to
                                                  .cancelSubscription();
                                              if (Get.context != null) {
                                                Get.snackbar(
                                                  "Subscription Cancelled",
                                                  "Your Pro subscription has been cancelled.",
                                                  backgroundColor:
                                                      Colors.redAccent
                                                          .withValues(
                                                            alpha: 0.85,
                                                          ),
                                                  colorText: isDark ? Colors.white : Colors.black,
                                                );
                                              }
                                            },
                                            style: TextButton.styleFrom(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 14.h,
                                              ),
                                            ),
                                            child: Text(
                                              "Cancel Plan",
                                              style: TextStyle(
                                                color: Colors.redAccent,
                                                fontSize: 16.sp,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 16.w),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.cyanAccent,
                                              foregroundColor: Colors.black,
                                              padding: EdgeInsets.symmetric(
                                                vertical: 14.h,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12.r),
                                              ),
                                            ),
                                            child: Text(
                                              "Keep Plan",
                                              style: TextStyle(
                                                fontSize: 16.sp,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withValues(
                          alpha: 0.2,
                        ),
                        foregroundColor: Colors.redAccent,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24.w,
                          vertical: 12.h,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          side: BorderSide(
                            color: Colors.redAccent.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      child: const Text("Cancel Subscription"),
                    ),
                  ],
                ),
              );
            } else if (SubscriptionController.to.isPending) {
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 100.h),
                    Container(
                      padding: EdgeInsets.all(20.w),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orangeAccent.withValues(alpha: 0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.hourglass_top_rounded,
                        size: 60.sp,
                        color: Colors.orangeAccent,
                      ),
                    ),
                    SizedBox(height: 32.h),
                    Text(
                      "Verification In Progress",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      "Your upgrade request is currently under review by the administration. You will be notified once your account is upgraded to Pro.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 40.h),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: isDark ? Colors.white30 : Colors.black.withValues(alpha: 0.3)),
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          "Go Back",
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyan.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.diamond_outlined,
                      size: 60.sp,
                      color: Colors.cyanAccent,
                    ),
                  ),
                  SizedBox(height: 24.h),

                  Text(
                    "Unlock Pro Access",
                    style: TextStyle(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    "Supercharge your financial control with premium features designed for growth.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                      height: 1.5,
                    ),
                  ),
                  Obx(() {
                    final sub = SubscriptionController.to;
                    if (sub.isTrial) {
                      return Container(
                        margin: EdgeInsets.only(bottom: 20.h),
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF69F0AE).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: const Color(0xFF69F0AE), width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer_outlined, color: Color(0xFF69F0AE), size: 20),
                            SizedBox(width: 8.w),
                            Text(
                              '${sub.daysLeftInTrial} day${sub.daysLeftInTrial == 1 ? '' : 's'} left in free trial',
                              style: TextStyle(
                                color: const Color(0xFF69F0AE),
                                fontWeight: FontWeight.w600,
                                fontSize: 14.sp,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    if (sub.trialUsed.value) {
                      return Container(
                        margin: EdgeInsets.only(bottom: 20.h),
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4), width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer_off_outlined, color: Colors.redAccent, size: 20),
                            SizedBox(width: 8.w),
                            Text(
                              'Your free trial has ended',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w600,
                                fontSize: 14.sp,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),

                  SizedBox(height: 40.h),

                  _buildFeatureRow(
                    "Unlimited Transactions",
                    "No monthly limits on your activity.",
                    isDark,
                  ),
                  _buildFeatureRow(
                    "Unlimited Categories",
                    "Create as many categories as you need.",
                    isDark,
                  ),
                  _buildFeatureRow(
                    "AI SMS Tracking",
                    "Automated expense tracking from bank SMS.",
                    isDark,
                  ),
                  _buildFeatureRow(
                    "Smart Budgeting",
                    "Set limits and get alerts before overspending.",
                    isDark,
                  ),
                  _buildFeatureRow(
                    "Data Export",
                    "Download CSV & PDF reports for tax & analysis.",
                    isDark,
                  ),
                  _buildFeatureRow(
                    "Advanced Analytics",
                    "Lifetime history and deep trend insights.",
                    isDark,
                  ),

                  SizedBox(height: 40.h),

                  Row(
                    children: [
                      Expanded(
                        child: Obx(() {
                          final iap = Get.find<IapService>();
                          final monthly = iap.products.firstWhereOrNull(
                            (p) => p.id == IapService.kMonthlyId,
                          );
                          return _buildPriceCard(
                            "Monthly",
                            monthly?.price ?? "${CurrencyController.to.currencySymbol.value}249",
                            "/mo",
                            false,
                            "Monthly",
                            isDark,
                          );
                        }),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Obx(() {
                          final iap = Get.find<IapService>();
                          final yearly = iap.products.firstWhereOrNull(
                            (p) => p.id == IapService.kYearlyId,
                          );
                          return _buildPriceCard(
                            "Yearly",
                            yearly?.price ?? "${CurrencyController.to.currencySymbol.value}1,999",
                            "/yr",
                            true,
                            "Yearly",
                            isDark,
                          );
                        }),
                      ),
                    ],
                  ),

                  SizedBox(height: 40.h),

                  Obx(() {
                    final isUpiMode = PaymentConfigService.to.paymentMode.value == 'upi';
                    return isUpiMode ? _buildUpiFlow(isDark) : _buildIapFlow(isDark);
                  }),
                  SizedBox(height: 20.h),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String title, String subtitle, bool isDark) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(Icons.check, color: Colors.greenAccent, size: 16.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  style: TextStyle(color: isDark ? Colors.white54 : AppColors.lightTextSecondary, fontSize: 14.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard(
    String title,
    String price,
    String period,
    bool isBestValue,
    String planId,
    bool isDark,
  ) {
    final isSelected = _selectedPlan == planId;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = planId),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.cyan.withValues(alpha: 0.15)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected
                ? Colors.cyanAccent
                : (isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lightBorder.withValues(alpha: 0.5)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            if (isBestValue) ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                margin: EdgeInsets.only(bottom: 4.h),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  "BEST VALUE",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 10.sp,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                margin: EdgeInsets.only(bottom: 8.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF69F0AE).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: const Color(0xFF69F0AE), width: 1),
                ),
                child: Text(
                  "SAVE 33%",
                  style: TextStyle(
                    color: const Color(0xFF69F0AE),
                    fontWeight: FontWeight.bold,
                    fontSize: 10.sp,
                  ),
                ),
              ),
            ],
            Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8.h),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: price,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 24.sp,
                    ),
                  ),
                  TextSpan(
                    text: period,
                    style: TextStyle(color: isDark ? Colors.white54 : AppColors.lightTextSecondary, fontSize: 14.sp),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIapFlow(bool isDark) {
    return Column(
      children: [
        Obx(() {
          final loading = Get.find<IapService>().isLoading.value;
          final ctrl = SubscriptionController.to;
          final trialDays = ctrl.trialEndDate.value != null
              ? ctrl.trialEndDate.value!.difference(DateTime.now()).inDays.clamp(1, 30)
              : (ctrl.trialUsed.value ? 0 : 7);
          final label = ctrl.trialUsed.value ? "Subscribe Now" : "Start $trialDays-Day Free Trial";
          return SizedBox(
            width: double.infinity,
            height: 56.h,
            child: ElevatedButton(
              onPressed: loading ? null : _buySubscription,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                elevation: 10,
                shadowColor: Colors.cyanAccent.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              ),
              child: loading
                  ? const SizedBox(height: 24, width: 24,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                  : Text(label, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ),
          );
        }),
        SizedBox(height: 12.h),
        TextButton(
          onPressed: () => Get.find<IapService>().restorePurchases(),
          child: Text("Restore Purchases", style: TextStyle(color: isDark ? Colors.white38 : AppColors.lightTextTertiary, fontSize: 13.sp)),
        ),
        SizedBox(height: 8.h),
        Text("Cancel anytime. No questions asked.", style: TextStyle(color: isDark ? Colors.white30 : Colors.black.withValues(alpha: 0.3), fontSize: 12.sp)),
      ],
    );
  }

  Widget _buildUpiFlow(bool isDark) {
    final upiId = PaymentConfigService.to.upiId.value;
    final amount = _selectedPlan == 'Monthly' ? '249' : '1,999';
    final amountRaw = _selectedPlan == 'Monthly' ? '249.00' : '1999.00';

    return StatefulBuilder(builder: (context, setLocal) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pay via UPI', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 15.sp)),
                SizedBox(height: 8.h),
                Text('Send ${CurrencyController.to.currencySymbol.value}$amount to:', style: TextStyle(color: isDark ? Colors.white70 : AppColors.lightTextSecondary, fontSize: 14.sp)),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Expanded(child: Text(upiId.isNotEmpty ? upiId : '—', style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary, fontWeight: FontWeight.bold, fontSize: 16.sp))),
                    if (upiId.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.copy, color: Colors.cyanAccent, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: upiId));
                          Get.snackbar('Copied', 'UPI ID copied to clipboard.',
                              backgroundColor: Colors.cyanAccent.withValues(alpha: 0.2),
                              colorText: isDark ? Colors.white : Colors.black, snackPosition: SnackPosition.BOTTOM);
                        },
                      ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text('Note: Money Control Pro - $_selectedPlan', style: TextStyle(color: isDark ? Colors.white38 : AppColors.lightTextTertiary, fontSize: 12.sp)),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          if (upiId.isNotEmpty)
            SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton.icon(
                onPressed: () => _openUpiApp(amountRaw, upiId, setLocal),
                icon: const Icon(Icons.account_balance_wallet_rounded),
                label: Text('Open UPI App', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                ),
              ),
            ),

          SizedBox(height: 16.h),
          Text('Enter Transaction ID', style: TextStyle(color: isDark ? Colors.white70 : AppColors.lightTextSecondary, fontSize: 13.sp)),
          SizedBox(height: 8.h),
          GlassContainer(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
            borderRadius: BorderRadius.circular(14.r),
            child: TextField(
              controller: _txnController,
              style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary, fontSize: 15.sp),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: _upiTxnId ?? 'Paste UPI transaction ID here',
                hintStyle: TextStyle(color: isDark ? Colors.white38 : AppColors.lightTextTertiary, fontSize: 14.sp),
                prefixIcon: const Icon(Icons.receipt_long_rounded, color: Colors.cyanAccent),
              ),
              onChanged: (_) => setLocal(() {}),
            ),
          ),
          SizedBox(height: 8.h),
          Text('The transaction ID is shown in your UPI app after payment.', style: TextStyle(color: isDark ? Colors.white30 : Colors.black.withValues(alpha: 0.3), fontSize: 11.sp)),
          SizedBox(height: 20.h),

          SizedBox(
            width: double.infinity,
            height: 56.h,
            child: ElevatedButton(
              onPressed: (_upiSubmitting || _txnController.text.trim().isEmpty) ? null : () => _submitUpiPayment(setLocal),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                elevation: 10,
                shadowColor: Colors.cyanAccent.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              ),
              child: _upiSubmitting
                  ? const SizedBox(height: 24, width: 24,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                  : Text('Submit for Verification', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold)),
            ),
          ),
          SizedBox(height: 12.h),
          Text('Your request will be reviewed by the admin. You will be notified once approved.',
              textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white30 : Colors.black.withValues(alpha: 0.3), fontSize: 12.sp)),
        ],
      );
    });
  }

  Future<void> _openUpiApp(String amount, String upiId, StateSetter setLocal) async {
    _showUpiAppSelector(amount, upiId, setLocal);
  }

  void _showUpiAppSelector(String amount, String upiId, StateSetter setLocal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const apps = [
      (name: 'GPay',   pkg: 'com.google.android.apps.nbu.paisa.user'),
      (name: 'PhonePe', pkg: 'com.phonepe.app'),
      (name: 'Paytm',  pkg: 'net.one97.paytm'),
      (name: 'BHIM',    pkg: 'in.org.npci.upiapp'),
      (name: 'CRED',    pkg: 'com.dreamplug.androidapp'),
      (name: 'Any UPI', pkg: ''),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (_) => Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Choose UPI App', style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary, fontWeight: FontWeight.bold, fontSize: 18.sp)),
            SizedBox(height: 20.h),
            ...apps.map((app) => ListTile(
              title: Text(app.name, style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary)),
              trailing: Icon(Icons.arrow_forward_ios, color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.2), size: 14),
              onTap: () {
                Navigator.pop(context);
                _initiateUpiPayment(app.pkg, amount, upiId, setLocal);
              },
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _initiateUpiPayment(String pkg, String amount, String upiId, StateSetter setLocal) async {
    try {
      final response = await _upiChannel.invokeMethod<String>('pay', {
        if (pkg.isNotEmpty) 'packageName': pkg,
        'pa': upiId,
        'amount': amount,
        'payeeName': 'Money Control',
        'note': 'Money Control Pro - $_selectedPlan',
      });
      _parseUpiResponse(response, setLocal);
    } catch (e) {
      if (pkg.isNotEmpty) {
        _initiateUpiPayment('', amount, upiId, setLocal);
      } else {
        _showMessengerSnackBar('No UPI App Found', 'Please install a UPI app and try again.', Colors.redAccent);
      }
    }
  }

  void _parseUpiResponse(String? response, StateSetter setLocal) {
    if (response == null || response.isEmpty) return;
    final params = Uri.splitQueryString(response);
    final status = params['Status'] ?? params['status'] ?? '';
    final txnId = params['txnId'] ?? params['txnRef'] ?? params['approvalRefNo'] ?? '';

    if (status.toUpperCase() == 'SUCCESS' && txnId.isNotEmpty) {
      setLocal(() {
        _upiTxnId = txnId;
        _txnController.text = txnId;
      });
      _showMessengerSnackBar('Payment Successful', 'Transaction ID auto-filled. Tap Submit to complete.', Colors.green);
    } else if (status.toUpperCase() == 'SUBMITTED') {
      _showMessengerSnackBar('Payment Pending', 'Enter the transaction ID manually once confirmed.', Colors.orangeAccent);
    } else if (status.toUpperCase() == 'FAILURE') {
      _showMessengerSnackBar('Payment Failed', 'Please try again or enter the transaction ID manually.', Colors.redAccent);
    }
  }

  void _showMessengerSnackBar(String title, String message, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    rootScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
      content: Text('$title\n$message', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ));
  }

  Future<void> _submitUpiPayment(StateSetter setLocal) async {
    final txnId = _txnController.text.trim();
    if (txnId.isEmpty) return;
    setLocal(() => _upiSubmitting = true);
    try {
      await SubscriptionController.to.requestUpgrade(txnId, _selectedPlan);
    } finally {
      if (mounted) setLocal(() => _upiSubmitting = false);
    }
  }

  Future<void> _buySubscription() async {
    final isUpiMode = PaymentConfigService.to.paymentMode.value == 'upi';
    if (isUpiMode) {
      Get.to(() => const SubscriptionScreen(), arguments: {'scrollToPayment': true});
      return;
    }
    final productId = _selectedPlan == 'Monthly' ? IapService.kMonthlyId : IapService.kYearlyId;
    await Get.find<IapService>().buySubscription(productId);
  }
}
