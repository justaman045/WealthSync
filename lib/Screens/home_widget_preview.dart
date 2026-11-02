import 'package:money_control/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Controllers/privacy_controller.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Services/widget_action_queue.dart';
import 'package:money_control/Services/widget_service.dart';
import 'package:money_control/Utils/responsive.dart';
import 'package:money_control/Utils/widget_action.dart';

/// Shows a live mock of the Android home-screen widget plus setup instructions.
/// Reachable from Settings → General → Appearance → Home Widget.
///
/// The mock is not decorative: its `+ Add` fires the same queued action the
/// real widget sends, so what the user tries here is exactly the behaviour they
/// get on their home screen. The switch below it writes the preference the
/// widget itself reads.
class HomeWidgetPreviewScreen extends StatefulWidget {
  const HomeWidgetPreviewScreen({super.key});

  @override
  State<HomeWidgetPreviewScreen> createState() =>
      _HomeWidgetPreviewScreenState();
}

class _HomeWidgetPreviewScreenState extends State<HomeWidgetPreviewScreen> {
  late final TransactionController _transactionController;

  /// Mirrors the widget's own preference; the default matches Android's
  /// (`mc_show_quick_add` absent ⇒ shortcut visible).
  bool _showQuickAdd = true;

  /// Serialises preference writes so two fast toggles cannot land out of order
  /// and leave the widget showing the opposite of the switch.
  Future<void> _settingsChain = Future<void>.value();

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<TransactionController>()) {
      Get.put(TransactionController());
    }
    _transactionController = Get.find<TransactionController>();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final show = await WidgetService.showQuickAdd();
    if (!mounted) return;
    setState(() => _showQuickAdd = show);
  }

  void _setShowQuickAdd(bool value) {
    // Optimistic: the switch must respond instantly; the write is local and
    // [WidgetService.updateSettings] swallows plugin failures.
    setState(() => _showQuickAdd = value);
    _settingsChain = _settingsChain
        .then((_) => WidgetService.updateSettings(showQuickAdd: value))
        .catchError((Object _) {});
  }

  /// Replays the widget's `+ Add` tap through the same queue the OS tap uses,
  /// so the preview cannot drift from the real navigation path.
  void _tryAddTransaction() {
    WidgetActionQueue.push(WidgetAction.addTransaction);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(l10n.homeWidget),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        titleTextStyle: AppType.titleMedium(isDark ? Colors.white : AppColors.lightTextPrimary),
      ),
      body: Container(
        height: double.infinity,
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: Responsive.contentMaxWidth(context),
                ),
                child: Column(
                  children: [
                    SizedBox(height: 10.h),
                    _buildWidgetPreview(),
                    SizedBox(height: 12.h),
                    _buildQuickAddSwitch(isDark),
                    SizedBox(height: 20.h),
                    _buildStep(
                      step: "1",
                      title: l10n.homeWidgetStepAddTitle,
                      body: l10n.homeWidgetStepAddBody,
                      icon: Icons.add_box_outlined,
                    ),
                    _buildStep(
                      step: "2",
                      title: l10n.homeWidgetStepTapTitle,
                      body: l10n.homeWidgetStepTapBody,
                      icon: Icons.login_rounded,
                    ),
                    _buildStep(
                      step: "3",
                      title: l10n.homeWidgetStepRefreshTitle,
                      body: l10n.homeWidgetStepRefreshBody,
                      icon: Icons.auto_awesome_rounded,
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAddSwitch(bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: SwitchListTile.adaptive(
        value: _showQuickAdd,
        onChanged: _setShowQuickAdd,
        title: Text(
          l10n.homeWidgetQuickAddTitle,
          style: AppType.labelLarge(
            isDark ? Colors.white : AppColors.lightTextPrimary,
          ),
        ),
        subtitle: Text(
          l10n.homeWidgetQuickAddSubtitle,
          style: AppType.bodySmall(
            isDark ? Colors.white54 : AppColors.lightTextSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildWidgetPreview() {
    final l10n = AppLocalizations.of(context)!;
    final currency = CurrencyController.to.currencySymbol.value;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.darkBackground,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.wealthsync,
            style: AppType.labelSmall(Colors.white.withValues(alpha: 0.6)),
          ),
          SizedBox(height: 4.h),
          PrivacyText(
            "$currency${_transactionController.totalBalance.toStringAsFixed(2)}",
            style: AppType.headlineSmall(Colors.white),
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              Text(
                l10n.homeWidgetTotalBalance,
                style: AppType.labelSmall(Colors.white.withValues(alpha: 0.4)),
              ),
              const Spacer(),
              if (_showQuickAdd)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _tryAddTransaction,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 4.h,
                    ),
                    child: Text(
                      l10n.add2,
                      style: AppType.labelSmall(AppColors.primary),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required String step,
    required String title,
    required String body,
    required IconData icon,
    bool isLast = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : AppColors.lightBorder.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 20.sp),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$step. $title",
                  style: AppType.labelLarge(isDark ? Colors.white : AppColors.lightTextPrimary),
                ),
                SizedBox(height: 4.h),
                Text(
                  body,
                  style: AppType.bodySmall(isDark
                        ? Colors.white54
                        : AppColors.lightTextSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
