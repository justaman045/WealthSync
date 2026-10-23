import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Config/app_strings.dart';
import 'package:money_control/Config/wealth_asset_registry.dart';

/// Age-based recommendations for the wealth screen.
///
/// The per-asset age windows live on [WealthAssetDescriptor] in the registry,
/// next to the label and the colour. They used to live here, in a 26-entry
/// copy of the same metadata, and had already drifted from the cards.
class WealthAgeRecommendations {
  WealthAgeRecommendations._();

  static const String _ageBasedEnabledKey = 'wealth_age_based_enabled';
  static const String _agePromptShownKey = 'wealth_age_prompt_shown';

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
  static Set<String> getRecommendedCardKeys(int age) =>
      WealthAssetRegistry.recommendedFor(age);

  // ── Smart Mode phases ────────────────────────────────────────────────────
  // Recommended order for a 26-year-old starting out: foundations first,
  // then long-term growth, alternatives only once the base is solid.
  static const Map<String, int> _phaseByKey = {
    // 1 · Start here — liquidity, protection, debt
    'bank': 1, 'fd': 1, 'postOffice': 1, 'insurance': 1,
    'loans': 1, 'creditCard': 1, 'bnpl': 1,
    // 2 · Build wealth — growth + retirement
    'sip': 2, 'stocks': 2, 'etf': 2, 'pf': 2, 'ppf': 2, 'vpf': 2,
    'nps': 2, 'bonds': 2, 'realEstate': 2, 'agriLand': 2, 'vehicle': 2,
    // 3 · Advanced — alternatives & high risk
    'gold': 3, 'sgb': 3, 'jewelry': 3, 'crypto': 3, 'reit': 3, 'p2p': 3,
    'foreignStocks': 3, 'startupEquity': 3, 'chitFund': 3, 'business': 3,
  };

  /// Recommended order phase for a card key (1 = start here … 3 = advanced).
  static int phaseFor(String key) => _phaseByKey[key] ?? 2;

  static String phaseName(int phase) => switch (phase) {
        1 => 'Start here',
        2 => 'Build wealth',
        _ => 'Advanced',
      };

  static String phaseSubtitle(int phase) => switch (phase) {
        1 => 'Emergency fund, protection and paying off debt come first.',
        2 => 'Long-term growth and retirement accumulation for the long run.',
        _ => 'Diversifiers for when your foundation is solid.',
      };

  static IconData phaseIcon(int phase) => switch (phase) {
        1 => Icons.shield_outlined,
        2 => Icons.trending_up_rounded,
        _ => Icons.auto_awesome,
      };

  static Color phaseColor(int phase) => switch (phase) {
        1 => AppColors.success,
        2 => AppColors.primary,
        _ => AppColors.secondary,
      };

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
                      child: Text(AppStrings.showAllCards),
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
