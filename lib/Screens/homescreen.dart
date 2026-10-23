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
import 'package:money_control/Utils/platform_support.dart';
import 'package:money_control/Config/app_strings.dart';
import 'package:money_control/Services/feature_flag_service.dart';

/// The Pro shortcuts that live behind the home AppBar's overflow menu.
enum _HomeAction { recurring, lentMoney, forecast, goals, challenges }

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
    // Shared translucent card fill for the home sections.
    final cardTint = isDark
        ? AppColors.darkSurface.withValues(alpha: 0.5)
        : AppColors.lightSurface.withValues(alpha: 0.6);

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
          child: Semantics(
            button: true,
            label: AppLocalizations.of(context)!.a11yProfilePhoto,
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
        ),
        // The greeting is a header, not a second profile button: tapping the
        // avatar already opens the profile, and giving two adjacent controls the
        // same label made a screen reader announce the name as a duplicate.
        title: Semantics(
          header: true,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context)!.welcomeBack,
              style: theme.textTheme.bodySmall?.copyWith(letterSpacing: 0.3),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: AppSpace.s2.h),
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
              // No ShaderMask: it renders the child through an offscreen layer
              // on every frame. A solid on-surface colour is the same visual
              // hierarchy for a name that never animates.
              return Text(
                name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            }),
          ],
          ),
        ),
        actions: [
          // 💎 PRO STATUS — hidden for admins (they are always Pro)
          Obx(() {
            if (!Get.isRegistered<SubscriptionController>()) {
              return const SizedBox.shrink();
            }
            final ctrl = Get.find<SubscriptionController>();
            if (ctrl.isAdmin.value) return const SizedBox.shrink();
            return _buildActionButton(
              icon: ctrl.isPro
                  ? Icons.verified_user_rounded
                  : Icons.diamond_outlined,
              onTap: () => gotoPage(const SubscriptionScreen()),
              theme: theme,
              color: ctrl.isPro ? AppColors.success : AppColors.primary,
              semanticLabel: AppLocalizations.of(context)!.a11yProStatus,
            );
          }),

          // 🔍 SEARCH — the one shortcut that stays in the bar. The five Pro
          // feature entries moved into the overflow menu: seven 38-w pills plus
          // the avatar left ~28 pt for the greeting on a 390 pt screen, so the
          // name was being clipped to nothing.
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
              semanticLabel: AppLocalizations.of(context)!
                  .a11ySearchTransactions,
            ),
          ),

          // 📂 Pro feature shortcuts. FeatureSection drops the whole menu when
          // an admin has hidden every entry, so the bar never keeps an empty
          // affordance.
          FeatureSection(
            flagKeys: const [
              'recurring',
              'lent_money',
              'forecast',
              'goals',
              'challenges',
            ],
            child: _buildOverflowMenu(context, theme),
          ),
          SizedBox(width: AppSpace.s4.w),
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
                      _entrance(
                        liteMode: liteMode,
                        duration: const Duration(milliseconds: 600),
                        begin: const Offset(0, -0.1),
                        curve: Curves.easeOutBack,
                        child: BalanceCard(),
                      ),
                      SizedBox(height: AppSpace.s12.h),
                      FeatureVisible(
                        flagKey: 'category',
                        child: _entrance(
                          liteMode: liteMode,
                          delay: const Duration(milliseconds: 200),
                          begin: const Offset(-0.1, 0),
                          child: SectionTitle(
                            title: AppStrings.categoryHistoryTitle,
                            color: scheme.onSurface,
                            accentColor: AppColors.primary,
                            onTap: () =>
                                gotoPage(const CategoriesHistoryScreen()),
                          ),
                        ),
                      ),
                      SizedBox(height: AppSpace.s12.h),
                      FeatureVisible(
                        flagKey: 'upi_pay',
                        child: _entrance(
                          liteMode: liteMode,
                          delay: const Duration(milliseconds: 300),
                          begin: const Offset(0.1, 0),
                          child: QuickSendRow(
                            cardColor: cardTint,
                            textColor: scheme.onSurface,
                          ),
                        ),
                      ),
                      SizedBox(height: AppSpace.s20.h),
                      _entrance(
                        liteMode: liteMode,
                        delay: const Duration(milliseconds: 400),
                        begin: const Offset(0, 0.2),
                        child: SectionTitle(
                          title: AppLocalizations.of(
                            context,
                          )!.recentTransactions,
                          color: scheme.onSurface,
                          accentColor: AppColors.primary,
                          onTap: () => gotoPage(TransactionHistoryScreen()),
                        ),
                      ),
                      SizedBox(height: AppSpace.s12.h),
                      _entrance(
                        liteMode: liteMode,
                        delay: const Duration(milliseconds: 500),
                        duration: const Duration(milliseconds: 600),
                        begin: const Offset(0, 0.1),
                        child: RecentPaymentList(
                          key: _keyTransactionList,
                          cardColor: cardTint,
                          textColor: scheme.onSurface,
                          receivedColor: AppColors.success,
                          sentColor: AppColors.error,
                        ),
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
          // The tooltip is also the button's semantic label, so it has to be
          // localized like any other visible copy.
          tooltip: AppLocalizations.of(context)!.a11yScanQrToPay,
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
    if (!isAndroidPlatform) {
      // The scanner is an Android-only camera flow and the UPI hand-off is a
      // Kotlin MethodChannel, so this is unavailable on web and iOS alike.
      ErrorHandler.showError(
        kIsWeb
            ? "QR scan & UPI pay is not available in browser."
            : "QR scan & UPI pay is only available on Android.",
      );
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
        title: Text(AppLocalizations.of(context)!.cameraPermissionRequired),
        content: Text(
          AppLocalizations.of(context)!.wealthsyncNeedsCameraAccessScan,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
            child: Text(AppLocalizations.of(context)!.openSettings),
          ),
        ],
      ),
    );
    if (open == true && mounted) {
      await openAppSettings();
    }
  }

  /// Home section entrance; a no-op in lite mode.
  ///
  /// Each section used to repeat the same `!liteMode ? child.animate()… : child`
  /// ternary, which duplicated every child's argument list twice and had already
  /// drifted (200/300/400/500 ms delays, two different slide axes, easeOut vs
  /// easeOutBack). The fade keeps the default curve — an overshoot curve on
  /// opacity would push alpha past 1.
  Widget _entrance({
    required Widget child,
    required bool liteMode,
    Duration delay = Duration.zero,
    Duration duration = const Duration(milliseconds: 500),
    Offset begin = const Offset(0, 0.1),
    Curve curve = Curves.easeOut,
  }) {
    if (liteMode) return child;
    return child
        .animate()
        .fadeIn(delay: delay, duration: duration)
        .slide(begin: begin, end: Offset.zero, curve: curve);
  }

  /// The visual pill stays 38x36, but the tappable area is a full 48x48 so the
  /// AppBar shortcuts meet the minimum touch target (they were 38x36).
  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required ThemeData theme,
    required String semanticLabel,
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

    // Every one of these is an icon-only button, so without a label a screen
    // reader announces them all as the same anonymous "button".
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: SizedBox(
          width: 48.w,
          height: 48.h,
          child: Center(
            child: GlassContainer(
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(AppRadius.xl.r),
              width: 38.w,
              height: 36.h,
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );
  }

  /// Secondary shortcuts. Rebuilt on open, so an admin flipping a flag is
  /// reflected the next time the menu is opened without restarting the app.
  Widget _buildOverflowMenu(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;

    return PopupMenuButton<_HomeAction>(
      tooltip: l10n.a11yMoreActions,
      icon: Icon(
        Icons.more_vert,
        size: 22.sp,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
      ),
      onOpened: () => HapticFeedback.selectionClick(),
      onSelected: _runHomeAction,
      itemBuilder: (context) {
        final flags = FeatureFlagService.to;
        final entries = <PopupMenuEntry<_HomeAction>>[];

        void add({
          required _HomeAction action,
          required IconData icon,
          required String label,
          required String flagKey,
        }) {
          if (flags.isHidden(flagKey)) return;
          entries.add(
            PopupMenuItem<_HomeAction>(
              value: action,
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 20.sp,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(width: AppSpace.s12.w),
                  Text(label, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
          );
        }

        add(
          action: _HomeAction.recurring,
          icon: Icons.event_repeat,
          label: l10n.a11yRecurringPayments,
          flagKey: 'recurring',
        );
        add(
          action: _HomeAction.lentMoney,
          icon: Icons.handshake_outlined,
          label: l10n.a11yLentMoney,
          flagKey: 'lent_money',
        );
        add(
          action: _HomeAction.forecast,
          icon: Icons.trending_up,
          label: l10n.a11ySpendingForecast,
          flagKey: 'forecast',
        );
        add(
          action: _HomeAction.goals,
          icon: Icons.flag_outlined,
          label: l10n.a11ySavingsGoals,
          flagKey: 'goals',
        );
        add(
          action: _HomeAction.challenges,
          icon: Icons.emoji_events_outlined,
          label: l10n.a11ySavingsChallenges,
          flagKey: 'challenges',
        );

        return entries;
      },
    );
  }

  /// Every entry except Challenges is Pro-only: tapping it while on the free
  /// plan opens the paywall instead, exactly as the old AppBar pills did.
  bool _requirePro() {
    if (!Get.isRegistered<SubscriptionController>() ||
        !Get.find<SubscriptionController>().isPro) {
      gotoPage(const SubscriptionScreen());
      return false;
    }
    return true;
  }

  void _runHomeAction(_HomeAction action) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    switch (action) {
      case _HomeAction.recurring:
        if (!_requirePro()) return;
        if (!ensureFeatureVisible(context, 'recurring')) return;
        gotoPage(const RecurringPaymentsScreen());
        return;
      case _HomeAction.lentMoney:
        if (!_requirePro()) return;
        if (!ensureFeatureVisible(context, 'lent_money')) return;
        gotoPage(const LentMoneyScreen());
        return;
      case _HomeAction.forecast:
        if (!_requirePro()) return;
        if (!ensureFeatureVisible(context, 'forecast')) return;
        gotoPage(const ForecastScreen());
        return;
      case _HomeAction.goals:
        if (!_requirePro()) return;
        if (!ensureFeatureVisible(context, 'goals')) return;
        gotoPage(const GoalsScreen());
        return;
      case _HomeAction.challenges:
        if (!ensureFeatureVisible(context, 'challenges')) return;
        gotoPage(const SavingsChallengesScreen());
        return;
    }
  }

  Widget shimmerText(ThemeData theme) => Text(
    '...',
    style: theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.bold,
      fontSize: 16.sp,
    ),
  );
}
