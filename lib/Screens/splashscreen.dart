import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:money_control/Components/animated_widget.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/methods.dart';
import 'package:money_control/Models/splash_data.dart';
import 'package:money_control/Screens/loginscreen.dart';
import 'package:money_control/Services/performance_controller.dart';
import 'package:money_control/l10n/app_localizations.dart';

/// First screen of the app — three onboarding pages over a themed gradient.
///
/// Copy comes from the ARB (the three headlines and subtitles used to be inline
/// English, invisible to the audit because they were named arguments rather than
/// `Text('…')`). The CTA is a [FilledButton], whose theme owns the fill, radius,
/// padding and label — this screen used to hand-build a gradient container,
/// a 28 px pill and a 0.3-alpha glow around a transparent button.
class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen> {
  int currentIndex = 0;

  List<SplashData> _pages(AppLocalizations l10n) => [
    SplashData(
      bgColor: AppColors.primary,
      image: 'assets/salary.png',
      headline: l10n.splashHeadlineSaveMoney,
      subtitle: l10n.splashSubtitleSaveMoney,
      buttonText: l10n.splashGetStarted,
    ),
    SplashData(
      bgColor: AppColors.primaryPress,
      image: 'assets/accounting.png',
      headline: l10n.splashHeadlineTrackExpenses,
      subtitle: l10n.splashSubtitleTrackExpenses,
      buttonText: l10n.splashContinue,
    ),
    SplashData(
      bgColor: AppColors.secondary,
      image: 'assets/wallet.png',
      headline: l10n.splashHeadlineFillWallet,
      subtitle: l10n.splashSubtitleFillWallet,
      buttonText: l10n.splashLetsStart,
    ),
  ];

  void _nextPage(int pageCount) {
    if (currentIndex < pageCount - 1) {
      setState(() => currentIndex++);
    } else {
      gotoPage(const LoginScreen());
    }
  }

  void _prevPage() {
    if (currentIndex > 0) {
      setState(() => currentIndex--);
    }
  }

  /// Lite mode renders statically instead of running fade/slide animations.
  Widget _entrance(Widget child, {required double slideFrom}) {
    if (PerformanceController.to.liteMode.value) return child;
    return child
        .animate()
        .fadeIn(duration: AppMotion.entrance)
        .slideY(begin: slideFrom, end: 0, curve: AppMotion.standard);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pages = _pages(l10n);
    final page = pages[currentIndex];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final liteMode = PerformanceController.to.liteMode.value;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    Widget illustration = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.10),
            blurRadius: 60.w,
            spreadRadius: 20.w,
          ),
        ],
      ),
      child: CAnimatedWidget(image: page.image),
    );
    if (!liteMode) {
      illustration = illustration
          .animate(key: ValueKey(currentIndex))
          .scale(
            duration: AppMotion.slow,
            curve: AppMotion.entranceCurve,
          );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [AppColors.darkBackground, AppColors.darkSurface]
                : [AppColors.lightBackground, AppColors.lightActionSurface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onHorizontalDragEnd: (details) {
                    final v = details.primaryVelocity;
                    if (v == null) return;
                    if (v < 0) {
                      _nextPage(pages.length);
                    } else if (v > 0) {
                      _prevPage();
                    }
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      illustration,
                      SizedBox(height: AppSpace.s40.h),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpace.pageGutter.w,
                        ),
                        child: AnimatedSwitcher(
                          duration: AppMotion.base,
                          child: Column(
                            key: ValueKey(page.headline),
                            children: [
                              _entrance(
                                Text(
                                  page.headline,
                                  textAlign: TextAlign.center,
                                  style: AppType.headlineMedium(textColor),
                                ),
                                slideFrom: 0.3,
                              ),
                              SizedBox(height: AppSpace.s16.h),
                              _entrance(
                                Text(
                                  page.subtitle,
                                  textAlign: TextAlign.center,
                                  style: AppType.bodyLarge(secondaryColor),
                                ),
                                slideFrom: 0.1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpace.pageGutter.w,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          pages.length,
                          (index) => AnimatedContainer(
                            duration: AppMotion.fast,
                            curve: AppMotion.standard,
                            margin: EdgeInsets.symmetric(
                              horizontal: AppSpace.s4.w,
                            ),
                            height: 8.h,
                            width: currentIndex == index ? 24.w : 8.w,
                            decoration: BoxDecoration(
                              color: currentIndex == index
                                  ? AppColors.primary
                                  : isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill.r),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        height: 56.h,
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => _nextPage(pages.length),
                          child: Text(page.buttonText),
                        ),
                      ),
                      SizedBox(height: AppSpace.s32.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
