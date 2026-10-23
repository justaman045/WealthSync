import 'package:money_control/l10n/app_localizations.dart';
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
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Controllers/profile_controller.dart';
import 'package:money_control/Models/user_model.dart';
import 'package:money_control/Controllers/loan_controller.dart';
import 'package:money_control/Screens/loan_tracker_screen.dart';
import 'package:money_control/Screens/credit_card_detail_screen.dart';
import 'package:money_control/Screens/insurance_policy_screen.dart';
import 'package:money_control/Screens/vehicle_detail_screen.dart';
import 'package:money_control/Screens/real_estate_detail_screen.dart';
import 'package:money_control/Screens/asset_detail_screen.dart';
import 'package:money_control/Config/wealth_asset_registry.dart';
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
  Worker? _txWorker;
  Timer? _targetDebounce;

  @override
  void initState() {
    super.initState();
    _portfolioSub = WealthService.streamPortfolio().listen((p) {
      if (mounted) setState(() => portfolio = p);
    }, onError: (e) => debugPrint('WealthBuilder portfolio stream error: $e'));
    _initProfileListener();
    _initTransactionWorker();
    _loadData();
  }

  @override
  void dispose() {
    _portfolioSub?.cancel();
    _profileSub?.cancel();
    _txWorker?.dispose();
    _targetDebounce?.cancel();
    _isBottomBarVisible.dispose();
    super.dispose();
  }

  /// Cash, income and insights are all derived from the transaction list, and
  /// this tab stays alive behind the bottom nav, so `initState` runs once per
  /// app session: without this worker the Wealth tab keeps reporting the
  /// balance from the moment it was first opened while the home balance is
  /// live.
  void _initTransactionWorker() {
    if (!Get.isRegistered<TransactionController>()) return;
    final txController = Get.find<TransactionController>();
    _txWorker = ever(txController.transactions, (_) {
      _refreshTransactionDerived();
    });
  }

  void _refreshTransactionDerived() {
    if (!Get.isRegistered<TransactionController>()) return;
    final transactions = Get.find<TransactionController>().transactions;
    final balance = WealthService.calculateBankBalance(transactions);
    final income = WealthService.calculateAverageMonthlyIncome(transactions);
    if (!mounted) return;
    setState(() {
      bankBalance = balance;
      actualMonthlyIncome = income;
      final p = portfolio;
      if (p != null) {
        smartInsights = WealthService.generateSmartInsights(p, transactions);
      }
    });
    _scheduleTargetRecompute(transactions, balance);
  }

  /// Asset targets depend on the bank balance, but computing them is async and
  /// touches Firestore, so a burst of transaction edits collapses into one
  /// recompute instead of one per edit.
  void _scheduleTargetRecompute(
    List<TransactionModel> transactions,
    double balance,
  ) {
    _targetDebounce?.cancel();
    _targetDebounce = Timer(const Duration(milliseconds: 800), () async {
      if (!mounted || !Get.isRegistered<ProfileController>()) return;
      final p = portfolio;
      if (p == null) return;
      final userProfile = Get.find<ProfileController>().userProfile.value;
      final quickGeo = await GeoService.getCached();
      final targets = await WealthService.calculateAssetTargets(
        p,
        transactions,
        userProfile,
        baselineMonthlyIncome: quickGeo?.baselineMonthlyIncome ?? 25000,
        bankBalance: balance,
      );
      if (!mounted) return;
      setState(() => assetTargets = targets);
    });
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
            SnackBar(
              content: Text(AppLocalizations.of(context)!.failedLoadWealthDataPull),
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
          AppLocalizations.of(context)!.wealthBuilder,
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
                                      AppLocalizations.of(context)!.allocation,
                                      style: AppType.titleMedium(scheme.onSurface),
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
                                      AppLocalizations.of(context)!.idealIncome,
                                      style: AppType.titleMedium(scheme.onSurface),
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
                                      AppLocalizations.of(context)!.smartSuggestions,
                                      style: AppType.titleMedium(scheme.onSurface),
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
              AppLocalizations.of(context)!.setAgeFirst,
              style: AppType.titleLarge(scheme.onSurface),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              AppLocalizations.of(context)!.wealthBuilderPersonalisesEveryTarget,
              style: AppType.bodyMedium(scheme.onSurface.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Gated like the other profile entry points: a `hidden`
                  // profile flag must not be routable from the wealth screen.
                  if (!ensureFeatureUsable(context, 'profile')) return;
                  await Get.to(() => const EditProfileScreen());
                  // Re-load after returning in case user set their DOB
                  _loadData();
                },
                icon: const Icon(Icons.edit_outlined),
                label: Text(AppLocalizations.of(context)!.goProfile),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
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
              style: AppType.labelMedium(_ageBasedEnabled
                    ? AppColors.primary
                    : isDark
                        ? Colors.white60
                        : AppColors.lightTextSecondary),
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
                  style: AppType.labelMedium(zoneColor),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${geo.zoneName} · ${geo.zoneDescription}',
                  style: AppType.labelSmall(zoneColor.withValues(alpha: 0.8)),
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
              style: AppType.labelSmall(zoneColor),
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
          style: AppType.titleMedium(scheme.onSurface),
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
                  AppLocalizations.of(context)!.smartMode,
                  style: AppType.labelSmall(AppColors.primary),
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
                tooltip: AppLocalizations.of(context)!.manageVisibility,
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
      for (final asset in WealthAssetRegistry.assets)
        MapEntry(
          asset.key,
          _buildAssetCard(
            asset,
            scheme,
            p,
            monthlyExpense: monthlyExpense,
            loanTotal: loanController?.totalOutstanding ?? 0,
            loanCount: loanCount,
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
      for (final group in WealthAssetRegistry.groupOrder) {
        final groupCards = WealthAssetRegistry.inGroup(group)
            .where((a) => isVisible(a.key))
            .map((a) => allCards.firstWhere((e) => e.key == a.key).value)
            .toList();
        if (groupCards.isEmpty) continue;
        sections.add(
          header(_sectionHeader(_groupLabel(group), scheme)),
        );
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
                tooltip: AppLocalizations.of(context)!.addCustomAsset,
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
                  style: AppType.labelMedium(scheme.onSurface),
                ),
                SizedBox(height: 2.h),
                Text(
                  WealthAgeRecommendations.phaseSubtitle(phase),
                  style: AppType.labelSmall(scheme.onSurface.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCustomAssetDialog(String key, double value) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _CustomAssetDialog(assetKey: key, value: value),
    );
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
              style: AppType.labelSmall(scheme.onSurface.withValues(alpha: 0.4)),
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

  /// The heading a Custom Mode section is drawn under.
  String _groupLabel(WealthAssetGroup group) => switch (group) {
    WealthAssetGroup.liquidAndFixedIncome => "Liquid & Fixed Income",
    WealthAssetGroup.equityAndGrowth => "Equity & Growth",
    WealthAssetGroup.retirement => "Retirement",
    WealthAssetGroup.alternativeAssets => "Alternative Assets",
    WealthAssetGroup.physicalAssets => "Physical Assets",
    WealthAssetGroup.protectionAndBusiness => "Protection & Business",
    WealthAssetGroup.liabilities => "Liabilities",
  };

  /// Builds one asset card from its descriptor.
  ///
  /// The routing, the read-only flag, the coverage style and the secondary
  /// figures all come from [WealthAssetDescriptor], so adding an asset type is
  /// one entry in the registry rather than a card spelled out here.
  Widget _buildAssetCard(
    WealthAssetDescriptor asset,
    ColorScheme scheme,
    WealthPortfolio p, {
    required double monthlyExpense,
    required double loanTotal,
    required int loanCount,
  }) {
    final amount = switch (asset.key) {
      'bank' => bankBalance,
      'loans' => loanTotal,
      _ => wealthAssetValue(p, asset.key),
    };

    // The cash card shows what it is being saved towards; the loan card shows
    // how many loans are behind the figure.
    String? secondaryLabel;
    double? secondaryValue;
    if (asset.key == 'bank' && monthlyExpense > 0) {
      secondaryLabel = "Monthly Expense";
      secondaryValue = monthlyExpense;
    } else if (asset.key == 'loans' && loanCount > 0) {
      secondaryLabel = "$loanCount loan${loanCount > 1 ? 's' : ''}";
    }

    final card = _assetCard(
      asset.label,
      amount,
      asset.key,
      asset.icon,
      asset.color,
      scheme,
      readOnly: asset.readOnly,
      coverageStyle: asset.coverageStyle,
      secondaryLabel: secondaryLabel,
      secondaryValue: secondaryValue,
      // A card with nowhere to go keeps the default tap, which opens the
      // target editor — the cash card is read-only but its target is not.
      onTapOverride: asset.destination == WealthAssetDestination.none
          ? null
          : () => _openAssetDetail(asset),
    );

    if (asset.destination == WealthAssetDestination.loans) {
      // The loan tracker has its own kill-switch: hiding it removes the card,
      // it must not leave a button that does nothing.
      return FeatureVisible(flagKey: 'loan_tracker', child: card);
    }
    return card;
  }

  /// Opens the screen behind an asset card.
  void _openAssetDetail(WealthAssetDescriptor asset) {
    switch (asset.destination) {
      case WealthAssetDestination.none:
        return;
      case WealthAssetDestination.config:
        final cfg = asset.config;
        if (cfg != null) Get.to(() => AssetDetailScreen(config: cfg));
        return;
      case WealthAssetDestination.realEstate:
        Get.to(() => const RealEstateDetailScreen());
        return;
      case WealthAssetDestination.vehicle:
        Get.to(() => const VehicleDetailScreen());
        return;
      case WealthAssetDestination.insurance:
        Get.to(() => const InsurancePolicyScreen());
        return;
      case WealthAssetDestination.creditCard:
        Get.to(() => const CreditCardDetailScreen());
        return;
      case WealthAssetDestination.loans:
        if (!ensureFeatureVisible(context, 'loan_tracker')) return;
        Get.to(() => const LoanTrackerScreen());
        return;
    }
  }

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
      // The card shows a name and an amount, so it reads as text without
      // this — nothing tells a screen reader that tapping it opens the editor.
      child: Semantics(
        button: true,
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
                    style: AppType.labelMedium(scheme.onSurface.withValues(alpha: 0.9)),
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
              style: AppType.titleLarge(scheme.onSurface),
            ),
            if (secondaryLabel != null && secondaryValue != null) ...[
              SizedBox(height: 8.h),
              Text(
                "$secondaryLabel: ${formatter.format(secondaryValue)}",
                style: AppType.labelSmall(scheme.onSurface.withValues(alpha: 0.6)),
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
                      AppLocalizations.of(context)!.est,
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
                      tooltip: AppLocalizations.of(context)!.updateValueOrTarget,
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
                AppLocalizations.of(context)!.trackingOnly,
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
                  style: AppType.labelSmall(scheme.onSurface.withValues(alpha: 0.4)),
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
                        style: AppType.titleMedium(isDark ? Colors.white : AppColors.lightTextPrimary),
                      ),
                      SizedBox(height: 16.h),

                      // Value Input (Bank Balance is read-only)
                      TextField(
                        controller: valueController,
                        // Bank is readOnly. Others depend on passed param.
                        readOnly: isBank || readOnly,
                        keyboardType: TextInputType.number,
                        style: AppType.titleMedium((isBank || readOnly)
                              ? isDark
                                  ? Colors.white54
                                  : AppColors.lightTextSecondary
                              : isDark
                                  ? Colors.white
                                  : AppColors.lightTextPrimary),
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
                        style: AppType.titleMedium(!isBank && _ageBasedEnabled
                              ? isDark
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : AppColors.lightTextPrimary
                              : isDark
                                  ? Colors.white
                                  : AppColors.lightTextPrimary),
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
                          helperStyle: AppType.labelSmall(AppColors.secondary.withValues(alpha: 0.5)),
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
                                AppLocalizations.of(context)!.cancel,
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
                                foregroundColor: Colors.white,
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
      for (final a in WealthAssetRegistry.assets) a.key: a.label,
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
                        AppLocalizations.of(context)!.manageVisibility,
                        style: AppType.titleMedium(isDark ? Colors.white : AppColors.lightTextPrimary),
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
                                    AppLocalizations.of(context)!.smartModeVisibilityFollowsAge,
                                    style: AppType.labelSmall(isDark
                                          ? Colors.white70
                                          : AppColors.lightTextSecondary),
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
                                        style: AppType.labelSmall(isRec
                                              ? AppColors.success
                                              : isDark
                                                  ? Colors.white30
                                                  : AppColors.lightTextTertiary),
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
                                AppLocalizations.of(context)!.cancel,
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
                                foregroundColor: Colors.white,
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
        ? WealthAssetRegistry.assets
              .map((a) => a.key)
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
            titleStyle: AppType.labelSmall(Colors.white),
          ),
        );
      }
    }

    // Every asset the allocation chart counts (liabilities excluded — an
    // allocation is a picture of what you own), mirroring the net-worth
    // card's full set plus custom assets.
    final assetSections = <MapEntry<String, (double, Color, String)>>[
      for (final asset in WealthAssetRegistry.allocationAssets)
        MapEntry(
          asset.key,
          (
            asset.key == 'bank'
                ? bankBalance
                : wealthAssetValue(p, asset.key),
            asset.color,
            asset.shortLabel,
          ),
        ),
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
          AppLocalizations.of(context)!.visibleAssets,
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
                AppLocalizations.of(context)!.whatShouldEarnStayTrack,
                style: AppType.labelMedium(scheme.onSurface.withValues(alpha: 0.6)),
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
                style: AppType.labelSmall(scheme.onSurface.withValues(alpha: 0.5)),
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
              AppLocalizations.of(context)!.annually,
              style: AppType.labelSmall(scheme.onSurface.withValues(alpha: 0.5)),
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
          style: AppType.labelMedium(scheme.onSurface.withValues(alpha: 0.6)),
        ),
        SizedBox(height: 4.h),
        PrivacyText(
          value,
          style: AppType.headlineSmall(color),
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
              style: AppType.bodySmall(scheme.onSurface.withValues(alpha: 0.7)),
            ),
          ),
          PrivacyText(
            value,
            style: AppType.labelMedium(scheme.onSurface),
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
          ? WealthAssetRegistry.assets
                .map((a) => a.key)
                .where((k) => !_recommendedKeys.contains(k))
                .toSet()
          : p.hiddenKeys;

      void add(String key, double val) {
        if (!hidden.contains(key)) total += val;
      }

      void sub(String key, double val) {
        if (!hidden.contains(key)) total -= val;
      }

      // The cash balance comes from the transaction stream, not from the
      // portfolio document.
      add('bank', bankBalance);

      // Every asset the allocation chart counts. Insurance is in neither:
      // a policy's sum assured is a cover, not an asset.
      for (final asset in WealthAssetRegistry.allocationAssets) {
        if (asset.key == 'bank') continue;
        add(asset.key, wealthAssetValue(p, asset.key));
      }

      // Customs
      p.custom.forEach((key, val) {
        if (!hidden.contains(key)) total += val;
      });

      // Liabilities (subtract all); fall back to the persisted loans figure
      // when the LoanController isn't available yet.
      final loanController = Get.isRegistered<LoanController>()
          ? Get.find<LoanController>()
          : null;
      for (final asset in WealthAssetRegistry.assets) {
        if (!asset.isLiability) continue;
        sub(
          asset.key,
          asset.key == 'loans'
              ? loanController?.totalOutstanding ?? p.loans
              : wealthAssetValue(p, asset.key),
        );
      }
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
            color: AppColors.accent.withValues(alpha: 0.4),
            blurRadius: 15.w,
            offset: Offset(0, 8.w),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context)!.totalNetWorth,
            style: AppType.bodyMedium(Colors.white70),
          ),
          SizedBox(height: 8.h),
          PrivacyText(
            "$symbol${total.toStringAsFixed(0)}",
            style: AppType.displaySmall(Colors.white),
          ),
          SizedBox(height: 8.h),
          Text(
            AppLocalizations.of(context)!.assetsLiabilities,
            style: AppType.bodySmall(Colors.white54),
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
            Icon(Icons.check_circle_outline, color: AppColors.success, size: 24.sp),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.suggestionsYetAddDataGet,
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

        Color iconColor = AppColors.primary;
        IconData iconData = Icons.info_outline;
        Color bgColor = AppColors.primary.withValues(alpha: 0.1);

        if (type == 'warning') {
          iconColor = AppColors.warning;
          iconData = Icons.warning_amber_rounded;
          bgColor = AppColors.warning.withValues(alpha: 0.1);
        } else if (type == 'alert') {
          iconColor = AppColors.error;
          iconData = Icons.dangerous_outlined;
          bgColor = AppColors.error.withValues(alpha: 0.1);
        } else if (type == 'success') {
          iconColor = AppColors.success;
          iconData = Icons.check_circle_outline;
          bgColor = AppColors.success.withValues(alpha: 0.1);
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
                  style: AppType.bodySmall(scheme.onSurface),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
} // Closing brace for _WealthBuilderScreenState

/// Owns its [TextEditingController]s and disposes them in [State.dispose] —
/// unlike the old inline `showDialog` + `try/finally` (the pattern AGENTS.md
/// warns about), this cannot re-attach a live [TextField] to a disposed
/// controller if the dialog rebuilds during its exit animation.
class _CustomAssetDialog extends StatefulWidget {
  final String assetKey;
  final double value;

  const _CustomAssetDialog({required this.assetKey, required this.value});

  @override
  State<_CustomAssetDialog> createState() => _CustomAssetDialogState();
}

class _CustomAssetDialogState extends State<_CustomAssetDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _valueCtrl;
  bool _busy = false;

  bool get _isNew => widget.assetKey.isEmpty;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.assetKey);
    _valueCtrl = TextEditingController(
      text: widget.value > 0 ? widget.value.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_busy) return;
    setState(() => _busy = true);
    await WealthService.deleteCustomAsset(widget.assetKey);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    if (_busy) return;
    final newName = _nameCtrl.text.trim();
    final newVal = double.tryParse(_valueCtrl.text.trim()) ?? 0;
    setState(() => _busy = true);
    if (newName.isNotEmpty && newVal > 0) {
      if (newName != widget.assetKey && !_isNew) {
        await WealthService.deleteCustomAsset(widget.assetKey);
      }
      await WealthService.setCustomAsset(newName, newVal);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      title: Text(_isNew ? "Add Custom Asset" : "Custom Asset"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: "Name"),
            style: TextStyle(color: isDark ? Colors.white : null),
          ),
          SizedBox(height: 8.h),
          TextField(
            controller: _valueCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Value"),
            style: TextStyle(color: isDark ? Colors.white : null),
          ),
        ],
      ),
      actions: [
        if (!_isNew)
          TextButton(
            onPressed: _busy ? null : _delete,
            child: const Text("Delete", style: TextStyle(color: AppColors.error)),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        TextButton(
          onPressed: _busy ? null : _save,
          child: const Text(AppStrings.save),
        ),
      ],
    );
  }
}
