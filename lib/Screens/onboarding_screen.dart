import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Utils/responsive.dart';
import 'package:money_control/Screens/main_shell.dart';
import 'package:money_control/Services/performance_controller.dart';
import 'package:money_control/Services/referral_service.dart';
import 'package:money_control/Services/error_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:money_control/l10n/app_localizations.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import 'package:money_control/Services/app_analytics.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _budgetController = TextEditingController();
  final _referralController = TextEditingController();
  late ConfettiController _confettiController;
  String _selectedCurrency = '₹';
  String? _userName;
  bool _isLoading = false;

  final List<Map<String, String>> _currencies = [
    {'code': 'INR', 'symbol': '₹'},
    {'code': 'USD', 'symbol': '\$'},
    {'code': 'EUR', 'symbol': '€'},
    {'code': 'GBP', 'symbol': '£'},
    {'code': 'JPY', 'symbol': '¥'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserName();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _budgetController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (!mounted) return;
    setState(() {
      _userName = user?.displayName?.split(' ').first ?? "User";
    });
  }

  Future<void> _finishSetup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Never fall through to the confetti + home navigation without a
        // session: the budget, currency and referral code the user just typed
        // would be silently thrown away, and home would then load an
        // unauthenticated account. Say so and keep them on onboarding.
        setState(() => _isLoading = false);
        ErrorHandler.showError(
          'Your session expired. Please sign in again to finish setup.',
          title: 'Session expired',
        );
        return;
      }
      final email = user.email;
      if (email == null) {
        // A Firebase user without an email cannot own a Firestore doc keyed by
        // email, so the writes below would silently create a doc named "null".
        setState(() => _isLoading = false);
        ErrorHandler.showError(
          'This account has no email address, so setup cannot be saved.',
          title: 'Setup failed',
        );
        return;
      }
      // 1. Save to Firestore
      final budget = double.tryParse(_budgetController.text) ?? 0;

      await FirebaseFirestore.instance.collection('users').doc(email).set({
        'currency': _selectedCurrency,
        'monthly_budget': budget,
        'is_onboarded': true,
      }, SetOptions(merge: true));

      // 2. Apply referral code if provided
      final referralCode = _referralController.text.trim();
      if (referralCode.isNotEmpty) {
        final applied = await ReferralService.applyReferralCode(referralCode);
        AppAnalytics.log(AnalyticsEvent.referralApplied, {'applied': applied});
        if (applied) {
          ErrorHandler.showSuccess("Referral code applied");
        } else {
          ErrorHandler.showError(
            "Invalid referral code. Setup continues — you can enter a "
            "different code later.",
            title: "Referral",
          );
        }
      }

      // 3. Save to SharedPreferences for local check. Stamped with the email
      // so a second account on this device is not waved past setup by the
      // previous account's flag.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_onboarded', true);
      await prefs.setString('is_onboarded_email', email);
      final currencyCode = _currencies.firstWhere(
        (c) => c['symbol'] == _selectedCurrency,
        orElse: () => const {'code': 'INR', 'symbol': '₹'},
      )['code']!;
      await prefs.setString('currency_code', currencyCode);
      await prefs.setString('currency_symbol', _selectedCurrency);

      // 4. Play Confetti & Navigate Home
      _confettiController.play();
      await Future.delayed(const Duration(seconds: 1)); // Wait a bit for effect

      Get.offAll(() => const MainShell());
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(
          "Setup failed: $e",
          title: AppLocalizations.of(context)!.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final hintColor =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    final l10n = AppLocalizations.of(context)!;

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
        body: Stack(
          alignment: Alignment.center,
          children: [
            SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: Responsive.contentMaxWidth(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: AppSpace.s40.h),
                        Center(
                          child: Container(
                            padding: EdgeInsets.all(20.r),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.rocket_launch_rounded,
                              size: 60.sp,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        SizedBox(height: AppSpace.s32.h),
                        Text(
                          l10n.welcomeUser(_userName ?? '...'),
                          style: AppType.headlineMedium(textColor),
                        ),
                        SizedBox(height: AppSpace.s8.h),
                        Text(
                          l10n.onboardingSubtitle,
                          style: AppType.bodyLarge(secondaryColor),
                        ),
                        SizedBox(height: AppSpace.s40.h),

                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Step 1: Currency
                              Text(
                                l10n.chooseCurrencyStep,
                                style: AppType.titleMedium(textColor),
                              ),
                              SizedBox(height: AppSpace.s12.h),
                              GlassContainer(
                                padding: EdgeInsets.symmetric(horizontal: 16.w),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedCurrency,
                                    isExpanded: true,
                                    dropdownColor: isDark
                                        ? AppColors.darkSurfaceCard
                                        : AppColors.lightSurface,
                                    icon: Icon(
                                      Icons.arrow_drop_down_rounded,
                                      color: AppColors.primary,
                                      size: 30.sp,
                                    ),
                                    items: _currencies
                                        .map(
                                          (c) => DropdownMenuItem(
                                            value: c['symbol'],
                                            child: Text(
                                              "${c['symbol']} (${c['code']})",
                                              style: AppType.titleMedium(textColor),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _selectedCurrency = v!),
                                  ),
                                ),
                              ),

                              SizedBox(height: AppSpace.s24.h),

                              // Step 2: Budget
                              Text(
                                l10n.setBudgetStep,
                                style: AppType.titleMedium(textColor),
                              ),
                              SizedBox(height: AppSpace.s12.h),
                              GlassContainer(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 8.h,
                                ),
                                child: TextFormField(
                                  controller: _budgetController,
                                  keyboardType: TextInputType.number,
                                  style: AppType.titleMedium(textColor),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    hintText: l10n.budgetHint,
                                    hintStyle: AppType.bodyLarge(hintColor),
                                    filled: false,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return l10n.enterBudgetError;
                                    }
                                    if (double.tryParse(v) == null) {
                                      return l10n.invalidNumberError;
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              SizedBox(height: AppSpace.s24.h),

                              // Step 3: Referral Code (optional)
                              Text(
                                l10n.onboardingReferralOptional,
                                style: AppType.titleMedium(textColor),
                              ),
                              SizedBox(height: AppSpace.s8.h),
                              Text(
                                l10n.onboardingReferralPitch,
                                style: AppType.bodySmall(AppColors.primary),
                              ),
                              SizedBox(height: AppSpace.s12.h),
                              GlassContainer(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 8.h,
                                ),
                                child: TextFormField(
                                  controller: _referralController,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  style: AppType.titleMedium(textColor),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    hintText: l10n.onboardingReferralHint,
                                    hintStyle: AppType.bodyLarge(hintColor),
                                    filled: false,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: AppSpace.s48.h),

                        SizedBox(
                          height: 56.h,
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _finishSetup,
                            child: _isLoading
                                ? SizedBox(
                                    height: 22.r,
                                    width: 22.r,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(l10n.startTracking),
                          ),
                        ),
                        SizedBox(height: AppSpace.s32.h),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: PerformanceController.to.liteMode.value
                  ? const SizedBox.shrink()
                  : ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirectionality: BlastDirectionality.explosive,
                      shouldLoop: false,
                      colors: const [
                        AppColors.success,
                        AppColors.primary,
                        AppColors.accent,
                        AppColors.warning,
                        AppColors.accent,
                      ],
                      createParticlePath: drawStar,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Path drawStar(Size size) {
    // Method to convert degree to radians
    double degToRad(double deg) => deg * (pi / 180.0);

    const numberOfPoints = 5;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final internalRadius = halfWidth / 2.5;
    final degreesPerStep = degToRad(360 / numberOfPoints);
    final halfDegreesPerStep = degreesPerStep / 2;
    final path = Path();
    final fullAngle = degToRad(360);
    path.moveTo(size.width, halfWidth);

    for (double step = 0; step < fullAngle; step += degreesPerStep) {
      path.lineTo(
        halfWidth + externalRadius * cos(step),
        halfWidth + externalRadius * sin(step),
      );
      path.lineTo(
        halfWidth + internalRadius * cos(step + halfDegreesPerStep),
        halfWidth + internalRadius * sin(step + halfDegreesPerStep),
      );
    }
    path.close();
    return path;
  }
}
