import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:money_control/Components/adaptive_scaffold.dart';
import 'package:money_control/Components/feature_gate.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Config/app_strings.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/privacy_controller.dart';
import 'package:money_control/Models/wealth_data.dart';
import 'package:money_control/Services/wealth_service.dart';
import 'package:money_control/Utils/wealth_math.dart';
import 'package:money_control/Components/skeleton_loader.dart';
import 'package:money_control/Services/wealth_age_recommendations.dart';

import 'package:intl/intl.dart';

import 'package:flutter/rendering.dart' as rendering;

import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Controllers/profile_controller.dart';
import 'package:money_control/Models/user_model.dart';
import 'package:money_control/Controllers/loan_controller.dart';
import 'package:money_control/Screens/loan_tracker_screen.dart';
import 'package:money_control/Screens/credit_card_detail_screen.dart';
import 'package:money_control/Screens/insurance_policy_screen.dart';
import 'package:money_control/Screens/vehicle_detail_screen.dart';
import 'package:money_control/Screens/real_estate_detail_screen.dart';
import 'package:money_control/Screens/asset_detail_screen.dart';
import 'package:money_control/Config/asset_screen_configs.dart';
import 'package:money_control/Services/geo_service.dart';
import 'package:money_control/Screens/edit_profile.dart';
import 'package:money_control/Utils/responsive.dart';
import 'package:money_control/main.dart' show rootScaffoldMessengerKey;
import 'package:get/get.dart';

class WealthBuilderScreen extends StatefulWidget {
  final bool showNavigation;
  const WealthBuilderScreen({super.key, this.showNavigation = true});

  @override
  State<WealthBuilderScreen> createState() => _WealthBuilderScreenState();
}

class _WealthBuilderScreenState extends State<WealthBuilderScreen> {
  bool loading = true;
  WealthPortfolio? portfolio;
  double bankBalance = 0;
  Map<String, WealthTarget> assetTargets = {};
  List<Map<String, dynamic>> smartInsights = [];
  int? userAge;
  GeoResult? geoResult;
  double actualMonthlyIncome = 0;
  final ValueNotifier<bool> _isBottomBarVisible = ValueNotifier(true);
  bool _ageBasedEnabled = false;
  bool _agePromptChecked = false;
  Set<String> _recommendedKeys = {};
  StreamSubscription<WealthPortfolio>? _portfolioSub;
  StreamSubscription<UserModel?>? _profileSub;

  @override
  void initState() {
    super.initState();
    _portfolioSub = WealthService.streamPortfolio().listen((p) {
      if (mounted) setState(() => portfolio = p);
    }, onError: (e) => debugPrint('WealthBuilder portfolio stream error: $e'));
    _initProfileListener();
    _loadData();
  }

  @override
  void dispose() {
    _portfolioSub?.cancel();
    _profileSub?.cancel();
    _isBottomBarVisible.dispose();
    super.dispose();
  }

