import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' as rendering;
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Animations
import 'package:money_control/Components/balance_card.dart';
import 'package:money_control/Components/animated_bottom_nav.dart';
import 'package:money_control/l10n/app_localizations.dart';

import 'package:money_control/Components/methods.dart';

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
import 'package:money_control/Screens/add_transaction_from_recipt.dart';

class BankingHomeScreen extends StatefulWidget {
  const BankingHomeScreen({super.key});

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
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Padding(
            padding: EdgeInsets.only(left: 16.w, top: 2.h, bottom: 2.h),
            child: GestureDetector(
              onTap: () => gotoPage(const EditProfileScreen()),
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
                      image: DecorationImage(
                        image: url.isNotEmpty
                            ? CachedNetworkImageProvider(url)
                            : const AssetImage('assets/profile.png')
                                  as ImageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Container(
                      width: 34.w,
                      height: 34.w,
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                    ),
                  ),
                );
              }),
            ),
          ),
          title: GestureDetector(
            onTap: () => gotoPage(const EditProfileScreen()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.welcomeBack,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Obx(() {
                  final userModel = _profileController.userProfile.value;
                  if (userModel == null) {
                    return shimmerText(theme);
                  }
                  final displayName = FirebaseAuth.instance.currentUser?.displayName;
                  return Text(
                    (userModel.firstName != null && userModel.firstName!.isNotEmpty)
                        ? userModel.firstName!
                        : (displayName != null && displayName.isNotEmpty
                              ? displayName
                              : 'User'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
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
              if (!Get.isRegistered<SubscriptionController>()) return const SizedBox.shrink();
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
            _buildActionButton(
              icon: Icons.search,
              onTap: () => gotoPage(const TransactionSearchPage()),
              theme: theme,
              heroTag: 'search_bar',
            ),
            SizedBox(width: 4.w),

            // 📅 SUBSCRIPTIONS BUTTON
            _buildActionButton(
              icon: Icons.event_repeat,
              onTap: () {
                if (!Get.isRegistered<SubscriptionController>() || !Get.find<SubscriptionController>().isPro) {
                  gotoPage(const SubscriptionScreen());
                  return;
                }
                gotoPage(const RecurringPaymentsScreen());
              },
              theme: theme,
            ),
            SizedBox(width: 4.w),

            // 🤝 LENT MONEY TRACKER BUTTON
            _buildActionButton(
              icon: Icons.handshake_outlined,
              onTap: () {
                if (!Get.isRegistered<SubscriptionController>() || !Get.find<SubscriptionController>().isPro) {
                  gotoPage(const SubscriptionScreen());
                  return;
                }
                gotoPage(const LentMoneyScreen());
              },
              theme: theme,
              color: Colors.greenAccent,
            ),
            SizedBox(width: 4.w),

            // 📈 FORECAST BUTTON
            _buildActionButton(
              icon: Icons.trending_up,
              onTap: () {
                if (!Get.isRegistered<SubscriptionController>() || !Get.find<SubscriptionController>().isPro) {
                  gotoPage(const SubscriptionScreen());
                  return;
                }
                gotoPage(const ForecastScreen());
              },
              theme: theme,
            ),
            SizedBox(width: 4.w),

            // 🎯 GOALS BUTTON
            _buildActionButton(
              icon: Icons.flag_outlined,
              onTap: () {
                if (!Get.isRegistered<SubscriptionController>() || !Get.find<SubscriptionController>().isPro) {
                  gotoPage(const SubscriptionScreen());
                  return;
                }
                gotoPage(const GoalsScreen());
              },
              theme: theme,
              color: Colors.amberAccent,
            ),
            SizedBox(width: 4.w),
            // 🏆 CHALLENGES BUTTON
            _buildActionButton(
              icon: Icons.emoji_events_outlined,
              onTap: () => gotoPage(const SavingsChallengesScreen()),
              theme: theme,
              color: Colors.greenAccent,
            ),
            SizedBox(width: 6.w),
          ],

          toolbarHeight: 64.h,
        ),
        bottomNavigationBar: AnimatedBottomNav(
          currentIndex: 0,
          isVisible: _isBottomBarVisible,
          navBarKey: _keyNavBar,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BalanceCard()
                        .animate()
                        .fadeIn(duration: 600.ms)
                        .slideY(begin: -0.1, end: 0, curve: Curves.easeOutBack),
                    SizedBox(height: 12.h), // Added some spacing after card
                    SectionTitle(
                          title: AppLocalizations.of(context)!.quickSend,
                          color: scheme.onSurface,
                          accentColor: AppColors.primary,
                          onTap: () =>
                              gotoPage(const CategoriesHistoryScreen()),
                        )
                        .animate()
                        .fadeIn(delay: 200.ms, duration: 500.ms)
                        .slideX(begin: -0.1, end: 0, curve: Curves.easeOut),
                    SizedBox(height: 12.h),
                    QuickSendRow(
                          cardColor: isDark
                              ? AppColors.darkSurface.withValues(alpha: 0.5)
                              : AppColors.lightSurface.withValues(alpha: 0.6),
                          textColor: scheme.onSurface,
                        )
                        .animate()
                        .fadeIn(delay: 300.ms, duration: 500.ms)
                        .slideX(begin: 0.1, end: 0, curve: Curves.easeOut),
                    SizedBox(height: 18.h),
                    SectionTitle(
                          title: AppLocalizations.of(
                            context,
                          )!.recentTransactions,
                          color: scheme.onSurface,
                          accentColor: AppColors.primary,
                          onTap: () => gotoPage(TransactionHistoryScreen()),
                        )
                        .animate()
                        .fadeIn(delay: 400.ms, duration: 500.ms)
                        .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
                    SizedBox(height: 12.h),
                    RecentPaymentList(
                          key: _keyTransactionList,
                          cardColor: isDark
                              ? AppColors.darkSurface.withValues(alpha: 0.5)
                              : AppColors.lightSurface.withValues(alpha: 0.6),
                          textColor: scheme.onSurface,
                          receivedColor: AppColors.success,
                          sentColor: AppColors.error,
                        )
                        .animate()
                        .fadeIn(delay: 500.ms, duration: 600.ms)
                        .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
                  ],
                ),
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.primary,
          tooltip: 'Scan Receipt',
          onPressed: () {
            HapticFeedback.lightImpact();
            if (!Get.isRegistered<SubscriptionController>() || !Get.find<SubscriptionController>().isPro) {
              gotoPage(const SubscriptionScreen());
              return;
            }
            Get.to(() => const ReceiptScanPage(), transition: Transition.downToUp);
          },
          child: const Icon(Icons.document_scanner_outlined, color: Colors.white),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        extendBody: true,
      ),
    );
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
