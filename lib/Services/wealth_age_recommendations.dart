import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:money_control/Components/colors.dart';

class WealthCardRecommendation {
  final String key;
  final String name;
  final IconData icon;
  final Color color;
  final int minAge;
  final int maxAge;
  final String reason;

  const WealthCardRecommendation({
    required this.key,
    required this.name,
    required this.icon,
    required this.color,
    this.minAge = 0,
    this.maxAge = 100,
    this.reason = '',
  });

  bool isRecommendedFor(int age) => age >= minAge && age <= maxAge;
}

class WealthAgeRecommendations {
  WealthAgeRecommendations._();

  static const String _ageBasedEnabledKey = 'wealth_age_based_enabled';
  static const String _agePromptShownKey = 'wealth_age_prompt_shown';

  // Age-based card recommendations
  // minAge/maxAge define the range where this card is RECOMMENDED
  static final List<WealthCardRecommendation> allCards = [
    // ── Liquid & Fixed Income ───────────────────────────────────────
    WealthCardRecommendation(
      key: 'bank', name: 'Cash / Bank',
      icon: Icons.account_balance, color: Colors.teal,
      minAge: 0, maxAge: 100,
      reason: 'Essential at every age for daily expenses and emergency access.',
    ),
    WealthCardRecommendation(
      key: 'fd', name: 'FD / RD',
      icon: Icons.savings, color: Colors.orange,
      minAge: 18, maxAge: 100,
      reason: 'Safe, guaranteed returns. Great for conservative savings at any age.',
    ),
    WealthCardRecommendation(
      key: 'ppf', name: 'PPF',
      icon: Icons.savings_outlined, color: Colors.lightBlue,
      minAge: 18, maxAge: 55,
      reason: '15-year lock-in makes it ideal for young and mid-career long-term savings.',
    ),
    WealthCardRecommendation(
      key: 'postOffice', name: 'Post Office Schemes',
      icon: Icons.local_post_office, color: Colors.red,
      minAge: 18, maxAge: 100,
      reason: 'Government-backed, safe returns. Good for conservative investors.',
    ),
    WealthCardRecommendation(
      key: 'bonds', name: 'Bonds (Govt/Corp)',
      icon: Icons.receipt_long, color: Colors.blueGrey,
      minAge: 18, maxAge: 70,
      reason: 'Safe, regular income. Good for capital preservation at any age.',
    ),
    WealthCardRecommendation(
      key: 'chitFund', name: 'Chit Fund',
      icon: Icons.groups, color: Colors.teal.shade300,
      minAge: 21, maxAge: 60,
      reason: 'Community-based savings. Useful for disciplined regular saving.',
    ),

    // ── Equity & Growth ────────────────────────────────────────────
    WealthCardRecommendation(
      key: 'stocks', name: 'Stocks',
      icon: Icons.show_chart, color: Colors.purple,
      minAge: 18, maxAge: 55,
      reason: 'Higher risk, higher reward. Start early and reduce exposure as retirement nears.',
    ),
    WealthCardRecommendation(
      key: 'sip', name: 'Mutual Funds (SIP)',
      icon: Icons.pie_chart, color: Colors.blue,
      minAge: 18, maxAge: 60,
      reason: 'Rupee cost averaging makes SIPs ideal for disciplined long-term wealth creation.',
    ),
    WealthCardRecommendation(
      key: 'etf', name: 'ETFs',
      icon: Icons.stacked_line_chart, color: Colors.cyan,
      minAge: 18, maxAge: 55,
      reason: 'Low-cost index tracking. Great diversification for long-term investors.',
    ),
    WealthCardRecommendation(
      key: 'foreignStocks', name: 'Foreign Stocks',
      icon: Icons.language, color: Colors.deepPurple,
      minAge: 25, maxAge: 50,
      reason: 'Geographic diversification. Best during peak earning years with a strong domestic base.',
    ),
    WealthCardRecommendation(
      key: 'startupEquity', name: 'Angel / Startup',
      icon: Icons.rocket_launch, color: Colors.orange,
      minAge: 30, maxAge: 50,
      reason: 'Very high risk. Only for experienced investors with significant surplus capital.',
    ),

    // ── Retirement ─────────────────────────────────────────────────
    WealthCardRecommendation(
      key: 'pf', name: 'PF / EPF',
      icon: Icons.account_balance_wallet, color: Colors.green,
      minAge: 18, maxAge: 60,
      reason: 'Mandatory for salaried employees. Foundation of retirement planning.',
    ),
    WealthCardRecommendation(
      key: 'vpf', name: 'Voluntary PF',
      icon: Icons.account_balance_wallet_outlined, color: Colors.green.shade300,
      minAge: 25, maxAge: 55,
      reason: 'Top up your PF for tax-free retirement corpus. Best during peak earning years.',
    ),
    WealthCardRecommendation(
      key: 'nps', name: 'NPS',
      icon: Icons.elderly, color: Colors.indigo,
      minAge: 25, maxAge: 60,
      reason: 'Tax-efficient retirement planning. Crucial to start before 45 for meaningful corpus.',
    ),

    // ── Alternative Assets ─────────────────────────────────────────
    WealthCardRecommendation(
      key: 'gold', name: 'Gold / Silver',
      icon: Icons.grid_goldenratio, color: Colors.amber,
      minAge: 0, maxAge: 100,
      reason: 'Hedge against inflation and uncertainty. Cultural and financial safety net.',
    ),
    WealthCardRecommendation(
      key: 'sgb', name: 'Sovereign Gold Bonds',
      icon: Icons.monetization_on, color: Colors.amber.shade300,
      minAge: 18, maxAge: 65,
      reason: 'Gold exposure with 2.5% interest. Better than physical gold for investors.',
    ),
    WealthCardRecommendation(
      key: 'jewelry', name: 'Jewelry / Diamonds',
      icon: Icons.diamond, color: Colors.pink.shade300,
      minAge: 0, maxAge: 100,
      reason: 'Traditional wealth store. Track for net worth, not investment.',
    ),
    WealthCardRecommendation(
      key: 'crypto', name: 'Crypto',
      icon: Icons.currency_bitcoin, color: Colors.deepOrange,
      minAge: 21, maxAge: 45,
      reason: 'Highly volatile. Only with money you can afford to lose. Reduce exposure after 45.',
    ),
    WealthCardRecommendation(
      key: 'reit', name: 'REITs',
      icon: Icons.apartment, color: Colors.tealAccent.shade700,
      minAge: 25, maxAge: 60,
      reason: 'Real estate exposure without buying property. Good for passive rental income.',
    ),
    WealthCardRecommendation(
      key: 'p2p', name: 'P2P Lending',
      icon: Icons.people_alt, color: Colors.lime,
      minAge: 25, maxAge: 50,
      reason: 'High-yield, high-risk lending. Diversify carefully and never over-allocate.',
    ),

    // ── Physical Assets ────────────────────────────────────────────
    WealthCardRecommendation(
      key: 'realEstate', name: 'Real Estate',
      icon: Icons.domain, color: Colors.brown,
      minAge: 25, maxAge: 100,
      reason: 'Major wealth builder. Track property value and rental income.',
    ),
    WealthCardRecommendation(
      key: 'agriLand', name: 'Agricultural Land',
      icon: Icons.grass, color: Colors.green,
      minAge: 25, maxAge: 100,
      reason: 'Long-term appreciation asset. Track for net worth.',
    ),
    WealthCardRecommendation(
      key: 'vehicle', name: 'Vehicle(s)',
      icon: Icons.directions_car, color: Colors.blueGrey,
      minAge: 18, maxAge: 100,
      reason: 'Depreciating asset but valuable. Track for accurate net worth.',
    ),

    // ── Protection & Business ──────────────────────────────────────
    WealthCardRecommendation(
      key: 'insurance', name: 'Life Insurance / ULIP',
      icon: Icons.health_and_safety, color: Colors.pink,
      minAge: 21, maxAge: 65,
      reason: 'Critical for anyone with dependents. Aim for 10× annual income coverage.',
    ),
    WealthCardRecommendation(
      key: 'business', name: 'Business Capital',
      icon: Icons.business_center, color: Colors.brown.shade300,
      minAge: 21, maxAge: 65,
      reason: 'Track your business investment for complete net worth picture.',
    ),

    // ── Liabilities ────────────────────────────────────────────────
    WealthCardRecommendation(
      key: 'loans', name: 'Loans / Liabilities',
      icon: Icons.money_off, color: Colors.red,
      minAge: 0, maxAge: 100,
      reason: 'Track all debts. Goal is always zero.',
    ),
    WealthCardRecommendation(
      key: 'creditCard', name: 'Credit Card Outstanding',
      icon: Icons.credit_card, color: Colors.red.shade700,
      minAge: 18, maxAge: 100,
      reason: 'High-interest debt. Pay off monthly to avoid compounding charges.',
    ),
    WealthCardRecommendation(
      key: 'bnpl', name: 'BNPL / Pay Later',
      icon: Icons.schedule, color: Colors.deepOrange.shade700,
      minAge: 18, maxAge: 60,
      reason: 'Short-term credit. Track to avoid hidden debt accumulation.',
    ),
  ];

