import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' as rendering;
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Animations
import 'package:money_control/Components/balance_card.dart';
import 'package:money_control/Components/adaptive_scaffold.dart';
import 'package:money_control/Components/feature_gate.dart';
import 'package:money_control/l10n/app_localizations.dart';

import 'package:money_control/Components/methods.dart';
import 'package:money_control/Components/profile_avatar.dart';
import 'package:money_control/Services/performance_controller.dart';

import 'package:money_control/Controllers/profile_controller.dart';
import 'package:money_control/Components/quick_send.dart';
import 'package:money_control/Components/recent_payment_list.dart';
import 'package:money_control/Components/section_title.dart';
import 'package:money_control/Screens/cateogaries_history.dart';
import 'package:money_control/Screens/edit_profile.dart';
import 'package:money_control/Screens/forecast_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:money_control/Screens/transaction_history.dart';
import 'package:money_control/Screens/transaction_search.dart';
import 'package:money_control/Screens/recurring_payments_screen.dart';
import 'package:money_control/Screens/lent_money_screen.dart';
import 'package:money_control/Screens/goals_screen.dart';
import 'package:money_control/Screens/savings_challenges_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 🔥 import background worker
import 'package:money_control/Services/background_worker.dart';
import 'package:flutter/foundation.dart';
import 'package:money_control/Controllers/tutorial_controller.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:get/get.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Controllers/subscription_controller.dart';
import 'package:money_control/Screens/subscription_screen.dart';
import 'package:money_control/Screens/upi_payment_screen.dart';
import 'package:money_control/Screens/qr_scan_screen.dart';
import 'package:money_control/Utils/upi_qr.dart';
import 'package:money_control/Services/error_handler.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:money_control/Utils/responsive.dart';

class BankingHomeScreen extends StatefulWidget {
  final bool showNavigation;
  const BankingHomeScreen({super.key, this.showNavigation = true});

  @override
  State<BankingHomeScreen> createState() => _BankingHomeScreenState();
}

class _BankingHomeScreenState extends State<BankingHomeScreen> {
  late final ProfileController _profileController;
  late final TransactionController _transactionController;

  final ValueNotifier<bool> _isBottomBarVisible = ValueNotifier(true);

  final GlobalKey _keyTransactionList = GlobalKey();
  final GlobalKey _keyNavBar = GlobalKey();

  @override
  void dispose() {
    _isBottomBarVisible.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<ProfileController>()) {
      Get.put(ProfileController());
    }
    _profileController = Get.find<ProfileController>();
    if (!Get.isRegistered<TransactionController>()) {
      Get.put(TransactionController());
    }
    _transactionController = Get.find<TransactionController>();
    _updateLastOpenedLocal();

