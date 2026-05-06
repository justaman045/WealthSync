import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Services/payment_config_service.dart';

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
    _mode = PaymentConfigService.to.paymentMode.value;
    _upiCtrl = TextEditingController(text: PaymentConfigService.to.upiId.value);
  }

  @override
  void dispose() {
    _upiCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_mode == 'upi' && _upiCtrl.text.trim().isEmpty) {
      Get.snackbar('Missing UPI ID', 'Please enter your UPI ID before switching to UPI mode.',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }
    setState(() => _saving = true);
    try {
      await PaymentConfigService.to.save(mode: _mode, upi: _upiCtrl.text.trim());
      Get.snackbar('Saved', 'Payment settings updated.',
          backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Error', 'Failed to save: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Payment Settings',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Payment Mode', style: TextStyle(color: Colors.white70, fontSize: 13.sp)),
              SizedBox(height: 12.h),
              _buildModeCard(
                mode: 'google_play',
                label: 'Google Play Billing',
                subtitle: 'Users pay via Google Play Store. Requires Play Console setup.',
                icon: Icons.shop_rounded,
                color: Colors.greenAccent,
              ),
              SizedBox(height: 12.h),
              _buildModeCard(
                mode: 'upi',
                label: 'Manual UPI',
                subtitle: 'Users pay to your UPI ID and submit the transaction ID for manual approval.',
                icon: Icons.account_balance_wallet_rounded,
                color: Colors.cyanAccent,
              ),
              SizedBox(height: 32.h),
              if (_mode == 'upi') ...[
                Text('Your UPI ID', style: TextStyle(color: Colors.white70, fontSize: 13.sp)),
                SizedBox(height: 8.h),
                GlassContainer(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                  borderRadius: BorderRadius.circular(14.r),
                  child: TextField(
                    controller: _upiCtrl,
                    style: TextStyle(color: Colors.white, fontSize: 16.sp),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'yourname@upi',
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 16.sp),
                      prefixIcon: const Icon(Icons.alternate_email, color: Colors.cyanAccent),
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Users will be asked to pay this UPI ID and enter the resulting transaction ID.',
                  style: TextStyle(color: Colors.white38, fontSize: 12.sp),
                ),
                SizedBox(height: 32.h),
              ],
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                      : Text('Save Settings', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
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
              child: Icon(icon, color: selected ? color : Colors.white38, size: 24.sp),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: selected ? Colors.white : Colors.white60,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 4.h),
                  Text(subtitle,
                      style: TextStyle(color: Colors.white38, fontSize: 12.sp)),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Container(
              width: 22.w,
              height: 22.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? color : Colors.white24, width: 2),
                color: selected ? color : Colors.transparent,
              ),
              child: selected ? const Icon(Icons.check, color: Colors.black, size: 14) : null,
            ),
          ],
        ),
      ),
    );
  }
}
