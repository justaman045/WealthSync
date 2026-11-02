import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'package:money_control/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Services/payment_config_service.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Utils/payment_config_fields.dart';
import 'package:money_control/Utils/responsive.dart';
import 'package:money_control/Services/error_handler.dart';

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  late final PaymentConfigService _service;
  late final TextEditingController _upiCtrl;

  /// The form. Seeded from the service, then owned by the admin until saved.
  late String _mode;

  /// What the form was last synced to. A remote change may overwrite the form
  /// only while it still equals this snapshot, otherwise the admin's edit wins.
  late String _savedMode;
  late String _savedUpi;

  bool _saving = false;

  /// A save from another device landed while this form had unsaved edits.
  bool _remoteChanged = false;

  Worker? _modeWorker;
  Worker? _upiWorker;

  @override
  void initState() {
    super.initState();
    _service = PaymentConfigService.to;
    _mode = normalizePaymentMode(_service.paymentMode.value);
    _savedMode = _mode;
    _upiCtrl = TextEditingController(text: normalizeUpiId(_service.upiId.value));
    _savedUpi = _upiCtrl.text;

    // The config is live: another admin can flip the mode while this screen is
    // open. Without this the screen kept showing the values it read in
    // initState and a later save silently reverted their change.
    _modeWorker = ever(_service.paymentMode, (_) => _onRemoteChange());
    _upiWorker = ever(_service.upiId, (_) => _onRemoteChange());
  }

  @override
  void dispose() {
    _modeWorker?.dispose();
    _upiWorker?.dispose();
    _upiCtrl.dispose();
    super.dispose();
  }

  String get _remoteMode => normalizePaymentMode(_service.paymentMode.value);
  String get _remoteUpi => normalizeUpiId(_service.upiId.value);

  /// An untouched form follows the remote config; an edited one does not.
  bool get _formUntouched => !paymentConfigIsDirty(
    mode: _mode,
    upi: _upiCtrl.text,
    savedMode: _savedMode,
    savedUpi: _savedUpi,
  );

  bool get _dirty => paymentConfigIsDirty(
    mode: _mode,
    upi: _upiCtrl.text,
    savedMode: _remoteMode,
    savedUpi: _remoteUpi,
  );

  void _onRemoteChange() {
    if (!mounted) return;
    final untouched = _formUntouched;
    setState(() {
      if (untouched) {
        _mode = _remoteMode;
        _upiCtrl.text = _remoteUpi;
        _savedMode = _remoteMode;
        _savedUpi = _remoteUpi;
        _remoteChanged = false;
      } else {
        _remoteChanged = true;
      }
    });
  }

  void _reload() {
    setState(() {
      _mode = _remoteMode;
      _upiCtrl.text = _remoteUpi;
      _savedMode = _mode;
      _savedUpi = _upiCtrl.text;
      _remoteChanged = false;
    });
  }

  Future<void> _save() async {
    final upi = _upiCtrl.text.trim();
    if (_mode == 'upi' && upi.isEmpty) {
      ErrorHandler.showError(
        'Please enter your UPI ID before switching to UPI mode.',
        title: 'Missing UPI ID',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await PaymentConfigService.to.saveConfig(mode: _mode, upi: upi);
      if (!mounted) return;
      setState(() {
        _savedMode = _mode;
        _savedUpi = upi;
        _remoteChanged = false;
      });
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
              child: Obx(
                // Rebuild when the live config or its audit trail changes.
                () => ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _upiCtrl,
                  builder: (context, _, __) => _buildForm(context, isDark),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.paymentMode,
            style: AppType.bodySmall(isDark ? Colors.white70 : AppColors.lightTextSecondary)),
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
        if (_remoteChanged) ...[
          _buildRemoteChangeBanner(l10n, isDark),
          SizedBox(height: 16.h),
        ],
        // Always visible: the UPI id used to be hidden until UPI mode was
        // selected, so it could not be checked (or corrected) while the mode
        // was still Play Billing — and an empty id only surfaced on save.
        Text(l10n.upiID,
            style: AppType.bodySmall(isDark
                    ? Colors.white70
                    : AppColors.lightTextSecondary)),
        SizedBox(height: 8.h),
        GlassContainer(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
          borderRadius: BorderRadius.circular(14.r),
          child: TextField(
            controller: _upiCtrl,
            style: AppType.bodyLarge(isDark ? Colors.white : AppColors.lightTextPrimary),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'yourname@upi',
              hintStyle: AppType.bodyLarge(isDark
                      ? Colors.white38
                      : AppColors.lightTextTertiary),
              prefixIcon: const Icon(Icons.alternate_email, color: AppColors.primary),
            ),
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          l10n.usersAskedPayUPIID,
          style: AppType.bodySmall(isDark
                  ? Colors.white38
                  : AppColors.lightTextTertiary),
        ),
        SizedBox(height: 12.h),
        _buildLastUpdated(l10n, isDark),
        SizedBox(height: 32.h),
        SizedBox(
          width: double.infinity,
          height: 52.h,
          child: ElevatedButton(
            // A save that changes nothing still bumps `updatedAt` and tells the
            // other admin their config was replaced, so a clean form cannot save.
            onPressed: (_saving || !_dirty) ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md.r),
              ),
            ),
            // The spinner was black on the indigo fill (3.1:1); the label
            // size now comes from the button theme.
            child: _saving
                ? SizedBox(
                    width: 22.w,
                    height: 22.h,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(l10n.saveSettings),
          ),
        ),
      ],
    );
  }

  Widget _buildRemoteChangeBanner(AppLocalizations l10n, bool isDark) {
    return GlassContainer(
      padding: EdgeInsets.all(12.w),
      borderRadius: BorderRadius.circular(14.r),
      child: Row(
        children: [
          const Icon(Icons.sync_problem, color: AppColors.warning, size: 20),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              l10n.paymentSettingsChangedElsewhere,
              style: AppType.bodySmall(isDark
                  ? Colors.white70
                  : AppColors.lightTextSecondary),
            ),
          ),
          TextButton(
            onPressed: _reload,
            child: Text(l10n.reload),
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdated(AppLocalizations l10n, bool isDark) {
    final updatedAt = _service.updatedAt.value;
    final updatedBy = _service.updatedBy.value;
    if (updatedAt == null && updatedBy.isEmpty) {
      return const SizedBox.shrink();
    }
    final stamp = updatedAt == null
        ? ''
        : ' · ${DateFormat.yMMMd().add_Hm().format(updatedAt)}';
    final who = updatedBy.isEmpty ? '' : ' $updatedBy';
    return Text(
      '${l10n.paymentSettingsLastUpdated}$who$stamp',
      style: AppType.bodySmall(
        isDark ? Colors.white38 : AppColors.lightTextTertiary,
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
    return GlassContainer(
      onTap: () => setState(() => _mode = mode),
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
                    style: AppType.labelLarge(selected
                            ? isDark
                                ? Colors.white
                                : AppColors.lightTextPrimary
                            : isDark
                                ? Colors.white60
                                : AppColors.lightTextSecondary)),
                SizedBox(height: 4.h),
                Text(subtitle,
                    style: AppType.bodySmall(isDark
                            ? Colors.white38
                            : AppColors.lightTextTertiary)),
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
    );
  }
}
