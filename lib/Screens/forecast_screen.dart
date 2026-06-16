import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:money_control/Controllers/analytics_controller.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/l10n/app_localizations.dart';
import 'package:money_control/Components/shimmer_loading.dart';

class ForecastScreen extends StatefulWidget {
  const ForecastScreen({super.key});

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  late final AnalyticsController controller;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<TransactionController>()) {
      Get.put(TransactionController());
    }
    if (!Get.isRegistered<AnalyticsController>()) Get.put(AnalyticsController());
    controller = Get.find<AnalyticsController>();
  }

  String _formatIndianCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: CurrencyController.to.currencySymbol.value,
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  String _monthName(int monthNum) {
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];
    if (monthNum < 1 || monthNum > 12) return '';
    return months[monthNum - 1];
  }

  @override
  Widget build(BuildContext context) {

    DateTime now = DateTime.now();
    String currentMonthYear = "${_monthName(now.month)} ${now.year}";
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark ? AppColors.darkGradient : AppColors.lightGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: theme.iconTheme.color),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            l10n.monthlyForecastTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 18.sp,
            ),
          ),
        ),
        body: SafeArea(
          child: Obx(() {
            if (controller.isLoading.value) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
                child: const ForecastShimmer(),
              );
            }

            if (controller.hasError.value) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48.sp, color: AppColors.error),
                    SizedBox(height: 12.h),
                    Text(
                      'Could not load forecast',
                      style: theme.textTheme.bodyLarge,
                    ),
                    SizedBox(height: 8.h),
                    TextButton(
                      onPressed: controller.loadMonthTransactions,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    currentMonthYear,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 24.sp,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 30.h),

                  // ------ Income Section ------
                  _sectionHeader(l10n.incomeSectionTitle, AppColors.success),
                  SizedBox(height: 16.h),
                  _ForecastCard(
                    label: l10n.incomeSoFar,
                    amount: controller.incomeSoFar.value,
                    color: AppColors.success,
                    formattedAmount: _formatIndianCurrency(
                      controller.incomeSoFar.value,
                    ),
                    icon: Icons.download_rounded,
                    isForecast: false,
                  ),
                  SizedBox(height: 12.h),
                  _ForecastCard(
                    label: l10n.projectedRemaining,
                    amount: controller.forecastIncome.value,
                    color: const Color(0xFF69F0AE),
                    formattedAmount: _formatIndianCurrency(
                      controller.forecastIncome.value,
                    ),
                    icon: Icons.trending_up_rounded,
                    isForecast: true,
                  ),

                  SizedBox(height: 40.h),

                  // ------ Expense Section ------
                  _sectionHeader(l10n.expenseSectionTitle, AppColors.error),
                  SizedBox(height: 16.h),
                  _ForecastCard(
                    label: l10n.expensesSoFar,
                    amount: controller.expenseSoFar.value,
                    color: AppColors.error,
                    formattedAmount: _formatIndianCurrency(
                      controller.expenseSoFar.value,
                    ),
                    icon: Icons.upload_rounded,
                    isForecast: false,
                  ),
                  SizedBox(height: 12.h),
                  _ForecastCard(
                    label: l10n.projectedRemaining,
                    amount: controller.forecastExpense.value,
                    color: const Color(0xFFFF5252),
                    formattedAmount: _formatIndianCurrency(
                      controller.forecastExpense.value,
                    ),
                    icon: Icons.trending_down_rounded,
                    isForecast: true,
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          title,
          style: TextStyle(
            color: color.withValues(alpha: 0.8),
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Container(height: 1, color: color.withValues(alpha: 0.2)),
        ),
      ],
    );
  }
}

class _ForecastCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final String formattedAmount;
  final IconData icon;
  final bool isForecast;

  const _ForecastCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.formattedAmount,
    required this.icon,
    required this.isForecast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassContainer(
      padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 20.w),
      borderRadius: BorderRadius.circular(24.r),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20.sp),
              ),
              SizedBox(width: 16.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 13.sp,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            formattedAmount,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.titleLarge?.color,
              shadows: isForecast
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
