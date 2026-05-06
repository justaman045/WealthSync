import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:money_control/Components/bottom_nav_bar.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Models/wealth_data.dart';
import 'package:money_control/Services/wealth_service.dart';
import 'package:money_control/Components/skeleton_loader.dart';

import 'package:intl/intl.dart';

import 'package:flutter/rendering.dart' as rendering;

import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Controllers/profile_controller.dart';
import 'package:money_control/Controllers/loan_controller.dart';
import 'package:money_control/Screens/loan_tracker_screen.dart';
import 'package:money_control/Services/geo_service.dart';
import 'package:money_control/Screens/edit_profile.dart';
import 'package:get/get.dart';

class WealthBuilderScreen extends StatefulWidget {
  const WealthBuilderScreen({super.key});

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
  final ValueNotifier<bool> _isBottomBarVisible = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _isBottomBarVisible.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
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

      // Use cached geo if available immediately, else baseline for first render
      final GeoResult? quickGeo = await GeoService.getCached();
      final targets = await WealthService.calculateAssetTargets(
        p,
        transactions,
        userProfile,
        baselineMonthlyIncome: quickGeo?.baselineMonthlyIncome ?? 25000,
      );

      final age = userProfile?.calculatedAge;

      if (mounted) {
        setState(() {
          portfolio = p;
          bankBalance = balance;
          smartInsights = insights;
          assetTargets = targets;
          userAge = age;
          geoResult = quickGeo;
          loading = false;
        });
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load wealth data. Pull down to retry.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gradientColors = isDark
        ? [
            const Color(0xFF1A1A2E),
            const Color(0xFF16213E).withValues(alpha: 0.95),
          ]
        : [const Color(0xFFF5F7FA), const Color(0xFFC3CFE2)];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
        bottomNavigationBar: ValueListenableBuilder<bool>(
          valueListenable: _isBottomBarVisible,
          builder: (context, visible, child) {
            return AnimatedSlide(
              duration: const Duration(milliseconds: 200),
              offset: visible ? Offset.zero : const Offset(0, 1),
              child: child,
            );
          },
          child: const BottomNavBar(currentIndex: 3),
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
          child: loading
              ? const WealthSkeleton()
              : (userAge == null ? _buildAgeBlocker(scheme) : RefreshIndicator(
                  onRefresh: _loadData,
                  color: const Color(0xFF00E5FF),
                  backgroundColor: const Color(0xFF1A1A2E),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 10.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (userAge != null)
                          Container(
                            width: double.infinity,
                            margin: EdgeInsets.only(bottom: 12.h),
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 12.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF00E5FF,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color: const Color(
                                  0xFF00E5FF,
                                ).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.verified_user_outlined,
                                  color: const Color(0xFF00E5FF),
                                  size: 20.sp,
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Text(
                                    "Personalized Strategy (Age: $userAge)",
                                    style: TextStyle(
                                      color: const Color(0xFF00E5FF),
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (geoResult != null && geoResult!.city.isNotEmpty)
                          _buildGeoBadge(geoResult!),
                        SizedBox(height: 8.h),
                        _buildNetWorthCard(scheme),
                        SizedBox(height: 20.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Your Assets",
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface,
                              ),
                            ),
                            IconButton(
                              onPressed: _showVisibilityDialog,
                              icon: Icon(
                                Icons.tune_rounded,
                                color: scheme.onSurface.withValues(alpha: 0.6),
                              ),
                              tooltip: "Manage Visibility",
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        _buildAssetGrid(scheme),
                        SizedBox(height: 20.h),
                        Text(
                          "Allocation",
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: scheme.onSurface,
                          ),
                        ),
                        SizedBox(height: 10.h),
                        _buildPieChart(scheme),
                        SizedBox(height: 20.h),
                        Text(
                          "Smart Suggestions",
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: scheme.onSurface,
                          ),
                        ),
                        SizedBox(height: 10.h),
                        _buildSuggestions(scheme),
                        SizedBox(height: 100.h), // Bottom padding
                      ],
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
                color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cake_outlined,
                size: 56.sp,
                color: const Color(0xFF00E5FF),
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
                  backgroundColor: const Color(0xFF00E5FF),
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

  Widget _buildGeoBadge(GeoResult geo) {
    const zoneColor = Color(0xFF69F0AE);
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
            child: Text(
              '~₹${(geo.baselineMonthlyIncome / 1000).toStringAsFixed(0)}K/mo',
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

  Widget _buildAssetGrid(ColorScheme scheme) {
    if (portfolio == null) return const SizedBox.shrink();
    final p = portfolio!;

    // ── helpers ──────────────────────────────────────────────────────────────
    int multiplier = 6;
    if (userAge != null) {
      if (userAge! < 30) { multiplier = 3; }
      else if (userAge! > 50) { multiplier = 12; }
    }
    final monthlyExpense = (assetTargets['bank']?.formula ?? 0) / multiplier;

    Widget card(String title, double amount, String key, IconData icon, Color color) =>
        _assetCard(title, amount, key, icon, color, scheme);

    List<Widget> addIf(String key, Widget Function() builder) =>
        p.hiddenKeys.contains(key) ? [] : [builder()];

    // ── sections ─────────────────────────────────────────────────────────────
    final sections = <Widget>[];

    // 1. Liquid & Fixed Income
    final liquidCards = <Widget>[
      _assetCard("Cash / Bank", bankBalance, 'bank', Icons.account_balance, Colors.teal, scheme,
          readOnly: true,
          secondaryLabel: monthlyExpense > 0 ? "Monthly Expense" : null,
          secondaryValue: monthlyExpense > 0 ? monthlyExpense : null),
      ...addIf('fd',         () => card("FD / RD",              p.fd,         'fd',         Icons.savings,                    Colors.orange)),
      ...addIf('ppf',        () => card("PPF",                  p.ppf,        'ppf',        Icons.savings_outlined,            Colors.lightBlue)),
      ...addIf('postOffice', () => card("Post Office Schemes",  p.postOffice, 'postOffice', Icons.local_post_office,           Colors.red.shade300)),
      ...addIf('bonds',      () => card("Bonds (Govt/Corp)",    p.bonds,      'bonds',      Icons.receipt_long,                Colors.blueGrey)),
      ...addIf('chitFund',   () => card("Chit Fund",            p.chitFund,   'chitFund',   Icons.groups,                      Colors.teal.shade300)),
    ];
    if (liquidCards.isNotEmpty) {
      sections.add(_sectionHeader("Liquid & Fixed Income"));
      sections.add(GridView.count(
        crossAxisCount: 2, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12.w, mainAxisSpacing: 12.h, childAspectRatio: 0.8,
        children: liquidCards,
      ));
      sections.add(SizedBox(height: 20.h));
    }

    // 2. Equity & Growth
    final equityCards = <Widget>[
      ...addIf('stocks',       () => card("Stocks",                p.stocks,       'stocks',       Icons.show_chart,          Colors.purple)),
      ...addIf('sip',          () => card("Mutual Funds (SIP)",    p.sip,          'sip',          Icons.pie_chart,           Colors.blue)),
      ...addIf('etf',          () => card("ETFs",                  p.etf,          'etf',          Icons.stacked_line_chart,  Colors.cyan)),
      ...addIf('foreignStocks',() => card("Foreign Stocks",        p.foreignStocks,'foreignStocks',Icons.language,            Colors.deepPurple)),
      ...addIf('startupEquity',() => card("Angel / Startup",       p.startupEquity,'startupEquity',Icons.rocket_launch,       Colors.orange)),
    ];
    if (equityCards.isNotEmpty) {
      sections.add(_sectionHeader("Equity & Growth"));
      sections.add(GridView.count(
        crossAxisCount: 2, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12.w, mainAxisSpacing: 12.h, childAspectRatio: 0.8,
        children: equityCards,
      ));
      sections.add(SizedBox(height: 20.h));
    }

    // 3. Retirement
    final retirementCards = <Widget>[
      ...addIf('pf',  () => card("PF / EPF",       p.pf,  'pf',  Icons.account_balance_wallet,          Colors.green)),
      ...addIf('vpf', () => card("Voluntary PF",   p.vpf, 'vpf', Icons.account_balance_wallet_outlined,  Colors.green.shade300)),
      ...addIf('nps', () => card("NPS",             p.nps, 'nps', Icons.elderly,                          Colors.indigo)),
    ];
    if (retirementCards.isNotEmpty) {
      sections.add(_sectionHeader("Retirement"));
      sections.add(GridView.count(
        crossAxisCount: 2, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12.w, mainAxisSpacing: 12.h, childAspectRatio: 0.8,
        children: retirementCards,
      ));
      sections.add(SizedBox(height: 20.h));
    }

    // 4. Alternative Assets
    final altCards = <Widget>[
      ...addIf('gold',    () => card("Gold / Silver",          p.gold,    'gold',    Icons.grid_goldenratio,   Colors.amber)),
      ...addIf('sgb',     () => card("Sovereign Gold Bonds",   p.sgb,     'sgb',     Icons.monetization_on,    Colors.amber.shade300)),
      ...addIf('jewelry', () => card("Jewelry / Diamonds",     p.jewelry, 'jewelry', Icons.diamond,            Colors.pink.shade300)),
      ...addIf('crypto',  () => card("Crypto",                 p.crypto,  'crypto',  Icons.currency_bitcoin,   Colors.deepOrange)),
      ...addIf('reit',    () => card("REITs",                  p.reit,    'reit',    Icons.apartment,          Colors.tealAccent.shade700)),
      ...addIf('p2p',     () => card("P2P Lending",            p.p2p,     'p2p',     Icons.people_alt,         Colors.lime)),
    ];
    if (altCards.isNotEmpty) {
      sections.add(_sectionHeader("Alternative Assets"));
      sections.add(GridView.count(
        crossAxisCount: 2, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12.w, mainAxisSpacing: 12.h, childAspectRatio: 0.8,
        children: altCards,
      ));
      sections.add(SizedBox(height: 20.h));
    }

    // 5. Physical Assets
    final physicalCards = <Widget>[
      ...addIf('realEstate', () => card("Real Estate",       p.realEstate, 'realEstate', Icons.domain,       Colors.brown)),
      ...addIf('agriLand',   () => card("Agricultural Land", p.agriLand,   'agriLand',   Icons.grass,        Colors.green)),
      ...addIf('vehicle',    () => card("Vehicle(s)",        p.vehicle,    'vehicle',    Icons.directions_car,Colors.blueGrey.shade300)),
    ];
    if (physicalCards.isNotEmpty) {
      sections.add(_sectionHeader("Physical Assets"));
      sections.add(GridView.count(
        crossAxisCount: 2, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12.w, mainAxisSpacing: 12.h, childAspectRatio: 0.8,
        children: physicalCards,
      ));
      sections.add(SizedBox(height: 20.h));
    }

    // 6. Protection
    final protectionCards = <Widget>[
      ...addIf('insurance', () => card("Life Insurance / ULIP", p.insurance, 'insurance', Icons.health_and_safety,  Colors.pink)),
      ...addIf('business',  () => card("Business Capital",      p.business,  'business',  Icons.business_center,    Colors.brown.shade300)),
    ];
    if (protectionCards.isNotEmpty) {
      sections.add(_sectionHeader("Protection & Business"));
      sections.add(GridView.count(
        crossAxisCount: 2, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12.w, mainAxisSpacing: 12.h, childAspectRatio: 0.8,
        children: protectionCards,
      ));
      sections.add(SizedBox(height: 20.h));
    }

    // 7. Liabilities
    final loanController = LoanController.to;
    final loanCount = loanController.loans.length;
    final liabilityCards = <Widget>[
      if (!p.hiddenKeys.contains('loans'))
        _assetCard("Loans / Liabilities", loanController.totalOutstanding, 'loans',
            Icons.money_off, Colors.red, scheme,
            secondaryLabel: loanCount > 0 ? "$loanCount loan${loanCount > 1 ? 's' : ''}" : null,
            onTapOverride: () => Get.to(() => const LoanTrackerScreen())),
      ...addIf('creditCard', () => card("Credit Card Outstanding", p.creditCard, 'creditCard', Icons.credit_card,  Colors.red.shade700)),
      ...addIf('bnpl',       () => card("BNPL / Pay Later",        p.bnpl,       'bnpl',       Icons.schedule,     Colors.deepOrange.shade700)),
    ];
    if (liabilityCards.isNotEmpty) {
      sections.add(_sectionHeader("Liabilities"));
      sections.add(GridView.count(
        crossAxisCount: 2, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12.w, mainAxisSpacing: 12.h, childAspectRatio: 0.8,
        children: liabilityCards,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  Widget _sectionHeader(String label) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h, top: 4.h),
      child: Row(
        children: [
          Expanded(child: Divider(color: scheme.onSurface.withValues(alpha: 0.15), height: 1)),
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
          Expanded(child: Divider(color: scheme.onSurface.withValues(alpha: 0.15), height: 1)),
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
  }) {
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
      onTap: onTapOverride ?? () => _showUpdateDialog(title, key, amount, readOnly: readOnly),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.1), // Glassy background
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.05),
              Colors.white.withValues(alpha: 0.01),
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
              ],
            ),
            SizedBox(height: 12.h),
            Text(
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
                      wealthTarget?.isEstimated == true
                          ? "Suggested: ${formatter.format(target)}"
                          : "Target: ${formatter.format(target)}",
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: wealthTarget?.isEstimated == true
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
                  readOnly ? "Update Expense" : "Tap to update",
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

    final valueController = TextEditingController(
      text: currentVal == 0 ? '' : currentVal.toStringAsFixed(0),
    );

    final wealthTarget = assetTargets[key];
    final formulaVal = wealthTarget?.formula ?? 0;

    // For Bank, we want to show/edit the Monthly Expense, not the Total Target.
    // Reverse calculate the expense from the target.
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
    }

    final targetController = TextEditingController(
      text: displayTargetVal == 0 ? '' : displayTargetVal.toStringAsFixed(0),
    );

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
              width: 340.w,
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                // ... same premium decoration
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E1A47), Color(0xFF1A1A2E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28.r),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 30,
                    offset: Offset(0, 10),
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
                        color: Colors.white,
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
                            ? Colors.white54
                            : Colors.white,
                        fontSize: 18.sp,
                      ),
                      decoration: InputDecoration(
                        labelText: isBank
                            ? "Current Bank Balance"
                            : "Current Value",
                        labelStyle: TextStyle(color: Colors.white60),
                        hintText: "0",
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        prefixText: symbol,
                        prefixStyle: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Target Input (Editable for Bank Expense)
                    TextField(
                      controller: targetController,
                      // Bank Expense is EDITABLE. Formula Targets are READ-ONLY.
                      readOnly: !isBank,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: !isBank
                            ? Colors.white.withValues(alpha: 0.7)
                            : Colors.white,
                        fontSize: 18.sp,
                      ),
                      decoration: InputDecoration(
                        labelText: isBank
                            ? "Monthly Expense Basis"
                            : "Target Goal (Formula)",
                        labelStyle: TextStyle(color: const Color(0xFF00E5FF)),
                        hintText: isBank ? "Enter expense" : "Auto-calculated",
                        helperText: isBank
                            ? "Leave empty to use auto-calculated average"
                            : "Calculated based on expenses & age",
                        helperStyle: TextStyle(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                          fontSize: 11.sp,
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(
                            color: const Color(
                              0xFF00E5FF,
                            ).withValues(alpha: 0.5),
                          ),
                        ),
                        prefixText: symbol,
                        prefixStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),

                    SizedBox(height: 24.h),

                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              "Cancel",
                              style: TextStyle(color: Colors.white54),
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
                                final val = double.tryParse(text.replaceAll(',', '')) ?? 0;
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
                                    double.tryParse(valueController.text.replaceAll(',', '')) ?? 0;
                                await WealthService.updateAsset(key, val);
                              }
                              // Formula targets are not updated explicitly

                              await _loadData();
                              if (context.mounted) Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00E5FF),
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
  }

  Future<void> _showVisibilityDialog() async {
    final Map<String, String> assets = {
      // Liquid & Fixed Income
      'bank':        "Cash / Bank",
      'fd':          "FD / RD",
      'ppf':         "PPF",
      'postOffice':  "Post Office Schemes",
      'bonds':       "Bonds (Govt/Corp)",
      'chitFund':    "Chit Fund",
      // Equity & Growth
      'stocks':        "Stocks",
      'sip':           "Mutual Funds (SIP)",
      'etf':           "ETFs",
      'foreignStocks': "Foreign Stocks",
      'startupEquity': "Angel / Startup Equity",
      // Retirement
      'pf':  "PF / EPF",
      'vpf': "Voluntary PF (VPF)",
      'nps': "NPS",
      // Alternative Assets
      'gold':    "Gold / Silver",
      'sgb':     "Sovereign Gold Bonds",
      'jewelry': "Jewelry / Diamonds",
      'crypto':  "Crypto",
      'reit':    "REITs",
      'p2p':     "P2P Lending",
      // Physical Assets
      'realEstate': "Real Estate",
      'agriLand':   "Agricultural Land",
      'vehicle':    "Vehicle(s)",
      // Protection
      'insurance': "Life Insurance / ULIP",
      'business':  "Business Capital",
      // Liabilities
      'loans':      "Loans / Liabilities",
      'creditCard': "Credit Card Outstanding",
      'bnpl':       "BNPL / Pay Later",
    };

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
                  width: 340.w,
                  constraints: BoxConstraints(maxHeight: 600.h),
                  padding: EdgeInsets.all(24.w),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E1A47), Color(0xFF1A1A2E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28.r),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
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
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: assets.entries.map((e) {
                            final key = e.key;
                            final title = e.value;
                            final isVisible = !hidden.contains(key);
                            return CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                title,
                                style: const TextStyle(color: Colors.white70),
                              ),
                              value: isVisible,
                              activeColor: const Color(0xFF00E5FF),
                              checkColor: Colors.black,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                              onChanged: (val) {
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
                              child: const Text(
                                "Cancel",
                                style: TextStyle(color: Colors.white54),
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
                                backgroundColor: const Color(0xFF00E5FF),
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
    final hidden = p.hiddenKeys;
    final List<PieChartSectionData> sections = [];

    void add(double val, String key, Color color, String title) {
      if (!hidden.contains(key) && val > 0) {
        sections.add(
          PieChartSectionData(
            value: val,
            color: color,
            radius: 50,
            title: title,
            titleStyle: const TextStyle(fontSize: 10, color: Colors.white),
          ),
        );
      }
    }

    add(bankBalance, 'bank', Colors.teal, 'Bank');
    add(p.sip, 'sip', Colors.blue, 'SIP');
    add(p.fd, 'fd', Colors.orange, 'FD');
    add(p.stocks, 'stocks', Colors.purple, 'Stocks');
    add(p.pf, 'pf', Colors.green, 'PF');
    add(p.crypto, 'crypto', Colors.amber, 'Crypto');
    add(p.gold, 'gold', Colors.yellow[700]!, 'Gold');
    add(p.realEstate, 'realEstate', Colors.brown, 'RE');
    add(p.nps, 'nps', Colors.indigo, 'NPS');
    add(p.etf, 'etf', Colors.cyan, 'ETF');
    add(p.reit, 'reit', Colors.tealAccent.shade700, 'REIT');
    add(p.p2p, 'p2p', Colors.lime, 'P2P');

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

  // Placeholder comment in previous edit removed the method. Restoring it.
  Widget _buildNetWorthCard(ColorScheme scheme) {
    double total = 0;
    if (portfolio != null) {
      final p = portfolio!;
      final hidden = p.hiddenKeys;

      void add(String key, double val) { if (!hidden.contains(key)) total += val; }
      void sub(String key, double val) { if (!hidden.contains(key)) total -= val; }

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
      p.custom.forEach((key, val) { if (!hidden.contains(key)) total += val; });

      // Liabilities (subtract all)
      sub('loans', LoanController.to.totalOutstanding);
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
            blurRadius: 15,
            offset: const Offset(0, 8),
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
          Text(
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
