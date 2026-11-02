import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Services/income_settings.dart';
import 'package:money_control/Utils/income_mode_label.dart';
import 'package:money_control/Utils/wealth_math.dart';
import 'package:money_control/l10n/app_localizations.dart';

/// Explains the three ways the app can estimate monthly income, and lets the
/// user pick one (plus the amount, for Manual) in the same place.
///
/// Before this existed the modes were a bare radio list of labels in Settings:
/// "Auto – Blend (3-month average)" and "Auto – Salary window (…)" gave no clue
/// what they would do to the daily limit, and AI Insights showed a mode the
/// user had never chosen. One sheet is now the single place both screens send
/// people to.
///
/// Returns `true` when a mode was saved.
Future<bool> showIncomeModeSheet(BuildContext context) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _IncomeModeSheet(),
  );
  // The sheet is a one-time explainer on AI Insights; dismissing it counts as
  // an answer ("keep the default") so it does not reopen on every visit.
  await IncomeSettings.markConfirmed();
  return saved ?? false;
}

String _hintFor(AppLocalizations l10n, IncomeMode mode) {
  switch (mode) {
    case IncomeMode.manual:
      return l10n.incomeModeManualHint;
    case IncomeMode.autoBlend:
      return l10n.incomeModeBlendHint;
    case IncomeMode.autoSalaryWindow:
      return l10n.incomeModeSalaryWindowHint;
  }
}

class _IncomeModeSheet extends StatefulWidget {
  const _IncomeModeSheet();

  @override
  State<_IncomeModeSheet> createState() => _IncomeModeSheetState();
}

class _IncomeModeSheetState extends State<_IncomeModeSheet> {
  late IncomeMode _mode = IncomeSettings.mode.value;
  late final TextEditingController _amountCtrl = TextEditingController(
    text: IncomeSettings.manualMonthly.value > 0
        ? IncomeSettings.manualMonthly.value.toStringAsFixed(0)
        : '',
  );
  bool _saving = false;
  bool _manualMissing = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final text = _amountCtrl.text.trim();
    double amount = 0;
    if (text.isNotEmpty) {
      final parsed = double.tryParse(text.replaceAll(',', ''));
      if (parsed == null || !parsed.isFinite || parsed < 0) {
        setState(() => _manualMissing = _mode == IncomeMode.manual);
        return;
      }
      amount = parsed;
    }
    if (_mode == IncomeMode.manual && amount <= 0) {
      // Keep the sheet open rather than saving an empty manual income that the
      // daily limit would then ignore while still claiming Manual mode.
      setState(() => _manualMissing = true);
      return;
    }

    setState(() {
      _manualMissing = false;
      _saving = true;
    });
    await IncomeSettings.setMode(_mode);
    if (_mode == IncomeMode.manual) {
      await IncomeSettings.setManual(amount);
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final symbol = CurrencyController.to.currencySymbol.value;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.incomeSource,
                style: AppType.titleMedium(scheme.onSurface),
              ),
              SizedBox(height: 6.h),
              Text(
                l10n.incomeModeChooserIntro,
                style: AppType.bodySmall(
                  scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              SizedBox(height: 16.h),
              for (final mode in IncomeMode.values) ...[
                _modeCard(scheme, l10n, mode),
                SizedBox(height: 10.h),
              ],
              if (_mode == IncomeMode.manual) ...[
                SizedBox(height: 6.h),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.incomeModeManualAmountLabel,
                    prefixText: symbol,
                    errorText: _manualMissing
                        ? l10n.incomeModeManualRequired
                        : null,
                  ),
                  onChanged: (_) {
                    if (_manualMissing) {
                      setState(() => _manualMissing = false);
                    }
                  },
                ),
                SizedBox(height: 6.h),
              ],
              SizedBox(height: 8.h),
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(
                    _saving ? l10n.loading : l10n.save,
                  ),
                ),
              ),
              SizedBox(height: 4.h),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeCard(
    ColorScheme scheme,
    AppLocalizations l10n,
    IncomeMode mode,
  ) {
    final selected = _mode == mode;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
        onTap: () => setState(() => _mode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppRadius.lg.r),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : scheme.outlineVariant.withValues(alpha: 0.6),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? AppColors.primary : scheme.onSurfaceVariant,
                size: 20.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incomeModeLabel(l10n, mode),
                      style: AppType.labelLarge(scheme.onSurface),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      _hintFor(l10n, mode),
                      style: AppType.bodySmall(
                        scheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
