// lib/Screens/loginscreen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Controllers/auth_controller.dart';
import 'package:money_control/Screens/forgot_password.dart';
import 'package:money_control/Screens/signup.dart'; // Correct import

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  AuthController get _authController => Get.find<AuthController>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark ? AppColors.darkGradient : AppColors.lightGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHeader(theme, isDark)
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .slideY(begin: -0.2, end: 0, curve: Curves.easeOutBack),
                  SizedBox(height: 40.h),
                  _buildLoginForm(theme, isDark)
                      .animate()
                      .fadeIn(duration: 600.ms, delay: 200.ms)
                      .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
                  SizedBox(height: 20.h),
                  _buildSocialLogin(
                    theme,
                    isDark,
                  ).animate().fadeIn(duration: 600.ms, delay: 400.ms),
                  SizedBox(height: 30.h),
                  _buildFooter(
                    theme,
                    isDark,
                  ).animate().fadeIn(duration: 600.ms, delay: 600.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Icon(
            Icons.account_balance_wallet_rounded,
            size: 64.sp,
            color: AppColors.primary,
          ),
        ),
        SizedBox(height: 24.h),
        Text(
          "Welcome Back",
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          "Sign in to continue managing your finances",
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
            fontSize: 16.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(ThemeData theme, bool isDark) {
    return GlassContainer(
      padding: EdgeInsets.all(24.w),
      borderRadius: BorderRadius.circular(24.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Error Message
          Obx(() {
            if (_authController.errorMessage.value.isNotEmpty) {
              return Container(
                margin: EdgeInsets.only(bottom: 16.h),
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 20.sp,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        _authController.errorMessage.value,
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          }),

          // Email Field
          _buildTextField(
            controller: _emailController,
            label: "Email Address",
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            theme: theme,
            isDark: isDark,
          ),
          SizedBox(height: 20.h),

          // Password Field
          _buildTextField(
            controller: _passwordController,
            label: "Password",
            icon: Icons.lock_outline,
            isPassword: true,
            isPasswordVisible: _isPasswordVisible,
            onVisibilityChanged: () {
              setState(() {
                _isPasswordVisible = !_isPasswordVisible;
              });
            },
            theme: theme,
            isDark: isDark,
          ),
          SizedBox(height: 12.h),

          // Forgot Password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Get.to(() => const ForgotPasswordScreen());
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              ),
              child: Text(
                "Forgot Password?",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp),
              ),
            ),
          ),
          SizedBox(height: 24.h),

          // Login Button
          Obx(
            () => ElevatedButton(
              onPressed: _authController.isLoading.value
                  ? null
                  : () {
                      _authController.loginWithEmail(
                        _emailController.text,
                        _passwordController.text,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                elevation: 4,
                shadowColor: AppColors.primary.withValues(alpha: 0.4),
              ),
              child: _authController.isLoading.value
                  ? SizedBox(
                      height: 24.h,
                      width: 24.h,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      "Sign In",
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onVisibilityChanged,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
            fontSize: 14.sp,
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppColors.lightBorder,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword && !isPasswordVisible,
            keyboardType: keyboardType,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
            decoration: InputDecoration(
              hintText: "Enter your ${label.toLowerCase()}",
              hintStyle: TextStyle(
                color: isDark ? Colors.white30 : Colors.black38,
                fontSize: 14.sp,
              ),
              prefixIcon: Icon(
                icon,
                color: isDark ? Colors.white54 : AppColors.lightTextSecondary,
                size: 20.sp,
              ),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        isPasswordVisible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: isDark
                            ? Colors.white54
                            : AppColors.lightTextSecondary,
                        size: 20.sp,
                      ),
                      onPressed: onVisibilityChanged,
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 16.h,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialLogin(ThemeData theme, bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(
                color: isDark ? Colors.white24 : AppColors.lightDivider,
                thickness: 1,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Text(
                "Or continue with",
                style: TextStyle(
                  color: isDark ? Colors.white54 : AppColors.lightTextSecondary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: isDark ? Colors.white24 : AppColors.lightDivider,
                thickness: 1,
              ),
            ),
          ],
        ),
        SizedBox(height: 24.h),
        GlassContainer(
          borderRadius: BorderRadius.circular(16.r),
          onTap: () => _authController.loginWithGoogle(),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/google.png',
                  height: 24.h,
                  width: 24.h,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.public,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  "Sign in with Google",
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16.sp,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(ThemeData theme, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account?",
          style: TextStyle(
            color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
            fontSize: 14.sp,
          ),
        ),
        TextButton(
          onPressed: () {
            Get.to(
              () => const AuthScreen(),
              transition: Transition.rightToLeft,
            );
          },
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: EdgeInsets.symmetric(horizontal: 8.w),
          ),
          child: Text(
            "Create Account",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
          ),
        ),
      ],
    );
  }
}