  // The profile may arrive late (async Firestore fetch) or be edited after the
  // initial load — re-run the load once an age becomes available so the age
  // gate clears without a manual reload.
  void _initProfileListener() {
    if (!Get.isRegistered<ProfileController>()) return;
    _profileSub = Get.find<ProfileController>().userProfile.listen((profile) {
      if (!mounted) return;
      if (userAge == null && profile?.calculatedAge != null) {
        _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    try {
      if (!Get.isRegistered<TransactionController>()) return;
      if (!Get.isRegistered<ProfileController>()) return;
      final TransactionController txController = Get.find();
      final ProfileController profileController = Get.find();

      // Wait for transactions to finish loading before computing portfolio
      if (txController.isLoading.value) {
        await Future.any([
          txController.isLoading.stream.firstWhere((loading) => !loading),
          Future.delayed(const Duration(seconds: 5)),
        ]);
      }

      final p = await WealthService.getPortfolio();

      final transactions = txController.transactions;
      final userProfile = profileController.userProfile.value;

      // Run geo fetch in parallel with other calculations; never blocks main data
      final Future<GeoResult> geoFuture = GeoService.getCached().then(
        (cached) async => cached ?? await GeoService.fetchAndCache(),
      );

      final balance = WealthService.calculateBankBalance(transactions);
      final insights = WealthService.generateSmartInsights(p, transactions);
      final actualIncome = WealthService.calculateAverageMonthlyIncome(
        transactions,
      );

      // Use cached geo if available immediately, else baseline for first render
      final GeoResult? quickGeo = await GeoService.getCached();
      final targets = await WealthService.calculateAssetTargets(
        p,
        transactions,
        userProfile,
        baselineMonthlyIncome: quickGeo?.baselineMonthlyIncome ?? 25000,
        bankBalance: balance,
      );

      final age = userProfile?.calculatedAge;

      // Load age-based preference and check prompt
      final ageBasedEnabled =
          await WealthAgeRecommendations.isAgeBasedEnabled();
      final promptShown = await WealthAgeRecommendations.isAgePromptShown();
      bool showPrompt = !promptShown && age != null && !_agePromptChecked;

      if (mounted) {
        setState(() {
          portfolio = p;
          bankBalance = balance;
          smartInsights = insights;
          assetTargets = targets;
          actualMonthlyIncome = actualIncome;
          userAge = age;
          geoResult = quickGeo;
          _ageBasedEnabled = ageBasedEnabled;
          _agePromptChecked = true;
          _recommendedKeys = age != null
              ? WealthAgeRecommendations.getRecommendedCardKeys(age)
              : {};
          loading = false;
        });

        // Show age prompt after initial data load
        if (showPrompt) {
          _showAgePromptIfEligible();
        }
      }

      // Once geo resolves (may take a few seconds for GPS), refresh targets
      final GeoResult liveGeo = await geoFuture;
      if (mounted &&
          liveGeo.baselineMonthlyIncome !=
              (quickGeo?.baselineMonthlyIncome ?? 25000)) {
        final updatedTargets = await WealthService.calculateAssetTargets(
          p,
          transactions,
          userProfile,
          baselineMonthlyIncome: liveGeo.baselineMonthlyIncome,
          bankBalance: bankBalance,
        );
        if (mounted) {
          setState(() {
            assetTargets = updatedTargets;
            geoResult = liveGeo;
          });
        }
      } else if (mounted && geoResult == null && liveGeo.city.isNotEmpty) {
        setState(() => geoResult = liveGeo);
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          rootScaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('Failed to load wealth data. Pull down to retry.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        });
      }
    }
  }

  Future<void> _showAgePromptIfEligible() async {
    if (userAge == null) return;
    final enabled = await WealthAgeRecommendations.showAgePrompt(context);
    await WealthAgeRecommendations.markAgePromptShown();
    if (mounted) {
      setState(() {
        _ageBasedEnabled = enabled;
        WealthAgeRecommendations.setAgeBasedEnabled(enabled);
        _recommendedKeys = enabled
            ? WealthAgeRecommendations.getRecommendedCardKeys(userAge!)
            : {};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final gradientColors = isDark
        ? [
            AppColors.darkBackground,
            AppColors.darkSurface.withValues(alpha: 0.95),
          ]
        : [AppColors.lightBackground, AppColors.lightBorder];

    return FeatureGate(
      flagKey: 'wealth',
      child: AdaptiveScaffold(
      currentTab: 'wealth',
      isVisible: widget.showNavigation ? _isBottomBarVisible : null,
      showNavigation: widget.showNavigation,
      backgroundColor: Colors.transparent,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      appBar: AppBar(
        title: Text(
          "Wealth Builder",
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      extendBody: true,
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
        child: loading
            ? const WealthSkeleton()
            : (userAge == null
                  ? _buildAgeBlocker(scheme)
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: AppColors.primary,
                      backgroundColor: AppColors.darkBackground,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: Responsive.contentMaxWidth(context),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            child: CustomScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                if (userAge != null)
                                  SliverFeatureVisible(
                                    flagKey: 'custom_mode',
                                    sliver: SliverToBoxAdapter(
                                      child: _buildAgeStrategyBanner(),
                                    ),
                                  ),
                                if (geoResult != null &&
                                    geoResult!.city.isNotEmpty)
                                  SliverToBoxAdapter(
                                    child: _buildGeoBadge(geoResult!),
                                  ),
                                SliverToBoxAdapter(
                                  child: SizedBox(height: 8.h),
                                ),
                                SliverFeatureVisible(
                                  flagKey: 'total_net_worth',
                                  sliver: SliverToBoxAdapter(
                                    child: _buildNetWorthCard(scheme),
                                  ),
                                ),
                                SliverToBoxAdapter(
                                  child: SizedBox(height: 20.h),
                                ),
                                SliverFeatureVisible(
                                  flagKey: 'wealth_assets',
                                  sliver: SliverToBoxAdapter(
                                    child: _buildAssetsHeader(scheme),
                                  ),
                                ),
                                SliverFeatureVisible(
                                  flagKey: 'wealth_assets',
                                  sliver: SliverToBoxAdapter(
                                    child: SizedBox(height: 10.h),
                                  ),
                                ),
                                ..._buildAssetSlivers(scheme).map(
                                  (s) => SliverFeatureVisible(
                                    flagKey: 'wealth_assets',
                                    sliver: s,
                                  ),
                                ),
                                SliverToBoxAdapter(
                                  child: SizedBox(height: 20.h),
                                ),
                                SliverFeatureVisible(
                                  flagKey: 'allocation',
                                  sliver: SliverToBoxAdapter(
                                    child: Text(
                                      "Allocation",
                                      style: TextStyle(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.bold,
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                                SliverFeatureVisible(
                                  flagKey: 'allocation',
                                  sliver: SliverToBoxAdapter(
                                    child: SizedBox(height: 10.h),
                                  ),
                                ),
                                SliverFeatureVisible(
                                  flagKey: 'allocation',
                                  sliver: SliverToBoxAdapter(
                                    child: _buildPieChart(scheme),
                                  ),
                                ),
                                SliverToBoxAdapter(
                                  child: SizedBox(height: 20.h),
                                ),
                                SliverFeatureVisible(
                                  flagKey: 'ideal_income',
                                  sliver: SliverToBoxAdapter(
                                    child: Text(
                                      "Ideal Income",
                                      style: TextStyle(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.bold,
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                                SliverFeatureVisible(
                                  flagKey: 'ideal_income',
                                  sliver: SliverToBoxAdapter(
                                    child: SizedBox(height: 10.h),
                                  ),
                                ),
                                SliverFeatureVisible(
                                  flagKey: 'ideal_income',
                                  sliver: SliverToBoxAdapter(
                                    child: _buildIdealIncomeCard(scheme),
                                  ),
                                ),
                                SliverToBoxAdapter(
                                  child: SizedBox(height: 20.h),
                                ),
                                SliverFeatureVisible(
                                  flagKey: 'smart_suggestions',
                                  sliver: SliverToBoxAdapter(
                                    child: Text(
                                      "Smart Suggestions",
                                      style: TextStyle(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.bold,
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                                SliverFeatureVisible(
                                  flagKey: 'smart_suggestions',
                                  sliver: SliverToBoxAdapter(
                                    child: SizedBox(height: 10.h),
                                  ),
                                ),
                                SliverFeatureVisible(
                                  flagKey: 'smart_suggestions',
                                  sliver: SliverToBoxAdapter(
                                    child: _buildSuggestions(scheme),
                                  ),
                                ),
                                SliverToBoxAdapter(
                                  child: SizedBox(
                                    height:
                                        (Responsive.isTablet(context) &&
                                            Responsive.isLandscape(context))
                                        ? 20.h
                                        : 100.h,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )),
      ),
      ),
    );
  }

  Widget _buildAgeBlocker(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cake_outlined,
                size: 56.sp,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              "Set Your Age First",
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              "Wealth Builder personalises every target — emergency fund, equity allocation, retirement corpus — based on your age.\n\nAdd your date of birth in your profile to get started.",
              style: TextStyle(
                fontSize: 14.sp,
                color: scheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Get.to(() => const EditProfileScreen());
                  // Re-load after returning in case user set their DOB
                  _loadData();
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text("Go to Profile"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgeStrategyBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: _ageBasedEnabled
            ? AppColors.primary.withValues(alpha: 0.1)
            : isDark
                ? Colors.white.withValues(alpha: 0.05)
                : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: _ageBasedEnabled
              ? AppColors.primary.withValues(alpha: 0.3)
              : isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : AppColors.lightBorder.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _ageBasedEnabled ? Icons.auto_awesome : Icons.cake_outlined,
            color: _ageBasedEnabled
                ? AppColors.primary
                : isDark
                    ? AppColors.primary
                    : AppColors.secondary,
            size: 18.sp,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              _ageBasedEnabled
                  ? "Smart Mode · Age $userAge"
                  : "Custom Mode · Age $userAge",
              style: TextStyle(
                color: _ageBasedEnabled
                    ? AppColors.primary
                    : isDark
                        ? Colors.white60
                        : AppColors.lightTextSecondary,
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            width: 40.w,
            height: 24.h,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Switch(
                value: _ageBasedEnabled,
                activeThumbColor: AppColors.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (val) {
                  setState(() {
                    _ageBasedEnabled = val;
                    _recommendedKeys = (val && userAge != null)
                        ? WealthAgeRecommendations.getRecommendedCardKeys(
                            userAge!,
                          )
                        : {};
                  });
                  WealthAgeRecommendations.setAgeBasedEnabled(val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeoBadge(GeoResult geo) {
    const zoneColor = AppColors.success;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: zoneColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: zoneColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_on_outlined, color: zoneColor, size: 18.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  geo.displayLocation,
                  style: TextStyle(
                    color: zoneColor,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${geo.zoneName} · ${geo.zoneDescription}',
                  style: TextStyle(
                    color: zoneColor.withValues(alpha: 0.8),
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: zoneColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: PrivacyText(
              '~${CurrencyController.to.currencySymbol.value}${(geo.baselineMonthlyIncome / 1000).toStringAsFixed(0)}K/mo',
              style: TextStyle(
                color: zoneColor,
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetsHeader(ColorScheme scheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _ageBasedEnabled ? "Recommended for You" : "Your Assets",
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_ageBasedEnabled)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  "Smart Mode",
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            if (_ageBasedEnabled) SizedBox(width: 8.w),
            FeatureVisible(
              flagKey: 'custom_mode',
              child: IconButton(
                onPressed: _showVisibilityDialog,
                icon: Icon(
                  Icons.tune_rounded,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
                tooltip: "Manage Visibility",
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildAssetSlivers(ColorScheme scheme) {
    if (portfolio == null) return const [];
    final p = portfolio!;

    // ── helpers ──────────────────────────────────────────────────────────────
    int multiplier = 6;
    if (userAge != null) {
      if (userAge! < 30) {
        multiplier = 3;
      } else if (userAge! > 50) {
        multiplier = 12;
      }
    }
    final monthlyExpense = (assetTargets['bank']?.formula ?? 0) / multiplier;

    // Helper: card with detail screen
    Widget detailCard(
      String title,
      double amount,
      String key,
      IconData icon,
      Color color,
      AssetScreenConfig cfg,
    ) => _assetCard(
      title,
      amount,
      key,
      icon,
      color,
      scheme,
      onTapOverride: () => Get.to(() => AssetDetailScreen(config: cfg)),
    );

    // Visibility: Smart Mode follows age recommendations; Custom Mode respects manual hides
    bool isVisible(String key) {
      if (_ageBasedEnabled) return _recommendedKeys.contains(key);
      return !p.hiddenKeys.contains(key);
    }

    // ── all asset cards (single source, grouped per mode) ──────────────────
    final hasLoanController = Get.isRegistered<LoanController>();
    final loanController = hasLoanController
        ? Get.find<LoanController>()
        : null;
    final loanCount = loanController?.loans.length ?? 0;

    final allCards = <MapEntry<String, Widget>>[
      MapEntry(
        'bank',
        _assetCard(
          "Cash / Bank",
          bankBalance,
          'bank',
          Icons.account_balance,
          Colors.teal,
          scheme,
          readOnly: true,
          secondaryLabel: monthlyExpense > 0 ? "Monthly Expense" : null,
          secondaryValue: monthlyExpense > 0 ? monthlyExpense : null,
        ),
      ),
      MapEntry(
        'fd',
        detailCard(
          "FD / RD",
          p.fd,
          'fd',
          Icons.savings,
          Colors.orange,
          AssetConfigs.fd,
        ),
      ),
      MapEntry(
        'ppf',
        detailCard(
          "PPF",
          p.ppf,
          'ppf',
          Icons.savings_outlined,
          Colors.lightBlue,
          AssetConfigs.ppf,
        ),
      ),
      MapEntry(
        'postOffice',
        detailCard(
          "Post Office Schemes",
          p.postOffice,
          'postOffice',
          Icons.local_post_office,
          Colors.red.shade300,
          AssetConfigs.postOffice,
        ),
      ),
      MapEntry(
        'bonds',
        detailCard(
          "Bonds (Govt/Corp)",
          p.bonds,
          'bonds',
          Icons.receipt_long,
          Colors.blueGrey,
          AssetConfigs.bonds,
        ),
      ),
      MapEntry(
        'chitFund',
        detailCard(
          "Chit Fund",
          p.chitFund,
          'chitFund',
          Icons.groups,
          Colors.teal.shade300,
          AssetConfigs.chitFund,
        ),
      ),
      MapEntry(
        'stocks',
        detailCard(
          "Stocks",
          p.stocks,
          'stocks',
          Icons.show_chart,
          Colors.purple,
          AssetConfigs.stocks,
        ),
      ),
      MapEntry(
        'sip',
        detailCard(
          "Mutual Funds (SIP)",
          p.sip,
          'sip',
          Icons.pie_chart,
          Colors.blue,
          AssetConfigs.sip,
        ),
      ),
      MapEntry(
        'etf',
        detailCard(
          "ETFs",
          p.etf,
          'etf',
          Icons.stacked_line_chart,
          Colors.cyan,
          AssetConfigs.etf,
        ),
      ),
      MapEntry(
        'foreignStocks',
        detailCard(
          "Foreign Stocks",
          p.foreignStocks,
          'foreignStocks',
          Icons.language,
          Colors.deepPurple,
          AssetConfigs.foreignStocks,
        ),
      ),
      MapEntry(
        'startupEquity',
        detailCard(
          "Angel / Startup",
          p.startupEquity,
          'startupEquity',
          Icons.rocket_launch,
          Colors.orange,
          AssetConfigs.startupEquity,
        ),
      ),
      MapEntry(
        'pf',
        detailCard(
          "PF / EPF",
          p.pf,
          'pf',
          Icons.account_balance_wallet,
          Colors.green,
          AssetConfigs.pf,
        ),
      ),
      MapEntry(
        'vpf',
        detailCard(
          "Voluntary PF",
          p.vpf,
          'vpf',
          Icons.account_balance_wallet_outlined,
          Colors.green.shade300,
          AssetConfigs.vpf,
        ),
      ),
      MapEntry(
        'nps',
        detailCard(
          "NPS",
          p.nps,
          'nps',
          Icons.elderly,
          Colors.indigo,
          AssetConfigs.nps,
        ),
      ),
      MapEntry(
        'gold',
        detailCard(
          "Gold / Silver",
          p.gold,
          'gold',
          Icons.grid_goldenratio,
          Colors.amber,
          AssetConfigs.gold,
        ),
      ),
      MapEntry(
        'sgb',
        detailCard(
          "Sovereign Gold Bonds",
          p.sgb,
          'sgb',
          Icons.monetization_on,
          Colors.amber.shade300,
          AssetConfigs.sgb,
        ),
      ),
      MapEntry(
        'jewelry',
        detailCard(
          "Jewelry / Diamonds",
          p.jewelry,
          'jewelry',
          Icons.diamond,
          Colors.pink.shade300,
          AssetConfigs.jewelry,
        ),
      ),
      MapEntry(
        'crypto',
        detailCard(
          "Crypto",
          p.crypto,
          'crypto',
          Icons.currency_bitcoin,
          Colors.deepOrange,
          AssetConfigs.crypto,
        ),
      ),
      MapEntry(
        'reit',
        detailCard(
          "REITs",
          p.reit,
          'reit',
          Icons.apartment,
          Colors.tealAccent.shade700,
          AssetConfigs.reit,
        ),
      ),
      MapEntry(
        'p2p',
        detailCard(
          "P2P Lending",
          p.p2p,
          'p2p',
          Icons.people_alt,
          Colors.lime,
          AssetConfigs.p2p,
        ),
      ),
      MapEntry(
        'realEstate',
        _assetCard(
          "Real Estate",
          p.realEstate,
          'realEstate',
          Icons.domain,
          Colors.brown,
          scheme,
          onTapOverride: () => Get.to(() => const RealEstateDetailScreen()),
        ),
      ),
      MapEntry(
        'agriLand',
        detailCard(
          "Agricultural Land",
          p.agriLand,
          'agriLand',
          Icons.grass,
          Colors.green,
          AssetConfigs.agriLand,
        ),
      ),
      MapEntry(
        'vehicle',
        _assetCard(
          "Vehicle(s)",
          p.vehicle,
          'vehicle',
          Icons.directions_car,
          Colors.blueGrey.shade300,
          scheme,
          onTapOverride: () => Get.to(() => const VehicleDetailScreen()),
        ),
      ),
      MapEntry(
        'insurance',
        _assetCard(
          "Life Insurance / ULIP",
          p.insurance,
          'insurance',
          Icons.health_and_safety,
          Colors.pink,
          scheme,
          coverageStyle: true,
          onTapOverride: () => Get.to(() => const InsurancePolicyScreen()),
        ),
      ),
      MapEntry(
        'business',
        detailCard(
          "Business Capital",
          p.business,
          'business',
          Icons.business_center,
          Colors.brown.shade300,
          AssetConfigs.business,
        ),
      ),
      MapEntry(
        'loans',
        FeatureVisible(
          flagKey: 'loan_tracker',
          child: _assetCard(
            "Loans / Liabilities",
            loanController?.totalOutstanding ?? 0,
            'loans',
            Icons.money_off,
            Colors.red,
            scheme,
            secondaryLabel: loanCount > 0
                ? "$loanCount loan${loanCount > 1 ? 's' : ''}"
                : null,
            onTapOverride: () {
              if (!ensureFeatureVisible(context, 'loan_tracker')) return;
              Get.to(() => const LoanTrackerScreen());
            },
          ),
        ),
      ),
      MapEntry(
        'creditCard',
        _assetCard(
          "Credit Card Outstanding",
          p.creditCard,
          'creditCard',
          Icons.credit_card,
          Colors.red.shade700,
          scheme,
          onTapOverride: () => Get.to(() => const CreditCardDetailScreen()),
        ),
      ),
      MapEntry(
        'bnpl',
        detailCard(
          "BNPL / Pay Later",
          p.bnpl,
          'bnpl',
          Icons.schedule,
          Colors.deepOrange.shade700,
          AssetConfigs.bnpl,
        ),
      ),
    ];

    // ── sections ─────────────────────────────────────────────────────────────
    final sections = <Widget>[];

    Widget header(Widget child) => SliverToBoxAdapter(child: child);
    Widget spacer(double height) =>
        SliverToBoxAdapter(child: SizedBox(height: height));

    SliverGridDelegate gridDelegate() =>
        SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: Responsive.wealthGridColumns(context),
          crossAxisSpacing: 12.w,
          mainAxisSpacing: 12.h,
          childAspectRatio: Responsive.childAspectRatio(context),
        );

    if (_ageBasedEnabled) {
      // Smart Mode: guide users through a recommended order (phases)
      for (final phase in const [1, 2, 3]) {
        final phaseCards = allCards
            .where(
              (e) =>
                  WealthAgeRecommendations.phaseFor(e.key) == phase &&
                  isVisible(e.key),
            )
            .map((e) => e.value)
            .toList();
        if (phaseCards.isEmpty) continue;
        sections.add(header(_phaseHeader(phase, scheme)));
        sections.add(
          SliverGrid(
            gridDelegate: gridDelegate(),
            delegate: SliverChildListDelegate(phaseCards),
          ),
        );
        sections.add(spacer(20.h));
      }
    } else {
      // Custom Mode: grouped by asset class
      const groups = <(String, List<String>)>[
        (
          "Liquid & Fixed Income",
          ['bank', 'fd', 'ppf', 'postOffice', 'bonds', 'chitFund'],
        ),
        (
          "Equity & Growth",
          ['stocks', 'sip', 'etf', 'foreignStocks', 'startupEquity'],
        ),
        ("Retirement", ['pf', 'vpf', 'nps']),
        (
          "Alternative Assets",
          ['gold', 'sgb', 'jewelry', 'crypto', 'reit', 'p2p'],
        ),
        ("Physical Assets", ['realEstate', 'agriLand', 'vehicle']),
        ("Protection & Business", ['insurance', 'business']),
        ("Liabilities", ['loans', 'creditCard', 'bnpl']),
      ];
      for (final group in groups) {
        final groupCards = group.$2
            .where(isVisible)
            .map((key) => allCards.firstWhere((e) => e.key == key).value)
            .toList();
        if (groupCards.isEmpty) continue;
        sections.add(header(_sectionHeader(group.$1, scheme)));
        sections.add(
          SliverGrid(
            gridDelegate: gridDelegate(),
            delegate: SliverChildListDelegate(groupCards),
          ),
        );
        sections.add(spacer(20.h));
      }
    }

    // Custom Assets
    final customCards = p.custom.entries
        .where((e) => isVisible(e.key))
        .map(
          (e) => _assetCard(
            e.key,
            e.value,
            e.key,
            Icons.category,
            Colors.grey.shade500,
            scheme,
            onTapOverride: () => _showCustomAssetDialog(e.key, e.value),
          ),
        )
        .toList();
    if (_ageBasedEnabled) {
      // Smart Mode: custom keys are never age-recommended, so they stay hidden.
      if (customCards.isNotEmpty) {
        sections.add(header(_sectionHeader("Custom Assets", scheme)));
        sections.add(
          SliverGrid(
            gridDelegate: gridDelegate(),
            delegate: SliverChildListDelegate(customCards),
          ),
        );
      }
    } else {
      sections.add(
        header(
          _sectionHeader(
            "Custom Assets",
            scheme,
            trailing: FeatureVisible(
              flagKey: 'custom_mode',
              child: IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: "Add Custom Asset",
                onPressed: () => _showCustomAssetDialog('', 0),
                icon: Icon(
                  Icons.add_circle_outline,
                  color: AppColors.primary,
                  size: 20.sp,
                ),
              ),
            ),
          ),
        ),
      );
      if (customCards.isNotEmpty) {
        sections.add(
          SliverGrid(
            gridDelegate: gridDelegate(),
            delegate: SliverChildListDelegate(customCards),
          ),
        );
      }
    }

    return sections;
  }

  Widget _phaseHeader(int phase, ColorScheme scheme) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h, top: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            WealthAgeRecommendations.phaseIcon(phase),
            size: 18.sp,
            color: WealthAgeRecommendations.phaseColor(phase),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Phase $phase · ${WealthAgeRecommendations.phaseName(phase)}",
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  WealthAgeRecommendations.phaseSubtitle(phase),
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomAssetDialog(String key, double value) {
    final isNew = key.isEmpty;
    final nameCtrl = TextEditingController(text: key);
    final valueCtrl = TextEditingController(
      text: value > 0 ? value.toStringAsFixed(0) : '',
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isNew ? "Add Custom Asset" : "Custom Asset"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Name"),
              style: TextStyle(color: isDark ? Colors.white : null),
            ),
            SizedBox(height: 8.h),
            TextField(
              controller: valueCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Value"),
              style: TextStyle(color: isDark ? Colors.white : null),
            ),
          ],
        ),
        actions: [
          if (!isNew)
            TextButton(
              onPressed: () async {
                await WealthService.deleteCustomAsset(key);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              final newVal = double.tryParse(valueCtrl.text.trim()) ?? 0;
              if (newName.isNotEmpty && newVal > 0) {
                if (newName != key && !isNew) {
                  await WealthService.deleteCustomAsset(key);
                }
                await WealthService.setCustomAsset(newName, newVal);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    ).whenComplete(() {
      nameCtrl.dispose();
      valueCtrl.dispose();
    });
  }

  Widget _sectionHeader(String label, ColorScheme scheme, {Widget? trailing}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h, top: 4.h),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: scheme.onSurface.withValues(alpha: 0.15),
              height: 1,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface.withValues(alpha: 0.4),
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: scheme.onSurface.withValues(alpha: 0.15),
              height: 1,
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  // ... (Keep existing _assetCard and helpers)
  Widget _assetCard(
    String title,
    double amount,
    String key,
    IconData icon,
    Color color,
    ColorScheme scheme, {
    bool readOnly = false,
    String? secondaryLabel,
    double? secondaryValue,
    VoidCallback? onTapOverride,
    bool? recommendedOverride,
    bool coverageStyle = false,
  }) {
    final isRecommended = recommendedOverride ?? _recommendedKeys.contains(key);
    final currencyCode = CurrencyController.to.currencyCode.value;
    final symbol = CurrencyController.to.currencySymbol.value;
    final wealthTarget = assetTargets[key];
    final target = wealthTarget?.effective ?? 0;

    final progress = target > 0 ? (amount / target).clamp(0.0, 1.0) : 0.0;

    // Proper formatter based on currency
    final formatter = NumberFormat.compactCurrency(
      symbol: symbol,
      locale: currencyCode == 'INR' ? 'en_IN' : 'en_US',
      decimalDigits: 1,
    );

    return GestureDetector(
      // Allow tap even if readOnly (Bank) to update TARGET
      onTap:
          onTapOverride ??
          () => _showUpdateDialog(title, key, amount, readOnly: readOnly),
      child: Container(
        padding: EdgeInsets.all(14.w),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.1), // Glassy background
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: scheme.brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.08)
                : AppColors.lightBorder,
            width: 1,
          ),
          gradient: LinearGradient(
            colors: scheme.brightness == Brightness.dark
                ? [
                    Colors.white.withValues(alpha: 0.05),
                    Colors.white.withValues(alpha: 0.01),
                  ]
                : [
                    AppColors.lightSurfaceCard.withValues(alpha: 0.7),
                    AppColors.lightSurfaceCard.withValues(alpha: 0.3),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18.sp),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface.withValues(alpha: 0.9),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_ageBasedEnabled)
                  Container(
                    width: 8.w,
                    height: 8.h,
                    margin: EdgeInsets.only(left: 4.w),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isRecommended
                          ? AppColors.success
                          : scheme.brightness == Brightness.dark
                              ? Colors.white24
                              : AppColors.lightBorder,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 10.h),
            PrivacyText(
              "$symbol${amount.toStringAsFixed(0)}",
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
                letterSpacing: 0.5,
              ),
            ),
            if (secondaryLabel != null && secondaryValue != null) ...[
              SizedBox(height: 8.h),
              Text(
                "$secondaryLabel: ${formatter.format(secondaryValue)}",
                style: TextStyle(
                  fontSize: 11.sp,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            SizedBox(height: 8.h),
            if (target > 0) ...[
              LinearProgressIndicator(
                value: progress,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                borderRadius: BorderRadius.circular(2.r),
                minHeight: 4.h,
              ),
              SizedBox(height: 4.h),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      wealthTarget?.isOverridden == true
                          ? "Manual target: ${formatter.format(target)}"
                          : wealthTarget?.isEstimated == true
                              ? (coverageStyle
                                    ? "Suggested coverage: ${formatter.format(target)}"
                                    : "Suggested: ${formatter.format(target)}")
                              : (coverageStyle
                                    ? "Coverage: ${formatter.format(target)}"
                                    : "Target: ${formatter.format(target)}"),
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: wealthTarget?.isOverridden == true
                            ? AppColors.primary
                            : wealthTarget?.isEstimated == true
                                ? color.withValues(alpha: 0.8)
                                : scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  if (wealthTarget?.isEstimated == true)
                    Text(
                      "est.",
                      style: TextStyle(
                        fontSize: 9.sp,
                        color: color.withValues(alpha: 0.6),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  if (!_ageBasedEnabled) ...[
                    SizedBox(width: 2.w),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 14.sp,
                      tooltip: "Update Value / Target",
                      onPressed: () => _showUpdateDialog(title, key, amount),
                      icon: Icon(
                        Icons.tune_rounded,
                        color: scheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ],
              ),
            ] else if (wealthTarget != null) ...[
              Text(
                "Tracking only",
                style: TextStyle(
                  fontSize: 10.sp,
                  color: scheme.onSurface.withValues(alpha: 0.35),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            // Show interaction hint
            Row(
              children: [
                Text(
                  readOnly
                      ? "Update Expense"
                      : onTapOverride != null
                      ? "Tap to manage"
                      : "Tap to update",
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: scheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 10.sp,
                  color: scheme.onSurface.withValues(alpha: 0.3),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ... (Keep existing _showUpdateDialog, _buildPieChart, _buildSuggestions)
  Future<void> _showUpdateDialog(
    String title,
    String key,
    double currentVal, {
    bool readOnly = false,
  }) async {
    final symbol = CurrencyController.to.currencySymbol.value;
    final isBank = key == 'bank';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final valueController = TextEditingController(
      text: currentVal == 0 ? '' : currentVal.toStringAsFixed(0),
    );

    final wealthTarget = assetTargets[key];
    final formulaVal = wealthTarget?.formula ?? 0;
    final manualOverride = portfolio?.targets[key];

    // For Bank, we want to show/edit the Monthly Expense, not the Total Target.
    // Any other asset prefills from its manual override when one is set.
    double displayTargetVal = formulaVal;
    if (isBank) {
      int multiplier = 6;
      if (userAge != null) {
        if (userAge! < 30) {
          multiplier = 3;
        } else if (userAge! > 50) {
          multiplier = 12;
        }
      }
      if (multiplier > 0) displayTargetVal = formulaVal / multiplier;
    } else if (manualOverride != null && manualOverride > 0) {
      displayTargetVal = manualOverride;
    }

    final targetController = TextEditingController(
      text: displayTargetVal == 0 ? '' : displayTargetVal.toStringAsFixed(0),
    );

    try {
      await showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: "Dismiss",
        barrierColor: Colors.black.withValues(alpha: 0.8),
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, anim1, anim2) {
          return Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: () {
                  final sw = MediaQuery.sizeOf(context).width;
                  final raw = sw * 0.88;
                  return raw > 380
                      ? 380.0
                      : raw < 280
                      ? 280.0
                      : raw;
                }(),
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  // ... same premium decoration
                  gradient: LinearGradient(
                    colors: isDark
                        ? [AppColors.primaryContainerDark, AppColors.darkBackground]
                        : AppColors.lightGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28.r),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : AppColors.lightBorder,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 30.w,
                      offset: Offset(0, 10.w),
                    ),
                  ],
                ),
                child: DefaultTabController(
                  length: 1, // Only one view needed
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isBank ? "Update Monthly Expense" : "Update $title",
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Value Input (Bank Balance is read-only)
                      TextField(
                        controller: valueController,
                        // Bank is readOnly. Others depend on passed param.
                        readOnly: isBank || readOnly,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          color: (isBank || readOnly)
                              ? isDark
                                  ? Colors.white54
                                  : AppColors.lightTextSecondary
                              : isDark
                                  ? Colors.white
                                  : AppColors.lightTextPrimary,
                          fontSize: 18.sp,
                        ),
                        decoration: InputDecoration(
                          labelText: isBank
                              ? "Current Bank Balance"
                              : "Current Value",
                          labelStyle: TextStyle(
                              color: isDark
                                  ? Colors.white60
                                  : AppColors.lightTextSecondary),
                          hintText: "0",
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          prefixText: symbol,
                          prefixStyle: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : AppColors.lightTextPrimary),
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Target Input (Editable for Bank Expense)
                      TextField(
                        controller: targetController,
                        // Bank Expense is always editable. Other assets are
                        // editable in Custom Mode so targets can be overridden.
                        readOnly: !isBank && _ageBasedEnabled,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          color: !isBank && _ageBasedEnabled
                              ? isDark
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : AppColors.lightTextPrimary
                              : isDark
                                  ? Colors.white
                                  : AppColors.lightTextPrimary,
                          fontSize: 18.sp,
                        ),
                        decoration: InputDecoration(
                          labelText: isBank
                              ? "Monthly Expense Basis"
                              : _ageBasedEnabled
                                  ? "Target Goal (Formula)"
                                  : "Target Goal (Manual)",
                          labelStyle: TextStyle(color: AppColors.primary),
                          hintText: isBank
                              ? "Enter expense"
                              : "Auto-calculated",
                          helperText: isBank
                              ? "Leave empty to use auto-calculated average"
                              : _ageBasedEnabled
                                  ? "Calculated based on expenses & age"
                                  : "Set your own goal — leave empty for formula",
                          helperStyle: TextStyle(
                            color: AppColors.secondary.withValues(alpha: 0.5),
                            fontSize: 11.sp,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.03),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide(
                              color: AppColors.secondary.withValues(alpha: 0.5),
                            ),
                          ),
                          prefixText: symbol,
                          prefixStyle: TextStyle(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.7)
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                      ),

                      SizedBox(height: 24.h),

                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                "Cancel",
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.white54
                                        : AppColors.lightTextTertiary),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (isBank) {
                                  // Update Expense Override. Null or 0 means reset to auto.
                                  final text = targetController.text.trim();
                                  final val =
                                      double.tryParse(
                                        text.replaceAll(',', ''),
                                      ) ??
                                      0;
                                  if (text.isEmpty || val <= 0) {
                                    await WealthService.updateMonthlyExpenseOverride(
                                      null,
                                    );
                                  } else {
                                    await WealthService.updateMonthlyExpenseOverride(
                                      val,
                                    );
                                  }
                                } else if (!readOnly) {
                                  // Update Asset Value
                                  final val =
                                      double.tryParse(
                                        valueController.text.replaceAll(
                                          ',',
                                          '',
                                        ),
                                      ) ??
                                      0;
                                  await WealthService.updateAsset(key, val);
                                }

                                // Manual target override (Custom Mode only)
                                if (!isBank && !_ageBasedEnabled) {
                                  final targetText = targetController.text
                                      .trim();
                                  // Empty means "revert to formula target"
                                  if (targetText.isEmpty) {
                                    if (manualOverride != null &&
                                        manualOverride > 0) {
                                      await WealthService.removeAssetTarget(
                                        key,
                                      );
                                    }
                                  } else {
                                    final targetVal =
                                        double.tryParse(
                                          targetText.replaceAll(',', ''),
                                        ) ??
                                        0;
                                    if (targetVal > 0 &&
                                        targetVal != manualOverride) {
                                      await WealthService.updateAssetTarget(
                                        key,
                                        targetVal,
                                      );
                                    }
                                  }
                                }
                                // Formula targets are not updated explicitly

                                await _loadData();
                                if (context.mounted) Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.black,
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              ),
                              child: const Text(
                                "Save Changes",
                                style: TextStyle(fontWeight: FontWeight.bold),
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
        transitionBuilder: (context, anim1, anim2, child) {
          return Transform.scale(
            scale: Curves.easeOutBack.transform(anim1.value),
            child: child,
          );
        },
      );
    } finally {
      valueController.dispose();
      targetController.dispose();
    }
  }

  Future<void> _showVisibilityDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Map<String, String> assets = {
      // Liquid & Fixed Income
      'bank': "Cash / Bank",
      'fd': "FD / RD",
      'ppf': "PPF",
      'postOffice': "Post Office Schemes",
      'bonds': "Bonds (Govt/Corp)",
      'chitFund': "Chit Fund",
      // Equity & Growth
      'stocks': "Stocks",
      'sip': "Mutual Funds (SIP)",
      'etf': "ETFs",
      'foreignStocks': "Foreign Stocks",
      'startupEquity': "Angel / Startup Equity",
      // Retirement
      'pf': "PF / EPF",
      'vpf': "Voluntary PF (VPF)",
      'nps': "NPS",
      // Alternative Assets
      'gold': "Gold / Silver",
      'sgb': "Sovereign Gold Bonds",
      'jewelry': "Jewelry / Diamonds",
      'crypto': "Crypto",
      'reit': "REITs",
      'p2p': "P2P Lending",
      // Physical Assets
      'realEstate': "Real Estate",
      'agriLand': "Agricultural Land",
      'vehicle': "Vehicle(s)",
      // Protection
      'insurance': "Life Insurance / ULIP",
      'business': "Business Capital",
      // Liabilities
      'loans': "Loans / Liabilities",
      'creditCard': "Credit Card Outstanding",
      'bnpl': "BNPL / Pay Later",
    };

    // Custom assets — standard keys take precedence on a name collision.
    portfolio?.custom.keys.forEach((key) => assets.putIfAbsent(key, () => key));

    final hidden = List<String>.from(portfolio?.hiddenKeys ?? []);

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: Colors.black.withValues(alpha: 0.8),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: StatefulBuilder(
              builder: (context, setState) {
                return Container(
                  width: () {
                    final sw = MediaQuery.sizeOf(context).width;
                    final raw = sw * 0.88;
                    return raw > 380
                        ? 380.0
                        : raw < 280
                        ? 280.0
                        : raw;
                  }(),
                  constraints: BoxConstraints(maxHeight: 600.h),
                  padding: EdgeInsets.all(24.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [AppColors.primaryContainerDark, AppColors.darkBackground]
                          : AppColors.lightGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28.r),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : AppColors.lightBorder,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 30.w,
                        offset: Offset(0, 10.w),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Manage Visibility",
                        style: TextStyle(
                          fontSize: 18.sp,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      if (_ageBasedEnabled)
                        Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: Container(
                            padding: EdgeInsets.all(10.w),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  size: 16.sp,
                                  color: AppColors.primary,
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text(
                                    "Smart Mode is on — visibility follows your age recommendations. Turn it off to customize manually.",
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      color: isDark
                                          ? Colors.white70
                                          : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: assets.entries.map((e) {
                            final key = e.key;
                            final title = e.value;
                            final isRec = _recommendedKeys.contains(key);
                            final isVisible = _ageBasedEnabled
                                ? isRec
                                : !hidden.contains(key);
                            return CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        color: isVisible
                                            ? isDark
                                                ? Colors.white70
                                                : AppColors.lightTextSecondary
                                            : isDark
                                                ? Colors.white30
                                                : AppColors.lightTextTertiary,
                                      ),
                                    ),
                                  ),
                                  if (_ageBasedEnabled)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 5.w,
                                        vertical: 1.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isRec
                                            ? AppColors.success.withValues(
                                                alpha: 0.15,
                                              )
                                            : isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.05,
                                                  )
                                                : AppColors.lightSurfaceCard,
                                        borderRadius: BorderRadius.circular(
                                          4.r,
                                        ),
                                      ),
                                      child: Text(
                                        isRec
                                            ? "Recommended"
                                            : "Not recommended",
                                        style: TextStyle(
                                          fontSize: 8.sp,
                                          color: isRec
                                              ? AppColors.success
                                              : isDark
                                                  ? Colors.white30
                                                  : AppColors.lightTextTertiary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              value: isVisible,
                              activeColor: AppColors.primary,
                              checkColor: Colors.black,
                              side: BorderSide(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.5)
                                    : AppColors.lightBorder,
                              ),
                              onChanged: _ageBasedEnabled
                                  ? null
                                  : (val) {
                                      setState(() {
                                        if (val == true) {
                                          hidden.remove(key);
                                        } else {
                                          hidden.add(key);
                                        }
                                      });
                                    },
                            );
                          }).toList(),
                        ),
                      ),
                      SizedBox(height: 24.h),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                "Cancel",
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.white54
                                        : AppColors.lightTextTertiary),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                await WealthService.updateHiddenAssets(hidden);
                                await _loadData();
                                if (context.mounted) Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.black,
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              ),
                              child: const Text(
                                "Save Changes",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(anim1.value),
          child: child,
        );
      },
    );
  }

  Widget _buildPieChart(ColorScheme scheme) {
    if (portfolio == null) return const SizedBox.shrink();
    // Check visible total instead of totalAssets

    final p = portfolio!;
    final hidden = _ageBasedEnabled
        ? WealthAgeRecommendations.allCards
              .map((c) => c.key)
              .where((k) => !_recommendedKeys.contains(k))
              .toSet()
        : p.hiddenKeys;
    final List<PieChartSectionData> sections = [];

    void add(double val, String key, Color color, String title) {
      if (!hidden.contains(key) && val > 0) {
        sections.add(
          PieChartSectionData(
            value: val,
            color: color,
            radius: 50.r,
            title: title,
            titleStyle: TextStyle(fontSize: 10.sp, color: Colors.white),
          ),
        );
      }
    }

    // All 26 asset classes (liabilities excluded — allocation shows assets
    // only), mirroring the net-worth card's full set plus custom assets.
    final assetSections = <MapEntry<String, (double, Color, String)>>[
      MapEntry('bank', (bankBalance, Colors.teal, 'Bank')),
      MapEntry('sip', (p.sip, Colors.blue, 'SIP')),
      MapEntry('fd', (p.fd, Colors.orange, 'FD')),
      MapEntry('stocks', (p.stocks, Colors.purple, 'Stocks')),
      MapEntry('pf', (p.pf, Colors.green, 'PF')),
      MapEntry('crypto', (p.crypto, Colors.amber, 'Crypto')),
      MapEntry('gold', (p.gold, Colors.yellow[700]!, 'Gold')),
      MapEntry('realEstate', (p.realEstate, Colors.brown, 'RE')),
      MapEntry('nps', (p.nps, Colors.indigo, 'NPS')),
      MapEntry('etf', (p.etf, Colors.cyan, 'ETF')),
      MapEntry('reit', (p.reit, Colors.tealAccent.shade700, 'REIT')),
      MapEntry('p2p', (p.p2p, Colors.lime, 'P2P')),
      MapEntry('ppf', (p.ppf, Colors.lightBlue, 'PPF')),
      MapEntry('sgb', (p.sgb, Colors.amber.shade300, 'SGB')),
      MapEntry('bonds', (p.bonds, Colors.blueGrey, 'Bonds')),
      MapEntry('insurance', (p.insurance, Colors.pink, 'Insurance')),
      MapEntry(
        'foreignStocks',
        (p.foreignStocks, Colors.deepPurple, 'Foreign'),
      ),
      MapEntry('vpf', (p.vpf, Colors.green.shade300, 'VPF')),
      MapEntry(
        'postOffice',
        (p.postOffice, Colors.red.shade300, 'Post Office'),
      ),
      MapEntry('chitFund', (p.chitFund, Colors.teal.shade300, 'Chit Fund')),
      MapEntry(
        'startupEquity',
        (p.startupEquity, Colors.deepOrange, 'Startup'),
      ),
      MapEntry('business', (p.business, Colors.brown.shade300, 'Business')),
      MapEntry('vehicle', (p.vehicle, Colors.blueGrey.shade300, 'Vehicle')),
      MapEntry('jewelry', (p.jewelry, Colors.pink.shade300, 'Jewelry')),
      MapEntry('agriLand', (p.agriLand, Colors.green, 'Agri Land')),
    ];

    for (final section in assetSections) {
      final (val, color, title) = section.value;
      add(val, section.key, color, title);
    }

    // Custom assets
    p.custom.forEach((key, val) {
      add(val, key, Colors.grey.shade500, key);
    });

    if (sections.isEmpty) {
      return Center(
        child: Text(
          "No visible assets",
          style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.5)),
        ),
      );
    }

    return GlassContainer(
      borderRadius: BorderRadius.circular(24.r),
      padding: EdgeInsets.all(20.w),
      child: SizedBox(
        height: 200.h,
        child: PieChart(
          PieChartData(
            sections: sections,
            centerSpaceRadius: 40,
            sectionsSpace: 2,
            borderData: FlBorderData(show: false),
          ),
        ),
      ),
    );
  }

  Widget _buildIdealIncomeCard(ColorScheme scheme) {
    if (portfolio == null) return const SizedBox.shrink();

    final code = CurrencyController.to.currencyCode.value;
    final symbol = CurrencyController.to.currencySymbol.value;

    // Effective monthly expense = bank target formula ÷ cash-months
    final cashMonths = userAge == null
        ? 6
        : (userAge! < 30 ? 3 : (userAge! > 50 ? 12 : 6));
    final monthlyExpense = cashMonths > 0
        ? (assetTargets['bank']?.formula ?? 0) / cashMonths
        : 0.0;

    final current = <String, double>{
      'bank': bankBalance,
      'fd': portfolio!.fd,
      'postOffice': portfolio!.postOffice,
      'sip': portfolio!.sip,
      'stocks': portfolio!.stocks,
      'etf': portfolio!.etf,
      'foreignStocks': portfolio!.foreignStocks,
      'startupEquity': portfolio!.startupEquity,
      'pf': portfolio!.pf,
      'ppf': portfolio!.ppf,
      'vpf': portfolio!.vpf,
      'nps': portfolio!.nps,
      'bonds': portfolio!.bonds,
      'gold': portfolio!.gold,
      'sgb': portfolio!.sgb,
      'crypto': portfolio!.crypto,
      'reit': portfolio!.reit,
      'p2p': portfolio!.p2p,
    };

    final targetEffective = <String, double>{
      for (final key in investableTargetKeys)
        key: assetTargets[key]?.effective ?? 0,
    };

    final result = calculateIdealIncome(
      monthlyExpense: monthlyExpense,
      targetEffective: targetEffective,
      current: current,
      age: userAge ?? 30,
    );

    final savingsLabel = formatMonthlyIncome(
      result.monthlySavingsNeeded,
      currencyCode: code,
      symbol: symbol,
    );

    return GlassContainer(
      borderRadius: BorderRadius.circular(24.r),
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.trending_up_rounded,
                color: AppColors.success,
                size: 18.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                "What you should earn to stay on track",
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _incomeFigure(
            scheme,
            label: "Ideal Monthly Income",
            value: formatMonthlyIncome(
              result.idealMonthlyIncome,
              currencyCode: code,
              symbol: symbol,
            ),
            sub: Obx(
              () => Text(
                "incl. savings of ${Get.isRegistered<PrivacyController>() && Get.find<PrivacyController>().isPrivacyMode.value ? '••••' : savingsLabel} /mo",
                style: TextStyle(
                  fontSize: 10.sp,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            color: AppColors.primary,
          ),
          SizedBox(height: 16.h),
          _incomeFigure(
            scheme,
            label: "Ideal Annual Income",
            value: formatAnnualIncome(
              result.idealAnnualIncome,
              currencyCode: code,
              symbol: symbol,
            ),
            sub: Text(
              "annually",
              style: TextStyle(
                fontSize: 10.sp,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            color: AppColors.success,
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Divider(
              color: scheme.onSurface.withValues(alpha: 0.15),
              height: 1,
            ),
          ),
          _contextRow(
            scheme,
            Icons.receipt_long_outlined,
            "Current monthly expense",
            formatMonthlyIncome(
              result.monthlyExpense,
              currencyCode: code,
              symbol: symbol,
            ),
          ),
          if (actualMonthlyIncome > 0)
            _contextRow(
              scheme,
              Icons.payments_outlined,
              "You earn today",
              formatMonthlyIncome(
                actualMonthlyIncome,
                currencyCode: code,
                symbol: symbol,
              ),
            ),
          if (geoResult != null && geoResult!.baselineMonthlyIncome > 0)
            _contextRow(
              scheme,
              Icons.location_city_outlined,
              "Typical income in your area",
              formatMonthlyIncome(
                geoResult!.baselineMonthlyIncome.toDouble(),
                currencyCode: code,
                symbol: symbol,
              ),
            ),
        ],
      ),
    );
  }

  Widget _incomeFigure(
    ColorScheme scheme, {
    required String label,
    required String value,
    required Widget sub,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        SizedBox(height: 4.h),
        PrivacyText(
          value,
          style: TextStyle(
            fontSize: 26.sp,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 2.h),
        sub,
      ],
    );
  }

  Widget _contextRow(
    ColorScheme scheme,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16.sp,
            color: scheme.onSurface.withValues(alpha: 0.5),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          PrivacyText(
            value,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // Placeholder comment in previous edit removed the method. Restoring it.
  Widget _buildNetWorthCard(ColorScheme scheme) {
    double total = 0;
    if (portfolio != null) {
      final p = portfolio!;
      final hidden = _ageBasedEnabled
          ? WealthAgeRecommendations.allCards
                .map((c) => c.key)
                .where((k) => !_recommendedKeys.contains(k))
                .toSet()
          : p.hiddenKeys;

      void add(String key, double val) {
        if (!hidden.contains(key)) total += val;
      }

      void sub(String key, double val) {
        if (!hidden.contains(key)) total -= val;
      }

      add('bank', bankBalance);
      add('realEstate', p.realEstate);
      add('stocks', p.stocks);
      add('sip', p.sip);
      add('fd', p.fd);
      add('pf', p.pf);
      add('nps', p.nps);
      add('gold', p.gold);
      add('crypto', p.crypto);
      add('etf', p.etf);
      add('reit', p.reit);
      add('p2p', p.p2p);
      add('ppf', p.ppf);
      add('sgb', p.sgb);
      add('bonds', p.bonds);
      add('insurance', p.insurance);
      add('foreignStocks', p.foreignStocks);
      add('vpf', p.vpf);
      add('postOffice', p.postOffice);
      add('chitFund', p.chitFund);
      add('startupEquity', p.startupEquity);
      add('business', p.business);
      add('vehicle', p.vehicle);
      add('jewelry', p.jewelry);
      add('agriLand', p.agriLand);

      // Customs
      p.custom.forEach((key, val) {
        if (!hidden.contains(key)) total += val;
      });

      // Liabilities (subtract all); fall back to the persisted loans figure
      // when the LoanController isn't available yet.
      final loanController = Get.isRegistered<LoanController>()
          ? Get.find<LoanController>()
          : null;
      sub('loans', loanController?.totalOutstanding ?? p.loans);
      sub('creditCard', p.creditCard);
      sub('bnpl', p.bnpl);
    }

    final symbol = CurrencyController.to.currencySymbol.value;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade800, Colors.deepPurple.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withValues(alpha: 0.4),
            blurRadius: 15.w,
            offset: Offset(0, 8.w),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            "Total Net Worth",
            style: TextStyle(color: Colors.white70, fontSize: 14.sp),
          ),
          SizedBox(height: 8.h),
          PrivacyText(
            "$symbol${total.toStringAsFixed(0)}",
            style: TextStyle(
              color: Colors.white,
              fontSize: 36.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            "Assets − All Liabilities",
            style: TextStyle(color: Colors.white54, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions(ColorScheme scheme) {
    if (smartInsights.isEmpty && !loading) {
      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green, size: 24.sp),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                "No suggestions yet. Add data to get insights!",
                style: TextStyle(color: scheme.onSurface),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: smartInsights.map((insight) {
        final type = insight['type'];
        final msg = insight['message'];

        Color iconColor = Colors.blue;
        IconData iconData = Icons.info_outline;
        Color bgColor = Colors.blue.withValues(alpha: 0.1);

        if (type == 'warning') {
          iconColor = Colors.orange;
          iconData = Icons.warning_amber_rounded;
          bgColor = Colors.orange.withValues(alpha: 0.1);
        } else if (type == 'alert') {
          iconColor = Colors.redAccent;
          iconData = Icons.dangerous_outlined;
          bgColor = Colors.red.withValues(alpha: 0.1);
        } else if (type == 'success') {
          iconColor = Colors.green;
          iconData = Icons.check_circle_outline;
          bgColor = Colors.green.withValues(alpha: 0.1);
        }

        return Container(
          width: double.infinity,
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: iconColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(iconData, color: iconColor, size: 20.sp),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  msg,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 13.sp,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
} // Closing brace for _WealthBuilderScreenState