  /// Check if user has enabled age-based recommendations
  static Future<bool> isAgeBasedEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_ageBasedEnabledKey) ?? false;
  }

  /// Check if the age prompt has been shown before
  static Future<bool> isAgePromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_agePromptShownKey) ?? false;
  }

  /// Enable or disable age-based recommendations
  static Future<void> setAgeBasedEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ageBasedEnabledKey, enabled);
  }

  /// Mark age prompt as shown
  static Future<void> markAgePromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_agePromptShownKey, true);
  }

  /// Get cards recommended for a given age
  static Set<String> getRecommendedCardKeys(int age) {
    return allCards
        .where((card) => card.isRecommendedFor(age))
        .map((card) => card.key)
        .toSet();
  }

  /// Get recommendation info for a specific card key
  static WealthCardRecommendation? getCardRecommendation(String key) {
    try {
      return allCards.firstWhere((card) => card.key == key);
    } catch (_) {
      return null;
    }
  }

  /// Show the age-based wealth prompt dialog
  /// Returns true if user enabled age-based, false otherwise
  static Future<bool> showAgePrompt(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        child: Container(
          constraints: BoxConstraints(maxWidth: 360.w),
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome,
                  size: 48.sp,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'Smart Wealth Builder',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
              Text(
                'We can personalize your wealth dashboard based on your age — showing the investment types that make the most sense for your life stage.\n\nFor example, a 15-year-old doesn\'t need crypto or NPS, while a 43-year-old shouldn\'t just keep money in a savings account.\n\nYou can still manually enable any card later.',
                style: TextStyle(
                  fontSize: 14.sp,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text('Show All Cards'),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text('Enable Smart Mode'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }
}
