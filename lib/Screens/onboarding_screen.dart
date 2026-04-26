import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Screens/homescreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:money_control/l10n/app_localizations.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _budgetController = TextEditingController();
  late ConfettiController _confettiController;
  String _selectedCurrency = '₹';
  String? _userName;
  bool _isLoading = false;

  final List<String> _currencies = ['₹', '\$', '€', '£', '¥'];

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
    super.dispose();
  }

  Future<void> _fetchUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _userName = user?.displayName?.split(' ').first ?? "User";
    });
  }

  Future<void> _finishSetup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // 1. Save to Firestore
        final budget = double.tryParse(_budgetController.text) ?? 0;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.email)
            .set({
              'currency': _selectedCurrency,
              'monthly_budget': budget,
              'is_onboarded': true,
            }, SetOptions(merge: true));

        // 2. Save to SharedPreferences for local check
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_onboarded', true);
        await prefs.setString('currency_symbol', _selectedCurrency);
      }

      // 3. Play Confetti & Navigate Home
      _confettiController.play();
      await Future.delayed(const Duration(seconds: 1)); // Wait a bit for effect

      Get.offAll(() => const BankingHomeScreen());
    } catch (e) {
      if (!mounted) return;
      Get.snackbar(
        AppLocalizations.of(context)!.error,
        "Setup failed: $e",
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 40.h),
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
                    SizedBox(height: 30.h),
                    Text(
                      l10n.welcomeUser(_userName ?? '...'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 28.sp,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      l10n.onboardingSubtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 16.sp,
                      ),
                    ),
                    SizedBox(height: 40.h),

                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Step 1: Currency
                          Text(
                            l10n.chooseCurrencyStep,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          GlassContainer(
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCurrency,
                                isExpanded: true,
                                dropdownColor: isDark
                                    ? AppColors.darkSurface
                                    : Colors.white,
                                icon: Icon(
                                  Icons.arrow_drop_down_rounded,
                                  color: AppColors.primary,
                                  size: 30.sp,
                                ),
                                items: _currencies
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(
                                          c,
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 18.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedCurrency = v!),
                              ),
                            ),
                          ),

                          SizedBox(height: 24.h),

                          // Step 2: Budget
                          Text(
                            l10n.setBudgetStep,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          GlassContainer(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 8.h,
                            ),
                            child: TextFormField(
                              controller: _budgetController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                hintText: l10n.budgetHint,
                                hintStyle: TextStyle(
                                  color: textColor.withValues(alpha: 0.4),
                                  fontWeight: FontWeight.normal,
                                ),
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
                        ],
                      ),
                    ),

                    SizedBox(height: 60.h),

                    GestureDetector(
                      onTap: _isLoading ? null : _finishSetup,
                      child: Container(
                        width: double.infinity,
                        height: 56.h,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                          ),
                          borderRadius: BorderRadius.circular(16.r),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                l10n.startTracking,
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: 30.h),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
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
