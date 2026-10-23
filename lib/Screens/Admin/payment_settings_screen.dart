import 'package:money_control/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Services/payment_config_service.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Utils/responsive.dart';
import 'package:money_control/Services/error_handler.dart';

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  late String _mode;
  late TextEditingController _upiCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mode = PaymentConfigService.to.paymentMode.value.isNotEmpty
        ? PaymentConfigService.to.paymentMode.value
        : 'cash';
    _upiCtrl = TextEditingController(text: PaymentConfigService.to.upiId.value);
  }

  @override
  void dispose() {
    _upiCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_mode == 'upi' && _upiCtrl.text.trim().isEmpty) {
      ErrorHandler.showError(
        'Please enter your UPI ID before switching to UPI mode.',
        title: 'Missing UPI ID',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await PaymentConfigService.to.save(mode: _mode, upi: _upiCtrl.text.trim());
      ErrorHandler.showSuccess('Payment settings updated.', title: 'Saved');
    } catch (e) {
      ErrorHandler.showError('Failed to save: $e', title: 'Error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.darkBackground, AppColors.darkSurface, AppColors.darkSurface]
              : AppColors.lightGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.paymentSettings,
              style: TextStyle(
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(AppLocalizations.of(context)!.paymentMode,
                  style: TextStyle(
                      color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                      fontSize: 13.sp)),
              SizedBox(height: 12.h),
              _buildModeCard(
                mode: 'google_play',
                label: 'Google Play Billing',
                subtitle: 'Users pay via Google Play Store. Requires Play Console setup.',
                icon: Icons.shop_rounded,
                color: AppColors.success,
              ),
              SizedBox(height: 12.h),
              _buildModeCard(
                mode: 'upi',
                label: 'Manual UPI',
                subtitle: 'Users pay to your UPI ID and submit the transaction ID for manual approval.',
                icon: Icons.account_balance_wallet_rounded,
                color: AppColors.primary,
              ),
              SizedBox(height: 32.h),
              if (_mode == 'upi') ...[
                Text(AppLocalizations.of(context)!.upiID,
                    style: TextStyle(
                        color: isDark
                            ? Colors.white70
                            : AppColors.lightTextSecondary,
                        fontSize: 13.sp)),
                SizedBox(height: 8.h),
                GlassContainer(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                  borderRadius: BorderRadius.circular(14.r),
                  child: TextField(
                    controller: _upiCtrl,
                    style: TextStyle(
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        fontSize: 16.sp),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'yourname@upi',
                      hintStyle: TextStyle(
                          color: isDark
                              ? Colors.white38
                              : AppColors.lightTextTertiary,
                          fontSize: 16.sp),
                      prefixIcon: const Icon(Icons.alternate_email, color: AppColors.primary),
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  AppLocalizations.of(context)!.usersAskedPayUPIID,
                  style: TextStyle(
                      color: isDark
                          ? Colors.white38
                          : AppColors.lightTextTertiary,
                      fontSize: 12.sp),
                ),
                SizedBox(height: 32.h),
              ],
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                  ),
                  child: _saving
                      ? SizedBox(
                          width: 22.w, height: 22.h,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                      : Text(AppLocalizations.of(context)!.saveSettings, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required String mode,
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final selected = _mode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: GlassContainer(
        padding: EdgeInsets.all(16.w),
        borderRadius: BorderRadius.circular(16.r),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: color.withValues(alpha: selected ? 0.2 : 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: selected
                    ? color
                    : isDark
                        ? Colors.white38
                        : AppColors.lightTextTertiary,
                size: 24.sp,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: selected
                              ? isDark
                                  ? Colors.white
                                  : AppColors.lightTextPrimary
                              : isDark
                                  ? Colors.white60
                                  : AppColors.lightTextSecondary,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 4.h),
                  Text(subtitle,
                      style: TextStyle(
                          color: isDark
                              ? Colors.white38
                              : AppColors.lightTextTertiary,
                          fontSize: 12.sp)),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Container(
              width: 22.w,
              height: 22.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: selected ? color : isDark ? Colors.white24 : AppColors.lightBorder,
                    width: 2),
                color: selected ? color : Colors.transparent,
              ),
              child: selected ? Icon(Icons.check, color: Colors.black, size: 14.sp) : null,
            ),
          ],
        ),
      ),
    );
  }
}
