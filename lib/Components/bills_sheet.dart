import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Utils/bills_math.dart';
import 'package:money_control/l10n/app_localizations.dart';

/// Bottom sheet listing this month's bills, one row per category.
///
/// The number on each row is the *plan* from `Utils/bills_math.dart`: the
/// average of the months that have spending, raised by a recurring payment due
/// this month, unless the user has typed their own amount. Tapping a row edits
/// that amount; clearing it goes back to Auto.
Future<void> showBillsSheet(
  BuildContext context, {
  required MonthlyBills bills,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => _BillsSheet(bills: bills),
  );
}

/// Result of the amount dialog. `clear` means "back to Auto"; [amount] is only
/// meaningful when [clear] is false. A null result means the dialog was
/// dismissed without a choice.
class _AmountChoice {
  final double? amount;
  final bool clear;
  const _AmountChoice.amount(this.amount) : clear = false;
  const _AmountChoice.auto()
    : amount = null,
      clear = true;
}

class _BillsSheet extends StatefulWidget {
  final MonthlyBills bills;

  const _BillsSheet({required this.bills});

  @override
  State<_BillsSheet> createState() => _BillsSheetState();
}

class _BillsSheetState extends State<_BillsSheet> {
  late final List<MonthlyBill> _bills = List<MonthlyBill>.from(
    widget.bills.categories,
  );
  bool _saving = false;

  double get _plannedTotal =>
      _bills.fold<double>(0, (sum, bill) => sum + bill.plan);

  double get _committedTotal =>
      _bills.fold<double>(0, (sum, bill) => sum + bill.committed);

