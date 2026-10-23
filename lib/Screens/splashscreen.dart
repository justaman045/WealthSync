import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:money_control/Components/animated_widget.dart';
import 'package:money_control/Components/methods.dart';
import 'package:money_control/Config/app_strings.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Models/splash_data.dart';
import 'package:money_control/Screens/loginscreen.dart';
import 'package:money_control/Services/performance_controller.dart';

class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen> {
  static const List<SplashData> splashPages = [
    SplashData(
      bgColor: AppColors.primary,
      image: 'assets/salary.png',
      headline: 'Save your Money',
      subtitle:
          'Discover smart ways to manage your finances and grow your savings—start making your money work for you, effortlessly and securely.',
      buttonText: AppStrings.getStarted,
    ),
    SplashData(
      bgColor: AppColors.primaryPress,
      image: 'assets/accounting.png',
      headline: 'Track Your Expenses',
      subtitle:
          'Monitor your spending habits effortlessly and take control of your financial goals in real time.',
      buttonText: AppStrings.continueLabel,
    ),
    SplashData(
      bgColor: AppColors.secondary,
      image: 'assets/wallet.png',
      headline: 'Fill Your Wallet',
      subtitle:
          'Take control of your earnings by working smarter and building your own success story.',
      buttonText: AppStrings.letsStart,
    ),
  ];

  int currentIndex = 0;

  void _nextPage() {
    if (currentIndex < splashPages.length - 1) {
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

  /// Lite mode: render statically instead of running the fade/slide-in so the
  /// splash paints with no animation work on low-end devices.
  Widget _fadeSlide(Widget child, {required double slideBegin}) {
    if (PerformanceController.to.liteMode.value) return child;
    return child
        .animate()
        .fadeIn(duration: 600.ms)
        .slideY(begin: slideBegin, end: 0);
  }

  @override
  Widget build(BuildContext context) {
    final splashData = splashPages[currentIndex];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gradientColors = isDark
        ? [
            AppColors.darkBackground, // Midnight Void
            AppColors.darkSurface.withValues(alpha: 0.95),
            AppColors.darkSurface,
          ]
        : [
            AppColors.lightBackground, // Premium Light
            AppColors.lightBorder,
            AppColors.lightActionSurface,
          ];

    final textColor = isDark ? Colors.white : AppColors.darkBackground;
    final secondaryTextColor = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : AppColors.darkBackground.withValues(alpha: 0.7);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
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
                      _nextPage();
                    } else if (v > 0) {
                      _prevPage();
                    }
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Image Container with Glow
                      (PerformanceController.to.liteMode.value
                          ? Container(
                              decoration: BoxDecoration(shape: BoxShape.circle),
                              child: CAnimatedWidget(image: splashData.image),
                            )
                          : Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: isDark
                                            ? AppColors.primary.withValues(alpha: 0.15)
                                            : const Color(
                                                0xFF3F51B5,
                                              ).withValues(alpha: 0.1),
                                        blurRadius: 60.w,
                                        spreadRadius: 20.w,
                                      ),
                                    ],
                                  ),
                                  child: CAnimatedWidget(
                                    image: splashData.image,
                                  ),
                                )
                                .animate(key: ValueKey(currentIndex))
                                .scale(
                                  duration: 600.ms,
                                  curve: Curves.easeOutBack,
                                )),
                      SizedBox(height: 40.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.w),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          child: Column(
                            key: ValueKey(splashData.headline),
                            children: [
                              _fadeSlide(
                                Text(
                                  splashData.headline,
                                  textAlign: TextAlign.center,
                                  style: AppType.headlineMedium(textColor),
                                ),
                                slideBegin: 0.3,
                              ),
                              SizedBox(height: 16.h),
                              _fadeSlide(
                                Text(
                                  splashData.subtitle,
                                  textAlign: TextAlign.center,
                                  style: AppType.bodyLarge(secondaryTextColor),
                                ),
                                slideBegin: 0.1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Section: Indicators + Button
              Expanded(
                flex: 1,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Page Indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          splashPages.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: EdgeInsets.symmetric(horizontal: 4.w),
                            height: 8.h,
                            width: currentIndex == index ? 24.w : 8.w,
                            decoration: BoxDecoration(
                              color: currentIndex == index
                                  ? (isDark
                                        ? AppColors.primary
                                        : AppColors.accent)
                                  : (isDark
                                        ? Colors.white.withValues(alpha: 0.2)
                                        : Colors.black.withValues(alpha: 0.1)),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),

                      // Action Button
                      Container(
                            width: double.infinity,
                            height: 56.h,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28.r),
                              gradient: LinearGradient(
                                colors: isDark
                                    ? [
                                        AppColors.primary,
                                        AppColors.primaryPress,
                                      ]
                                    : [
                                        AppColors.primary.withValues(alpha: 0.9),
                                        AppColors.primaryPress.withValues(alpha: 0.9),
                                      ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 15.w,
                                  offset: Offset(0, 8.w),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _nextPage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28.r),
                                ),
                              ),
                              child: Text(
                                splashData.buttonText,
                                style: AppType.titleMedium(Colors.white),
                              ),
                            ),
                          )
                          .animate(
                            target: currentIndex == splashPages.length - 1
                                ? 1
                                : 0,
                          )
                          .fadeIn(duration: 500.ms)
                          .scale(
                            begin: const Offset(0.9, 0.9),
                            end: const Offset(1, 1),
                          ),
                      SizedBox(height: 30.h),
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
