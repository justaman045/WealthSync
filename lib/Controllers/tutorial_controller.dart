import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class TutorialController {
  static bool isTestMode = false;
  static const _keyHomeSeen = 'tutorial_home_seen';
  static const _keyAnalyticsSeen = 'tutorial_analytics_seen';

  // --- HOME SCREEN TUTORIAL ---
  static Future<void> showHomeTutorial(
    BuildContext context, {
    required GlobalKey keyTransactionList,
    required GlobalKey keyNavBar,
  }) async {
    if (isTestMode) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyHomeSeen) == true) return;

    // Delay to allow UI to settle
    await Future.delayed(const Duration(seconds: 1));
    if (!context.mounted) return;

    List<TargetFocus> targets = [];

    // Target 1: Recent Transactions (Swipe)
    targets.add(
      TargetFocus(
        identify: "home_swipe",
        keyTarget: keyTransactionList,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildTutorialContent(
                "Swipe Actions",
                "Swipe left on any transaction to Edit or Delete quickly.",
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: 10,
      ),
    );

    // Target 2: Deep Scroll (Navbar Hides)
    targets.add(
      TargetFocus(
        identify: "home_scroll",
        keyTarget: keyNavBar,
        alignSkip: Alignment.topLeft,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildTutorialContent(
                "Immersive Scrolling",
                "Scroll down to hide the navigation bar and see more content. Scroll up to bring it back.",
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: 10,
      ),
    );

    _showTutorial(context, targets, () async {
      await prefs.setBool(_keyHomeSeen, true);
    });
  }

  // --- ANALYTICS TUTORIAL ---
  static Future<void> showAnalyticsTutorial(
    BuildContext context, {
    required GlobalKey keyChart,
  }) async {
    if (isTestMode) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyAnalyticsSeen) == true) return;

    await Future.delayed(const Duration(seconds: 1));
    if (!context.mounted) return;

    List<TargetFocus> targets = [
      TargetFocus(
        identify: "analytics_chart",
        keyTarget: keyChart,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildTutorialContent(
                "Interactive Charts",
                "Tap on chart points to see precise values and details.",
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: 10,
      ),
    ];

    _showTutorial(context, targets, () async {
      await prefs.setBool(_keyAnalyticsSeen, true);
    });
  }

  // --- ADD TRANSACTION TUTORIAL ---
  static const _keyAddTransactionSeen = 'tutorial_add_transaction_seen';

  static Future<void> showAddTransactionTutorial(
    BuildContext context, {
    GlobalKey? keyReceipt,
    required GlobalKey keyCategory,
  }) async {
    if (isTestMode) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyAddTransactionSeen) == true) return;

    await Future.delayed(const Duration(seconds: 1));
    if (!context.mounted) return;

    List<TargetFocus> targets = [];

    // Target 1: Receipt Scanner (Optional)
    if (keyReceipt != null) {
      targets.add(
        TargetFocus(
          identify: "receipt_scanner",
          keyTarget: keyReceipt,
          alignSkip: Alignment.bottomLeft,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return _buildTutorialContent(
                  "AI Receipt Scanner",
                  "Scan receipts to automatically extract details like Amount, Date, and Category.",
                );
              },
            ),
          ],
          shape: ShapeLightFocus.Circle,
          radius: 10,
        ),
      );
    }

    // Target 2: Category Selector
    targets.add(
      TargetFocus(
        identify: "category_selector",
        keyTarget: keyCategory,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildTutorialContent(
                "Smart Categories",
                "Easily categorize your spending. Tap to select, press and hold to manage.",
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: 10,
      ),
    );

    _showTutorial(context, targets, () async {
      await prefs.setBool(_keyAddTransactionSeen, true);
    });
  }

  // --- HELPER ---
  static void _showTutorial(
    BuildContext context,
    List<TargetFocus> targets,
    Function() onFinish,
  ) {
    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black.withValues(alpha: 0.8),
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: onFinish,
      onSkip: () {
        onFinish();
        return true;
      },
    ).show(context: context);
  }

  static Widget _buildTutorialContent(String title, String desc) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: const Color(0xFF00E5FF),
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            desc,
            style: TextStyle(color: Colors.white, fontSize: 14.sp),
          ),
        ],
      ),
    );
  }
}