  Future<void> _edit(MonthlyBill bill) async {
    final l10n = AppLocalizations.of(context)!;
    final choice = await showDialog<_AmountChoice>(
      context: context,
      builder: (_) => _BillAmountDialog(
        title: bill.category,
        autoAmount: bill.autoAmount,
        currentOverride: bill.overrideAmount,
      ),
    );
    if (choice == null || !mounted) return;

    final controller = Get.isRegistered<TransactionController>()
        ? Get.find<TransactionController>()
        : null;
    if (controller == null) return;

    setState(() => _saving = true);
    final saved = await controller.setCategoryBillAmount(
      bill.category,
      choice.clear ? null : choice.amount,
    );
    if (!mounted) return;

    if (!saved) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.billsSaveFailed)));
      return;
    }

    setState(() {
      _saving = false;
      final index = _bills.indexWhere((b) => b.category == bill.category);
      if (index >= 0) {
        _bills[index] = bill.copyWithAmount(choice.clear ? 0 : choice.amount!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final sym = CurrencyController.to.currencySymbol.value;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.billsTitle, style: AppType.titleMedium(scheme.onSurface)),
                SizedBox(height: 4.h),
                Text(
                  l10n.billsSubtitle,
                  style: AppType.bodySmall(
                    scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    _total(
                      l10n.billsPlanned,
                      "$sym${_plannedTotal.toStringAsFixed(0)}",
                      scheme.onSurface,
                    ),
                    SizedBox(width: 24.w),
                    _total(
                      l10n.billsReserved,
                      "$sym${_committedTotal.toStringAsFixed(0)}",
                      scheme.primary,
                    ),
                  ],
                ),
                if (widget.bills.outstanding > 0) ...[
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 16.sp,
                        color: AppColors.warning,
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          l10n.billsOutstanding(
                            "$sym${widget.bills.outstanding.toStringAsFixed(0)}",
                          ),
                          style: AppType.labelSmall(AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: 4.h),
                Text(
                  l10n.billsTapToEdit,
                  style: AppType.labelSmall(
                    scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                SizedBox(height: 4.h),
              ],
            ),
          ),
          if (_saving) LinearProgressIndicator(minHeight: 2.h),
          Flexible(
            child: _bills.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(24.w),
                    child: Text(
                      l10n.billsEmpty,
                      style: AppType.bodyMedium(
                        scheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
                    itemCount: _bills.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: scheme.onSurface.withValues(alpha: 0.08),
                    ),
                    itemBuilder: (_, index) => _row(_bills[index], sym, scheme),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _total(String label, String value, Color color) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppType.labelSmall(
            scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        SizedBox(height: 2.h),
        Text(value, style: AppType.titleSmall(color)),
      ],
    );
  }

  Widget _row(MonthlyBill bill, String sym, ColorScheme scheme) {
    final l10n = AppLocalizations.of(context)!;
    final due = bill.dueDate;
    return InkWell(
      onTap: () => _edit(bill),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          bill.category,
                          style: AppType.labelLarge(scheme.onSurface),
                        ),
                      ),
                      if (bill.isOverridden) ...[
                        SizedBox(width: 6.w),
                        _chip(l10n.billsManual, scheme.primary),
                      ],
                      if (bill.isLiability) ...[
                        SizedBox(width: 6.w),
                        _chip(l10n.billsLiability, AppColors.warning),
                      ],
                      if (bill.isExcludedFromLimit) ...[
                        SizedBox(width: 6.w),
                        _chip(l10n.billsExcludedFromLimit, AppColors.lightTextTertiary),
                      ],
                    ],
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    due == null
                        ? bill.autoAmount > 0
                            ? l10n.billsAutoAmount(
                                "$sym${bill.autoAmount.toStringAsFixed(0)}",
                              )
                            : bill.spentThisMonth > 0
                                ? l10n.billsAutoAmountSpent(
                                    "$sym${bill.spentThisMonth.toStringAsFixed(0)}",
                                  )
                                : l10n.billsAutoAmount(
                                    "$sym${bill.autoAmount.toStringAsFixed(0)}",
                                  )
                        : l10n.billsDueOn(DateFormat.MMMd().format(due)),
                    style: AppType.labelSmall(
                      scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "$sym${bill.plan.toStringAsFixed(0)}",
                  style: AppType.labelLarge(
                    bill.isPaid ? AppColors.success : scheme.onSurface,
                  ),
                ),
                if (bill.remaining > 0) ...[
                  SizedBox(height: 3.h),
                  Text(
                    l10n.billsLeft(
                      "$sym${bill.remaining.toStringAsFixed(0)}",
                    ),
                    style: AppType.labelSmall(
                      scheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ],
            ),
            Icon(
              Icons.chevron_right,
              size: 18.sp,
              color: scheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(label, style: AppType.labelSmall(color)),
    );
  }
}

/// Owns its [TextEditingController]: the dialog rebuilds as the user types, so
/// a controller held by the caller would outlive the route's exit animation and
/// can be re-attached after disposal.
class _BillAmountDialog extends StatefulWidget {
  final String title;
  final double autoAmount;
  final double currentOverride;

  const _BillAmountDialog({
    required this.title,
    required this.autoAmount,
    required this.currentOverride,
  });

  @override
  State<_BillAmountDialog> createState() => _BillAmountDialogState();
}

class _BillAmountDialogState extends State<_BillAmountDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.currentOverride > 0
        ? widget.currentOverride.toStringAsFixed(0)
        : '',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final l10n = AppLocalizations.of(context)!;
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      Navigator.of(context, rootNavigator: true).pop(const _AmountChoice.auto());
      return;
    }
    final value = double.tryParse(raw.replaceAll(',', ''));
    if (value == null || !value.isFinite || value <= 0) {
      setState(() => _error = l10n.billsInvalidAmount);
      return;
    }
    Navigator.of(
      context,
      rootNavigator: true,
    ).pop(_AmountChoice.amount(value));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final sym = CurrencyController.to.currencySymbol.value;

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.billsAutoAmount(
              "$sym${widget.autoAmount.toStringAsFixed(0)}",
            ),
            style: AppType.bodySmall(
              scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.billsMonthlyAmount,
              errorText: _error,
              prefixText: sym,
            ),
            onSubmitted: (_) => _save(),
          ),
          SizedBox(height: 8.h),
          Text(
            l10n.billsLeaveBlank,
            style: AppType.labelSmall(
              scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(
            context,
            rootNavigator: true,
          ).pop(const _AmountChoice.auto()),
          child: Text(l10n.billsUseAuto),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}
