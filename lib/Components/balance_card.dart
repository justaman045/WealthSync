import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/feature_gate.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Config/app_strings.dart';
import 'package:money_control/l10n/app_localizations.dart';
import 'package:money_control/Utils/wealth_math.dart';

import 'package:money_control/Screens/add_transaction.dart';
import 'package:money_control/Components/methods.dart';
import 'package:get/get.dart';
import 'package:money_control/Controllers/privacy_controller.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Controllers/lent_money_controller.dart';
import 'package:money_control/Controllers/recurring_payment_controller.dart';
import 'package:money_control/Services/feature_flag_service.dart';
import 'package:money_control/Services/performance_controller.dart';

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

  /// Temporary view switch, never persisted: when on, this month's pending
  /// commitments are deducted from the headline balance. Off by default so the
  /// card reports the money actually held until the user asks otherwise.
  final RxBool _includeDues = false.obs;
  final ValueNotifier<double> _lastAnimatedValue = ValueNotifier<double>(0);
  Worker? _flagResetWorker;

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
    _resetFlaggedToggles();
    _flagResetWorker = ever(
      FeatureFlagService.to.statusMap,
      (_) => _resetFlaggedToggles(),
    );
  }

  /// "As if never there": drop the lent toggle from the running total the
  /// moment an admin hides the feature, so the balance never silently keeps
  /// counting a hidden feature's amount (mirrors the privacy-mode ever worker).
  /// The dues toggle is cleared the same way — the chip is hidden by
  /// `FeatureVisible`, so leaving the deduction on would change the headline
  /// for a feature the user can no longer see or undo.
  void _resetFlaggedToggles() {
    final flags = FeatureFlagService.to;
    if (flags.isHidden('lent_money')) _includeLentMoney.value = false;
    if (flags.isHidden('recurring')) _includeDues.value = false;
  }

  /// Balance shown by the card. Delegates to the pure helper so the overlay
  /// signs are unit-tested rather than buried in a widget.
  double _computeTotal() {
    return computeDisplayTotal(
      balance: _transactionController.totalBalance,
      netLent: _lentMoneyController.netBalance,
      includeLent: _includeLentMoney.value,
      pendingDues: _recurringPaymentController.pendingSubscriptions.value,
      includeDues: _includeDues.value,
    );
  }

  @override
  void dispose() {
    _flagResetWorker?.dispose();
    _includeLentMoney.close();
    _includeDues.close();
    _lastAnimatedValue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final l10n = AppLocalizations.of(context)!;

    final gradientColors = isDark
        ? [AppColors.primary, AppColors.primaryPress]
        : [AppColors.primary, AppColors.secondary];

    return Container(
      margin: EdgeInsets.symmetric(vertical: AppSpace.s8.h),
      child: GlassContainer(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(AppRadius.xxl.r),
        // Overriding GlassContainer default color/gradient to have the strong card brand color
        // But keeping the glass border effect
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.xxl.r),
          ),
          child: Stack(
            children: [
              // Static decorative blobs — isolated in their own repaint layer
              // so balance value changes do not trigger repaints here. They are
              // decorative only, so they must never block taps (the top-right
              // blob can overlap the Send/Receive buttons on short screens).
              Positioned(
                right: -60.w,
                top: -60.w,
                child: _blob(size: 250, opacity: 0.15),
              ),
              Positioned(
                left: -60.w,
                bottom: -60.w,
                child: _blob(size: 200, opacity: 0.10),
              ),

              Padding(
                padding: EdgeInsets.all(AppSpace.s24.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppStrings.totalBalance,
                          style: AppType.labelLarge(
                            Colors.white.withValues(alpha: 0.8),
                          ).copyWith(letterSpacing: 0.5),
                        ),
                        Wrap(
                          spacing: AppSpace.s8.w,
                          children: [
                            FeatureVisible(
                              flagKey: 'lent_money',
                              child: Obx(
                                () => _overlayChip(
                                  toggled: _includeLentMoney.value,
                                  label: l10n.balanceIncludeLent,
                                  text: _includeLentMoney.value
                                      ? l10n.balanceLentIncluded
                                      : l10n.balanceAddLent,
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    if (_privacyController
                                        .isPrivacyMode
                                        .value) {
                                      return; // Prevent toggle if hidden
                                    }
                                    _includeLentMoney.value =
                                        !_includeLentMoney.value;
                                  },
                                ),
                              ),
                            ),
                            // Commitments due this month. Informational by
                            // default; tapping deducts them from the headline
                            // balance for this session only.
                            FeatureVisible(
                              flagKey: 'recurring',
                              child: Obx(() {
                                final committed = _recurringPaymentController
                                    .pendingSubscriptions
                                    .value;
                                return _overlayChip(
                                  toggled: _includeDues.value,
                                  label: l10n.balanceDeductDues,
                                  text: _includeDues.value
                                      ? l10n.balanceDuesDeducted
                                      : committed <= 0
                                      ? l10n.balanceNoDues
                                      : _privacyController
                                                .isPrivacyMode
                                                .value
                                        ? l10n.balanceDuesHidden
                                        : l10n.balanceDuesDue(
                                            '- ${CurrencyController.to.currencySymbol.value}${committed.toStringAsFixed(0)}',
                                          ),
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    if (_privacyController
                                        .isPrivacyMode
                                        .value) {
                                      return; // Never move a hidden number
                                    }
                                    _includeDues.value = !_includeDues.value;
                                  },
                                );
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpace.s12.h),
                    if (user != null)
                      Obx(() {
                        if (_transactionController.isLoading.value) {
                          return _balanceShimmer(Theme.of(context).colorScheme);
                        }
                        final label =
                            _privacyController.isPrivacyMode.value
                            ? l10n.balanceHiddenAnnouncement(
                                AppStrings.totalBalance,
                              )
                            : l10n.balanceTapToHide(AppStrings.totalBalance);
                        return Semantics(
                          button: true,
                          label: label,
                          child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _privacyController.toggle();
                          },
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Obx(() {
                                final style = AppType.money(
                                  color: Colors.white,
                                  size: 36.sp,
                                );
                                if (_privacyController.isPrivacyMode.value) {
                                  return Text(l10n.balanceHidden, style: style);
                                } else if (PerformanceController
                                    .to
                                    .liteMode
                                    .value) {
                                  // Lite mode: skip the count-up tween.
                                  return Text(
                                    '${CurrencyController.to.currencySymbol.value} ${_computeTotal().toStringAsFixed(2)}',
                                    style: style,
                                  );
                                } else {
                                  return TweenAnimationBuilder<double>(
                                    tween: Tween<double>(
                                      begin: _lastAnimatedValue.value,
                                      end: _computeTotal(),
                                    ),
                                    duration: AppMotion.countUp,
                                    curve: AppMotion.emphasized,
                                    builder: (context, value, child) {
                                      return Text(
                                        '${CurrencyController.to.currencySymbol.value} ${value.toStringAsFixed(2)}',
                                        style: style,
                                      );
                                    },
                                    onEnd: () {
                                      _lastAnimatedValue.value =
                                          _computeTotal();
                                    },
                                  );
                                }
                              }),
                              SizedBox(width: AppSpace.s12.w),
                              Obx(
                                () => Icon(
                                  _privacyController.isPrivacyMode.value
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  size: 20.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                        );
                      })
                    else
                      _balanceLabel(
                        '--',
                        Theme.of(context).colorScheme,
                      ),
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
                        padding: EdgeInsets.only(bottom: AppSpace.s4.h),
                        child: Row(
                          children: [
                            Icon(
                              isUp ? Icons.trending_up : Icons.trending_down,
                              color: isUp
                                  ? AppColors.success
                                  : AppColors.error,
                              size: 14.sp,
                            ),
                            SizedBox(width: AppSpace.s4.w),
                            Text(
                              l10n.balanceVersusLastMonth(
                                '${isUp ? '+' : ''}${pct.toStringAsFixed(1)}',
                              ),
                              style: AppType.labelMedium(
                                isUp ? AppColors.success : AppColors.error,
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
                        padding: EdgeInsets.only(bottom: AppSpace.s4.h),
                        child: Text(
                          '🔥 ${l10n.balanceStreak(streak)}',
                          style: AppType.labelMedium(
                            Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      );
                    }),
                    SizedBox(height: AppSpace.s24.h),
                    FeatureVisible(
                      flagKey: 'transactions',
                      child: Row(
                        children: [
                          Expanded(
                            child: _glassActionButton(
                              label: AppStrings.send,
                              icon: Icons.north_east_rounded,
                              color: Colors.white,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                if (!ensureFeatureVisible(context, 'transactions')) {
                                  return;
                                }
                                gotoPage(
                                  PaymentScreen(type: PaymentType.send),
                                );
                              },
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: _glassActionButton(
                              label: AppStrings.receive,
                              icon: Icons.south_west_rounded,
                              color: Colors.white,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                if (!ensureFeatureVisible(context, 'transactions')) {
                                  return;
                                }
                                gotoPage(
                                  PaymentScreen(type: PaymentType.receive),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
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

  /// Decorative radial wash, in its own repaint layer so a balance change never
  /// repaints it, and behind an IgnorePointer so it can never swallow a tap.
  Widget _blob({required double size, required double opacity}) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: SizedBox(
          width: size.w,
          height: size.w,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: opacity),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A temporary view toggle on the card. Both overlays share this chrome so
  /// they cannot drift apart (they had: the two copies had different animation
  /// durations and each hardcoded its own copy).
  Widget _overlayChip({
    required bool toggled,
    required String label,
    required String text,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      toggled: toggled,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpace.s12.w,
            vertical: AppSpace.s8.h,
          ),
          decoration: BoxDecoration(
            color: toggled ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.xs.r),
            border: Border.all(
              color: Colors.white.withValues(alpha: toggled ? 0.4 : 0.1),
            ),
          ),
          child: Text(text, style: AppType.labelSmall(Colors.white)),
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
    // The label is visible, but a screen reader still needs to know the row
    // is actionable.
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 54.h,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.lg.r),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18.sp),
              SizedBox(width: AppSpace.s8.w),
              Text(label, style: AppType.labelLarge(Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  // Keep helpers but ensure they return valid widgets for new style
  Widget _balanceLabel(String text, ColorScheme scheme) {
    return Text(text, style: AppType.money(color: Colors.white, size: 36.sp));
  }

  Widget _balanceShimmer(ColorScheme scheme) => Container(
    width: 120.w,
    height: 36.h,
    decoration: BoxDecoration(
      color: scheme.onSurface.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(AppRadius.sm.r),
    ),
    margin: EdgeInsets.symmetric(vertical: AppSpace.s4.h),
  );
}
