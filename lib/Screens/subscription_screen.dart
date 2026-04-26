import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Controllers/subscription_controller.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Services/iap_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String _selectedPlan = "Yearly"; // Default to best value

  @override
  Widget build(BuildContext context) {
    // Premium Gradient Background
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF1A1A2E), // Midnight Void
            Color(0xFF16213E), // Deep Blue
            Color(0xFF0F3460), // Royal Blue
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
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: Obx(() {
            // ── TRIAL VIEW ──────────────────────────────────────────────────
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
                        color: Colors.white,
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
                      style: TextStyle(fontSize: 15.sp, color: Colors.white70, height: 1.5),
                    ),
                    SizedBox(height: 32.h),
                    _buildFeatureRow("Unlimited Transactions", "No monthly limits on your activity."),
                    _buildFeatureRow("Unlimited Categories", "Create as many categories as you need."),
                    _buildFeatureRow("AI SMS Tracking", "Automated expense tracking from bank SMS."),
                    _buildFeatureRow("Smart Budgeting", "Set limits and get alerts before overspending."),
                    _buildFeatureRow("Data Export", "Download CSV & PDF reports for tax & analysis."),
                    _buildFeatureRow("Advanced Analytics", "Lifetime history and deep trend insights."),
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
                                      style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(height: 12.h),
                                    Text(
                                      "You will lose Pro access immediately. This cannot be undone.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white70, fontSize: 15.sp, height: 1.5),
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
                                                colorText: Colors.white,
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
                        style: TextStyle(color: Colors.white38, fontSize: 14.sp),
                      ),
                    ),
                    SizedBox(height: 40.h),
                  ],
                ),
              );
            }

            // ── PAID PRO VIEW ────────────────────────────────────────────────
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
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      "Enjoy unlimited access to all premium features.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16.sp, color: Colors.white70),
                    ),
                    SizedBox(height: 40.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Current Plan",
                            style: TextStyle(
                              color: Colors.white54,
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
                                color: Colors.white30,
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
                                        color: Colors.white,
                                        fontSize: 20.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 12.h),
                                    Text(
                                      "Are you sure you want to cancel? You will lose access to Pro features at the end of the billing period.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white70,
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
                                                  colorText: Colors.white,
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
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      "Your upgrade request is currently under review by the administration. You will be notified once your account is upgraded to Pro.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 40.h),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white30),
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          "Go Back",
                          style: TextStyle(
                            color: Colors.white,
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
                  // Header Icon
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

                  // Title
                  Text(
                    "Unlock Pro Access",
                    style: TextStyle(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    "Supercharge your financial control with premium features designed for growth.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                  // Trial banner / expired-trial notice
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

                  // Features List
                  _buildFeatureRow(
                    "Unlimited Transactions",
                    "No monthly limits on your activity.",
                  ),
                  _buildFeatureRow(
                    "Unlimited Categories",
                    "Create as many categories as you need.",
                  ),
                  _buildFeatureRow(
                    "AI SMS Tracking",
                    "Automated expense tracking from bank SMS.",
                  ),
                  _buildFeatureRow(
                    "Smart Budgeting",
                    "Set limits and get alerts before overspending.",
                  ),
                  _buildFeatureRow(
                    "Data Export",
                    "Download CSV & PDF reports for tax & analysis.",
                  ),
                  _buildFeatureRow(
                    "Advanced Analytics",
                    "Lifetime history and deep trend insights.",
                  ),

                  SizedBox(height: 40.h),

                  // Pricing Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildPriceCard(
                          "Monthly",
                          "₹249",
                          "/mo",
                          false,
                          "Monthly",
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: _buildPriceCard(
                          "Yearly",
                          "₹1,999",
                          "/yr",
                          true,
                          "Yearly",
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 40.h),

                  // Subscribe Button
                  Obx(() {
                    final loading = IapService().isLoading.value;
                    final label = SubscriptionController.to.trialUsed.value
                        ? "Subscribe Now"
                        : "Start 7-Day Free Trial";
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                        child: loading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                label,
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    );
                  }),
                  SizedBox(height: 12.h),
                  TextButton(
                    onPressed: () => IapService().restorePurchases(),
                    child: Text(
                      "Restore Purchases",
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    "Cancel anytime. No questions asked.",
                    style: TextStyle(color: Colors.white30, fontSize: 12.sp),
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String title, String subtitle) {
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
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white54, fontSize: 14.sp),
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
  ) {
    final isSelected = _selectedPlan == planId;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = planId),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.cyan.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected
                ? Colors.cyanAccent
                : Colors.white.withValues(alpha: 0.1),
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
                color: Colors.white70,
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
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24.sp,
                    ),
                  ),
                  TextSpan(
                    text: period,
                    style: TextStyle(color: Colors.white54, fontSize: 14.sp),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _buySubscription() async {
    final productId = _selectedPlan == 'Monthly'
        ? IapService.kMonthlyId
        : IapService.kYearlyId;
    await IapService().buySubscription(productId);
  }
}
