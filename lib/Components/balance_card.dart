import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/glass_container.dart';

import 'package:money_control/Screens/add_transaction.dart';
import 'package:money_control/Components/methods.dart';
import 'package:get/get.dart';
import 'package:money_control/Controllers/privacy_controller.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Controllers/lent_money_controller.dart';
import 'package:money_control/Controllers/recurring_payment_controller.dart';

class BalanceCard extends StatefulWidget {
  const BalanceCard({super.key});

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  late final PrivacyController _privacyController;
  late final TransactionController _transactionController;
  late final LentMoneyController _lentMoneyController;
  late final RecurringPaymentController _recurringPaymentController;
  final RxBool _includeLentMoney = false.obs;
  final RxBool _subtractSubscriptions = false.obs;
  double _lastAnimatedValue = 0;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<PrivacyController>()) Get.put(PrivacyController());
    _privacyController = Get.find<PrivacyController>();
    if (!Get.isRegistered<TransactionController>()) Get.put(TransactionController());
    _transactionController = Get.find<TransactionController>();
    if (!Get.isRegistered<LentMoneyController>()) Get.put(LentMoneyController());
    _lentMoneyController = Get.find<LentMoneyController>();
    if (!Get.isRegistered<RecurringPaymentController>()) Get.put(RecurringPaymentController());
    _recurringPaymentController = Get.find<RecurringPaymentController>();
  }

  @override
  void dispose() {
    _includeLentMoney.close();
    _subtractSubscriptions.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

    // Use AppColors.primary/secondary for a premium look, or keep the specific card gradient
    // Let's align with the app's theme but make it pop
    final gradientColors = isDark
        ? [AppColors.primary, const Color(0xFF4A148C)]
        : [AppColors.primary, AppColors.secondary];

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.h),
      child: GlassContainer(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(32.r),
        // Overriding GlassContainer default color/gradient to have the strong card brand color
        // But keeping the glass border effect
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32.r),
          ),
          child: Stack(
            children: [
              // Static decorative blobs — isolated in their own repaint layer
              // so balance value changes do not trigger repaints here.
              const Positioned(
                right: -60,
                top: -60,
                child: RepaintBoundary(
                  child: SizedBox(
                    width: 250,
                    height: 250,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color(0x26FFFFFF),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned(
                left: -60,
                bottom: -60,
                child: RepaintBoundary(
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color(0x1AFFFFFF),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.all(
                  24.r,
                ), // Restore padding inside the custom container
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Balance',
                          style: TextStyle(
                            color: isDark ? Colors.white.withValues(alpha: 0.8) : AppColors.lightTextPrimary.withValues(alpha: 0.8),
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Wrap(
                          spacing: 8.w,
                          children: [
                            Obx(
                              () => GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  if (_privacyController.isPrivacyMode.value) {
                                    return; // Prevent toggle if hidden
                                  }
                                  _includeLentMoney.value =
                                      !_includeLentMoney.value;
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10.w,
                                    vertical: 4.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _includeLentMoney.value
                                        ? isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.14)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(
                                      color: _includeLentMoney.value
                                          ? isDark ? Colors.white.withValues(alpha: 0.4) : AppColors.lightBorder.withValues(alpha: 0.4)
                                          : isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lightBorder.withValues(alpha: 0.1),
                                    ),
                                  ),
                                  child: Text(
                                    _includeLentMoney.value
                                        ? "Lent Included"
                                        : "+ Add Lent",
                                    style: TextStyle(
                                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // New Subscription Toggle Button
                            Obx(
                              () => GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  if (_privacyController.isPrivacyMode.value) {
                                    return;
                                  }
                                  _subtractSubscriptions.value =
                                      !_subtractSubscriptions.value;
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10.w,
                                    vertical: 4.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _subtractSubscriptions.value
                                        ? isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.14)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(
                                      color: _subtractSubscriptions.value
                                          ? isDark ? Colors.white.withValues(alpha: 0.4) : AppColors.lightBorder.withValues(alpha: 0.4)
                                          : isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lightBorder.withValues(alpha: 0.1),
                                    ),
                                  ),
                                  child: Text(
                                    _subtractSubscriptions.value
                                        ? "- ${CurrencyController.to.currencySymbol.value}${_recurringPaymentController.pendingSubscriptions.value.toStringAsFixed(0)} (Subs)"
                                        : "- Subs",
                                    style: TextStyle(
                                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    if (user != null)
                      Obx(() {
                        if (_transactionController.isLoading.value) {
                          return _balanceShimmer(Theme.of(context).colorScheme);
                        }
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _privacyController.togglePrivacy();
                          },
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    LinearGradient(
                                      colors: [isDark ? Colors.white : AppColors.lightTextPrimary, Color(0xFFE0E0E0)],
                                    ).createShader(bounds),
                                child: Obx(() {
                                  if (_privacyController.isPrivacyMode.value) {
                                    return Text(
                                      "••••",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 36.sp,
                                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                        letterSpacing: -1.0,
                                        shadows: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.1,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else {
                                    return TweenAnimationBuilder<double>(
                                      tween: Tween<double>(
                                        begin: _lastAnimatedValue,
                                        end: () {
                                          double total = _transactionController
                                              .totalBalance;
                                          if (_includeLentMoney.value) {
                                            total +=
                                                _lentMoneyController.netBalance;
                                          }
                                          if (_subtractSubscriptions.value) {
                                            total -= _recurringPaymentController
                                                .pendingSubscriptions
                                                .value;
                                          }
                                          return total;
                                        }(),
                                      ),
                                      duration: const Duration(
                                        milliseconds: 800,
                                      ),
                                      curve: Curves.easeOutExpo,
                                      builder: (context, value, child) {
                                        return Text(
                                          '${CurrencyController.to.currencySymbol.value} ${value.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 36.sp,
                                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                            letterSpacing: -1.0,
                                            shadows: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.1,
                                                ),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      onEnd: () {
                                        setState(() {
                                          _lastAnimatedValue = () {
                                            double total = _transactionController
                                                .totalBalance;
                                            if (_includeLentMoney.value) {
                                              total +=
                                                  _lentMoneyController.netBalance;
                                            }
                                            if (_subtractSubscriptions.value) {
                                              total -= _recurringPaymentController
                                                  .pendingSubscriptions
                                                  .value;
                                            }
                                            return total;
                                          }();
                                        });
                                      },
                                    );
                                  }
                                }),
                              ),
                              SizedBox(width: 12.w),
                              Obx(
                                () => Icon(
                                  _privacyController.isPrivacyMode.value
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: isDark ? Colors.white.withValues(alpha: 0.5) : AppColors.lightTextPrimary.withValues(alpha: 0.5),
                                  size: 20.sp,
                                ),
                              ),
                            ],
                          ),
                        );
                      })
                    else
                      _balanceLabel('--', Theme.of(context).colorScheme),
                    Obx(() {
                      if (_transactionController.isLoading.value) return const SizedBox.shrink();
                      if (_privacyController.isPrivacyMode.value) return const SizedBox.shrink();
                      final now = DateTime.now();
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid == null) return const SizedBox.shrink();
                      final txs = _transactionController.transactions;

                      double thisMonth = 0;
                      double lastMonth = 0;
                      final startThis = DateTime(now.year, now.month, 1);
                      final startLast = DateTime(now.year, now.month - 1, 1);
                      final endLast = startThis;

                      for (final tx in txs) {
                        final isSend = tx.senderId == uid;
                        if (!isSend) continue;
                        final amount = tx.amount.abs();
                        if (!tx.date.isBefore(startThis)) {
                          thisMonth += amount;
                        } else if (!tx.date.isBefore(startLast) && tx.date.isBefore(endLast)) {
                          lastMonth += amount;
                        }
                      }

                      if (lastMonth == 0) return const SizedBox.shrink();
                      final pct = ((thisMonth - lastMonth) / lastMonth.abs() * 100);
                      final isUp = pct >= 0;
                      return Padding(
                        padding: EdgeInsets.only(bottom: 6.h),
                        child: Row(
                          children: [
                            Icon(
                              isUp ? Icons.trending_up : Icons.trending_down,
                              color: isUp
                                  ? const Color(0xFF69F0AE)
                                  : const Color(0xFFFF5252),
                              size: 14.sp,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              '${isUp ? '+' : ''}${pct.toStringAsFixed(1)}% vs last month',
                              style: TextStyle(
                                color: isUp
                                    ? const Color(0xFF69F0AE)
                                    : const Color(0xFFFF5252),
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    Obx(() {
                      final streak = _transactionController.streakCount.value;
                      if (streak < 2) return const SizedBox.shrink();
                      return Padding(
                        padding: EdgeInsets.only(bottom: 4.h),
                        child: Row(
                          children: [
                            Text(
                              '🔥 $streak day streak',
                              style: TextStyle(
                                color: isDark ? Colors.white.withValues(alpha: 0.85) : AppColors.lightTextPrimary.withValues(alpha: 0.85),
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    SizedBox(height: 24.h),
                    Row(
                      children: [
                        Expanded(
                          child: _glassActionButton(
                            label: "Send",
                            icon: Icons.north_east_rounded,
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              gotoPage(PaymentScreen(type: PaymentType.send));
                            },
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: _glassActionButton(
                            label: "Receive",
                            icon: Icons.south_west_rounded,
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              gotoPage(
                                PaymentScreen(type: PaymentType.receive),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54.h,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.084),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.15) : AppColors.lightBorder.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18.sp),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Keep helpers but ensure they return valid widgets for new style
  Widget _balanceLabel(String text, ColorScheme scheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 36.sp,
        color: isDark ? Colors.white : AppColors.lightTextPrimary,
        letterSpacing: -1.0,
      ),
    );
  }

  Widget _balanceShimmer(ColorScheme scheme) => Container(
    width: 120.w,
    height: 36.h,
    decoration: BoxDecoration(
      color: scheme.onSurface.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(12.r),
    ),
    margin: EdgeInsets.symmetric(vertical: 4.h),
  );
}
