import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:money_control/Components/animated_widget.dart';
import 'package:money_control/Components/methods.dart';
import 'package:money_control/Models/splash_data.dart';
import 'package:money_control/Screens/loginscreen.dart';

class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen> {
  static const List<SplashData> splashPages = [
    SplashData(
      bgColor: Color(0xFF2B2B8E), // Legacy color kept for model compatibility
      image: 'assets/salary.png',
      headline: 'Save your Money',
      subtitle:
          'Discover smart ways to manage your finances and grow your savings—start making your money work for you, effortlessly and securely.',
      buttonText: 'Get Started',
    ),
    SplashData(
      bgColor: Color(0xFF347EA3),
      image: 'assets/accounting.png',
      headline: 'Track Your Expenses',
      subtitle:
          'Monitor your spending habits effortlessly and take control of your financial goals in real time.',
      buttonText: 'Continue',
    ),
    SplashData(
      bgColor: Color(0xFF89BCE6),
      image: 'assets/wallet.png',
      headline: 'Fill Your Wallet',
      subtitle:
          'Take control of your earnings by working smarter and building your own success story.',
      buttonText: 'Let\'s Start',
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

  @override
  Widget build(BuildContext context) {
    final splashData = splashPages[currentIndex];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gradientColors = isDark
        ? [
            const Color(0xFF1A1A2E), // Midnight Void
            const Color(0xFF16213E).withValues(alpha: 0.95),
            const Color(0xFF0F3460),
          ]
        : [
            const Color(0xFFF5F7FA), // Premium Light
            const Color(0xFFC3CFE2),
            const Color(0xFFE3F2FD),
          ];

    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final secondaryTextColor = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : const Color(0xFF1A1A2E).withValues(alpha: 0.7);

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
                    if (details.primaryVelocity! < 0) {
                      _nextPage();
                    } else if (details.primaryVelocity! > 0) {
                      _prevPage();
                    }
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Image Container with Glow
                      Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: isDark
                                      ? const Color(
                                          0xFF6C63FF,
                                        ).withValues(alpha: 0.15)
                                      : const Color(
                                          0xFF3F51B5,
                                        ).withValues(alpha: 0.1),
                                  blurRadius: 60,
                                  spreadRadius: 20,
                                ),
                              ],
                            ),
                            child: CAnimatedWidget(image: splashData.image),
                          )
                          .animate(key: ValueKey(currentIndex))
                          .scale(duration: 600.ms, curve: Curves.easeOutBack),
                      SizedBox(height: 40.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.w),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          child: Column(
                            key: ValueKey(splashData.headline),
                            children: [
                              Text(
                                    splashData.headline,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 28.sp,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                      letterSpacing: 0.5,
                                    ),
                                  )
                                  .animate()
                                  .fadeIn(duration: 600.ms)
                                  .slideY(
                                    begin: 0.3,
                                    end: 0,
                                    curve: Curves.easeOut,
                                  ),
                              SizedBox(height: 16.h),
                              Text(
                                    splashData.subtitle,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      color: secondaryTextColor,
                                      height: 1.5,
                                    ),
                                  )
                                  .animate()
                                  .fadeIn(duration: 600.ms, delay: 100.ms)
                                  .slideY(begin: 0.1, end: 0),
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
                                        ? const Color(0xFF6C63FF)
                                        : Colors.deepPurple)
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
                                        const Color(0xFF6C63FF),
                                        const Color(0xFF4834D4),
                                      ]
                                    : [
                                        const Color(
                                          0xFF6C63FF,
                                        ).withValues(alpha: 0.9),
                                        const Color(
                                          0xFF4834D4,
                                        ).withValues(alpha: 0.9),
                                      ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF6C63FF,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
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
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
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