    // Start WorkManager & Tutorial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!kIsWeb) BackgroundWorker.init();
      TutorialController.showHomeTutorial(
        context,
        keyTransactionList: _keyTransactionList,
        keyNavBar: _keyNavBar,
      );
    });
  }

  /// Save last time the home screen was opened AND user email for background tasks
  Future<void> _updateLastOpenedLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("lastOpened", DateTime.now().millisecondsSinceEpoch);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final email = user.email;
      if (email != null) await prefs.setString("user_email", email);
      await prefs.setString("user_uid", user.uid);
    }
  }

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    await _updateLastOpenedLocal();
    await _transactionController.refreshData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    // Lite mode: skip entrance animations entirely (reduced jank + battery).
    final liteMode = PerformanceController.to.liteMode.value;

    return AdaptiveScaffold(
      currentTab: 'home',
      isVisible: widget.showNavigation ? _isBottomBarVisible : null,
      navBarKey: widget.showNavigation ? _keyNavBar : null,
      showNavigation: widget.showNavigation,
      backgroundColor: Colors.transparent,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark ? AppColors.darkGradient : AppColors.lightGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.only(left: 16.w, top: 2.h, bottom: 2.h),
          child: GestureDetector(
            onTap: () {
              if (!ensureFeatureUsable(context, 'profile')) return;
              gotoPage(const EditProfileScreen());
            },
            child: Obx(() {
              final url = _profileController.photoURL.value;
              return Hero(
                tag: 'profile_pic',
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.onSurface.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                  ),
                  child: AppAvatar(url: url, size: 34.w),
                ),
              );
            }),
          ),
        ),
        title: GestureDetector(
          onTap: () {
            if (!ensureFeatureUsable(context, 'profile')) return;
            gotoPage(const EditProfileScreen());
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)!.welcomeBack,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13.sp,
                  letterSpacing: 0.3,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 2.h),
              Obx(() {
                final userModel = _profileController.userProfile.value;
                if (userModel == null) {
                  return shimmerText(theme);
                }
                final displayName =
                    FirebaseAuth.instance.currentUser?.displayName;
                final name =
                    (userModel.firstName != null &&
                        userModel.firstName!.isNotEmpty)
                    ? userModel.firstName!
                    : (displayName != null && displayName.isNotEmpty
                          ? displayName
                          : 'User');
                return ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: isDark
                        ? const [AppColors.secondary, AppColors.accent]
                        : const [AppColors.primary, AppColors.secondary],
                  ).createShader(bounds),
                  blendMode: BlendMode.srcIn,
                  child: Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18.sp,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          // 💎 PRO STATUS — hidden for admins (they are always Pro)
          Obx(() {
            if (!Get.isRegistered<SubscriptionController>())
              return const SizedBox.shrink();
            final ctrl = Get.find<SubscriptionController>();
            if (ctrl.isAdmin.value) return const SizedBox.shrink();
            return _buildActionButton(
              icon: ctrl.isPro
                  ? Icons.verified_user_rounded
                  : Icons.diamond_outlined,
              onTap: () => gotoPage(const SubscriptionScreen()),
              theme: theme,
              color: ctrl.isPro ? Colors.cyanAccent : null,
            );
          }),
          SizedBox(width: 4.w),

          // 🔍 NEW SEARCH BUTTON
          FeatureVisible(
            flagKey: 'transaction_search',
            child: _buildActionButton(
              icon: Icons.search,
              onTap: () {
                if (!ensureFeatureVisible(context, 'transaction_search')) {
                  return;
                }
                gotoPage(const TransactionSearchPage());
              },
              theme: theme,
              heroTag: 'search_bar',
            ),
          ),
          SizedBox(width: 4.w),

          // 📅 SUBSCRIPTIONS BUTTON
          FeatureVisible(
            flagKey: 'recurring',
            child: _buildActionButton(
              icon: Icons.event_repeat,
              onTap: () {
                if (!Get.isRegistered<SubscriptionController>() ||
                    !Get.find<SubscriptionController>().isPro) {
                  gotoPage(const SubscriptionScreen());
                  return;
                }
                if (!ensureFeatureVisible(context, 'recurring')) return;
                gotoPage(const RecurringPaymentsScreen());
              },
              theme: theme,
            ),
          ),
          SizedBox(width: 4.w),

          // 🤝 LENT MONEY TRACKER BUTTON
          FeatureVisible(
            flagKey: 'lent_money',
            child: _buildActionButton(
              icon: Icons.handshake_outlined,
              onTap: () {
                if (!Get.isRegistered<SubscriptionController>() ||
                    !Get.find<SubscriptionController>().isPro) {
                  gotoPage(const SubscriptionScreen());
                  return;
                }
                if (!ensureFeatureVisible(context, 'lent_money')) return;
                gotoPage(const LentMoneyScreen());
              },
              theme: theme,
              color: Colors.greenAccent,
            ),
          ),
          SizedBox(width: 4.w),

          // 📈 FORECAST BUTTON
          FeatureVisible(
            flagKey: 'forecast',
            child: _buildActionButton(
              icon: Icons.trending_up,
              onTap: () {
                if (!Get.isRegistered<SubscriptionController>() ||
                    !Get.find<SubscriptionController>().isPro) {
                  gotoPage(const SubscriptionScreen());
                  return;
                }
                if (!ensureFeatureVisible(context, 'forecast')) return;
                gotoPage(const ForecastScreen());
              },
              theme: theme,
            ),
          ),
          SizedBox(width: 4.w),

          // 🎯 GOALS BUTTON
          FeatureVisible(
            flagKey: 'goals',
            child: _buildActionButton(
              icon: Icons.flag_outlined,
              onTap: () {
                if (!Get.isRegistered<SubscriptionController>() ||
                    !Get.find<SubscriptionController>().isPro) {
                  gotoPage(const SubscriptionScreen());
                  return;
                }
                if (!ensureFeatureVisible(context, 'goals')) return;
                gotoPage(const GoalsScreen());
              },
              theme: theme,
              color: Colors.amberAccent,
            ),
          ),
          SizedBox(width: 4.w),
          // 🏆 CHALLENGES BUTTON
          FeatureVisible(
            flagKey: 'challenges',
            child: _buildActionButton(
              icon: Icons.emoji_events_outlined,
              onTap: () {
                if (!ensureFeatureVisible(context, 'challenges')) return;
                gotoPage(const SavingsChallengesScreen());
              },
              theme: theme,
              color: Colors.greenAccent,
            ),
          ),
          SizedBox(width: 6.w),
        ],

        toolbarHeight: 64.h,
      ),
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.direction == rendering.ScrollDirection.reverse) {
            if (_isBottomBarVisible.value) _isBottomBarVisible.value = false;
          } else if (notification.direction ==
              rendering.ScrollDirection.forward) {
            if (!_isBottomBarVisible.value) _isBottomBarVisible.value = true;
          }
          return true;
        },
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 100.h),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: Responsive.contentMaxWidth(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      !liteMode
                              ? BalanceCard().animate().fadeIn(duration: 600.ms).slideY(
                                  begin: -0.1,
                                  end: 0,
                                  curve: Curves.easeOutBack,
                                )
                              : BalanceCard(),
                      SizedBox(height: 12.h), // Added some spacing after card
                      FeatureVisible(
                        flagKey: 'category',
                        child:
                            !liteMode
                                  ? SectionTitle(
                                      title: AppLocalizations.of(
                                        context,
                                      )!.quickSend,
                                      color: scheme.onSurface,
                                      accentColor: AppColors.primary,
                                      onTap: () => gotoPage(
                                        const CategoriesHistoryScreen(),
                                      ),
                                    ).animate().fadeIn(delay: 200.ms, duration: 500.ms).slideX(
                                      begin: -0.1,
                                      end: 0,
                                      curve: Curves.easeOut,
                                    )
                                  : SectionTitle(
                                      title: AppLocalizations.of(
                                        context,
                                      )!.quickSend,
                                      color: scheme.onSurface,
                                      accentColor: AppColors.primary,
                                      onTap: () => gotoPage(
                                        const CategoriesHistoryScreen(),
                                      ),
                                    ),
                      ),
                      SizedBox(height: 12.h),
                      FeatureVisible(
                        flagKey: 'upi_pay',
                        child:
                            !liteMode
                                  ? QuickSendRow(
                                      cardColor: isDark
                                          ? AppColors.darkSurface.withValues(
                                              alpha: 0.5,
                                            )
                                          : AppColors.lightSurface.withValues(
                                              alpha: 0.6,
                                            ),
                                      textColor: scheme.onSurface,
                                    ).animate().fadeIn(delay: 300.ms, duration: 500.ms).slideX(
                                      begin: 0.1,
                                      end: 0,
                                      curve: Curves.easeOut,
                                    )
                                  : QuickSendRow(
                                      cardColor: isDark
                                          ? AppColors.darkSurface.withValues(
                                              alpha: 0.5,
                                            )
                                          : AppColors.lightSurface.withValues(
                                              alpha: 0.6,
                                            ),
                                      textColor: scheme.onSurface,
                                    ),
                      ),
                      SizedBox(height: 18.h),
                      !liteMode
                            ? SectionTitle(
                                title: AppLocalizations.of(
                                  context,
                                )!.recentTransactions,
                                color: scheme.onSurface,
                                accentColor: AppColors.primary,
                                onTap: () =>
                                    gotoPage(TransactionHistoryScreen()),
                              ).animate().fadeIn(delay: 400.ms, duration: 500.ms).slideY(
                                begin: 0.2,
                                end: 0,
                                curve: Curves.easeOut,
                              )
                            : SectionTitle(
                                title: AppLocalizations.of(
                                  context,
                                )!.recentTransactions,
                                color: scheme.onSurface,
                                accentColor: AppColors.primary,
                                onTap: () =>
                                    gotoPage(TransactionHistoryScreen()),
                              ),
                      SizedBox(height: 12.h),
                      !liteMode
                            ? RecentPaymentList(
                                key: _keyTransactionList,
                                cardColor: isDark
                                    ? AppColors.darkSurface.withValues(alpha: 0.5)
                                    : AppColors.lightSurface.withValues(alpha: 0.6),
                                textColor: scheme.onSurface,
                                receivedColor: AppColors.success,
                                sentColor: AppColors.error,
                              ).animate().fadeIn(delay: 500.ms, duration: 600.ms).slideY(
                                begin: 0.1,
                                end: 0,
                                curve: Curves.easeOut,
                              )
                            : RecentPaymentList(
                                key: _keyTransactionList,
                                cardColor: isDark
                                    ? AppColors.darkSurface.withValues(alpha: 0.5)
                                    : AppColors.lightSurface.withValues(alpha: 0.6),
                                textColor: scheme.onSurface,
                                receivedColor: AppColors.success,
                                sentColor: AppColors.error,
                              ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FeatureVisible(
        flagKey: 'qr_scan',
        child: FloatingActionButton(
          backgroundColor: AppColors.primary,
          tooltip: 'Scan QR to Pay',
          onPressed: () {
            HapticFeedback.lightImpact();
            if (!Get.isRegistered<SubscriptionController>() ||
                !Get.find<SubscriptionController>().isPro) {
              gotoPage(const SubscriptionScreen());
              return;
            }
            if (!ensureFeatureVisible(context, 'qr_scan')) return;
            _openQrPay();
          },
          child: const Icon(Icons.qr_code_scanner, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      extendBody: true,
    );
  }

  Future<void> _openQrPay() async {
    if (kIsWeb) {
      ErrorHandler.showError("QR scan & UPI pay is not available in browser.");
      return;
    }

    var status = await Permission.camera.status;
    if (!mounted) return;

    if (status.isPermanentlyDenied || status.isRestricted) {
      await _showCameraSettingsDialog();
      return;
    }
    if (!status.isGranted && !status.isLimited) {
      status = await Permission.camera.request();
      if (!mounted) return;
    }
    if (!status.isGranted && !status.isLimited) {
      ErrorHandler.showError(
        "Camera permission is required to scan a UPI QR code.",
      );
      return;
    }

    final data = await Get.to<UpiQrData>(() => const QrScanScreen());
    if (data == null) return;

    await Get.to(
      () => UpiPaymentScreen(
        initialVpa: data.isManual ? null : data.vpa,
        initialName: data.name,
        initialAmount: data.amount,
        initialNote: data.note,
      ),
    );
  }

  Future<void> _showCameraSettingsDialog() async {
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Camera permission required"),
        content: const Text(
          "WealthSync needs camera access to scan UPI QR codes. "
          "Open Settings to grant it.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
    if (open == true && mounted) {
      await openAppSettings();
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required ThemeData theme,
    String? heroTag,
    Color? color,
  }) {
    Widget content = Icon(
      icon,
      color: color ?? theme.colorScheme.onSurface.withValues(alpha: 0.8),
      size: 22.sp,
    );

    if (heroTag != null) {
      content = Hero(tag: heroTag, child: content);
    }

    return GlassContainer(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(22.r),
      width: 38.w,
      height: 36.h,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: content,
    );
  }

  Widget shimmerText(ThemeData theme) => Text(
    '...',
    style: theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.bold,
      fontSize: 16.sp,
    ),
  );

  Widget blankText(ThemeData theme) => Text(
    'User',
    style: theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.bold,
      fontSize: 16.sp,
    ),
  );
}
