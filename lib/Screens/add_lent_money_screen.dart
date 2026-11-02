import 'package:money_control/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Config/app_strings.dart';
import 'package:money_control/Controllers/lent_money_controller.dart';
import 'package:money_control/Models/lent_money_model.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Services/error_handler.dart';
import 'package:money_control/Utils/responsive.dart';
import 'package:money_control/Components/responsive_form_row.dart';
import 'package:money_control/Screens/repayment_screen.dart';

class AddLentMoneyScreen extends StatefulWidget {
  final LentMoneyModel? existingEntry;
  const AddLentMoneyScreen({super.key, this.existingEntry});

  @override
  State<AddLentMoneyScreen> createState() => _AddLentMoneyScreenState();
}

class _AddLentMoneyScreenState extends State<AddLentMoneyScreen> {
  late final LentMoneyController _controller;
  late final CurrencyController _currencyController;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedType = 'lent';

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<LentMoneyController>()) Get.put(LentMoneyController());
    _controller = Get.find<LentMoneyController>();
    if (!Get.isRegistered<CurrencyController>()) Get.put(CurrencyController());
    _currencyController = Get.find<CurrencyController>();
    if (widget.existingEntry != null) {
      _amountController.text = widget.existingEntry!.amount.toString();
      _nameController.text = widget.existingEntry!.friendName;
      _noteController.text = widget.existingEntry!.note;
      _selectedDate = widget.existingEntry!.dateLent;
      _selectedType = widget.existingEntry!.type;
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      if (!mounted) return;
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _submit() async {
    double amt =
        double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;

    bool success;
    if (widget.existingEntry != null) {
      success = await _controller.editEntry(
        id: widget.existingEntry!.id,
        friendName: _nameController.text.trim(),
        amount: amt,
        note: _noteController.text.trim(),
        dateLent: _selectedDate,
        type: _selectedType,
        isSettled: widget.existingEntry!.isSettled,
        createdAt: widget.existingEntry!.createdAt,
        repayments: widget.existingEntry!.repayments,
        advances: widget.existingEntry!.advances,
      );
    } else {
      success = await _controller.addEntry(
        friendName: _nameController.text.trim(),
        amount: amt,
        note: _noteController.text.trim(),
        dateLent: _selectedDate,
        type: _selectedType,
      );
    }

    if (success) {
      ErrorHandler.showSuccess(widget.existingEntry != null ? "Entry Updated" : "Entry Added");
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        appBar: AppBar(
          title: Text(
            widget.existingEntry != null ? "Edit Entry" : "Lent Money",
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAmountField(context),
              SizedBox(height: 16.h),
              _buildTypeSelector(context),
              SizedBox(height: 24.h),
              _buildDetailsForm(context),
              if (widget.existingEntry != null) ...[
                SizedBox(height: 24.h),
                _buildTopUpSection(context),
                SizedBox(height: 24.h),
                _buildRepaymentHistory(context),
              ],
              SizedBox(height: 32.h),
              _buildSaveButton(),
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector(BuildContext context) {
    return GlassContainer(
      padding: EdgeInsets.all(8.w),
      borderRadius: BorderRadius.circular(20.r),
      child: SegmentedButton<String>(
        segments: [
          ButtonSegment(
            value: 'lent',
            icon: Icon(Icons.arrow_downward),
            label: Text(AppStrings.lentToFriend),
          ),
          ButtonSegment(
            value: 'borrowed',
            icon: Icon(Icons.arrow_upward),
            label: Text(AppLocalizations.of(context)!.borrowedFriend),
          ),
        ],
        selected: {_selectedType},
        onSelectionChanged: (Set<String> newSelection) {
          setState(() {
            _selectedType = newSelection.first;
          });
        },
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.selected)) {
              return _selectedType == 'lent'
                  ? AppColors.success.withValues(alpha: 0.2)
                  : AppColors.warning.withValues(alpha: 0.2);
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.selected)) {
              return _selectedType == 'lent' ? AppColors.success : AppColors.warning;
            }
            return Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7);
          }),
        ),
      ),
    );
  }

  Widget _buildAmountField(BuildContext context) {
    return GlassContainer(
      padding: EdgeInsets.all(24.w),
      borderRadius: BorderRadius.circular(24.r),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context)!.amount,
            style: AppType.bodyMedium(Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _currencyController.currencySymbol.value,
                style: TextStyle(fontSize: 32.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 8.w),
              IntrinsicWidth(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(
                    fontSize: 40.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: "0.00",
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsForm(BuildContext context) {
    final theme = Theme.of(context);
    return GlassContainer(
      padding: EdgeInsets.all(20.w),
      borderRadius: BorderRadius.circular(24.r),
      child: Column(
        children: [
          ResponsiveFormRow(
            left: _buildInputRow(
              icon: Icons.person_outline,
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "Friend's Name",
                ),
              ),
            ),
            right: _buildInputRow(
              icon: Icons.calendar_today_outlined,
              child: InkWell(
                onTap: () => _selectDate(context),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  child: Text(
                    DateFormat('MMM dd, yyyy').format(_selectedDate),
                    style: TextStyle(fontSize: 16.sp),
                  ),
                ),
              ),
            ),
          ),
          Divider(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            height: 32.h,
          ),
          _buildInputRow(
            icon: Icons.notes_rounded,
            child: TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: "Optional Note",
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow({required IconData icon, required Widget child}) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 24.sp),
        SizedBox(width: 16.w),
        Expanded(child: child),
      ],
    );
  }

  /// Top-ups: money handed over after the original loan. Kept separate from the
  /// original amount so the history stays truthful; [remainingAmount] accounts
  /// for the extra principal.
  Widget _buildTopUpSection(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final entryId = widget.existingEntry!.id;
    final currency = _currencyController.currencyCode.value;
    return GlassContainer(
      padding: EdgeInsets.all(20.w),
      borderRadius: BorderRadius.circular(24.r),
      child: Obx(() {
        final live = _controller.entries.firstWhereOrNull(
          (e) => e.id == entryId,
        );
        final advances = live?.advances ?? widget.existingEntry!.advances;
        final principal = live?.totalPrincipal ??
            widget.existingEntry!.totalPrincipal;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.lentTopUps,
                  style: AppType.titleSmall(theme.colorScheme.onSurface),
                ),
                Text(
                  l10n.lentTopUpsTotal(
                    NumberFormat.simpleCurrency(name: currency).format(principal),
                  ),
                  style: AppType.labelMedium(AppColors.primary),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              l10n.lentTopUpsHint,
              style: AppType.bodySmall(
                theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: 12.h),
            if (advances.isEmpty)
              Text(
                l10n.lentTopUpsEmpty,
                style: AppType.bodySmall(
                  theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              )
            else
              for (var i = 0; i < advances.length; i++) ...[
                _buildAdvanceRow(theme, entryId, advances[i], i),
                if (i < advances.length - 1)
                  Divider(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    height: 1,
                  ),
              ],
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _addTopUp(entryId),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                ),
                icon: Icon(Icons.add_circle_outline, size: 18.sp),
                label: Text(l10n.lentAddTopUp),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildAdvanceRow(
    ThemeData theme,
    String entryId,
    LentAdvance advance,
    int index,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final currency = _currencyController.currencyCode.value;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Icon(Icons.add_circle, size: 18.sp, color: AppColors.primary),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  NumberFormat.simpleCurrency(name: currency)
                      .format(advance.amount),
                  style: AppType.numericOf(
                    AppType.bodyLarge(theme.colorScheme.onSurface).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  DateFormat('MMM dd, yyyy').format(advance.date),
                  style: AppType.bodySmall(
                    theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                if (advance.note.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(
                    advance.note,
                    style: AppType.bodySmall(
                      theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.lentRemoveTopUp,
            icon: Icon(
              Icons.delete_outline,
              size: 20.sp,
              color: AppColors.error,
            ),
            onPressed: () => _controller.deleteAdvance(entryId, index),
          ),
        ],
      ),
    );
  }

  Future<void> _addTopUp(String entryId) async {
    final result = await showDialog<({double amount, DateTime date, String note})>(
      context: context,
      builder: (_) => const _AddTopUpDialog(),
    );
    if (result == null) return;
    await _controller.addAdvance(
      entryId: entryId,
      amount: result.amount,
      date: result.date,
      note: result.note,
    );
  }

  Widget _buildRepaymentHistory(BuildContext context) {
    final theme = Theme.of(context);
    final entryId = widget.existingEntry!.id;
    final currency = _currencyController.currencyCode.value;
    return GlassContainer(
      padding: EdgeInsets.all(20.w),
      borderRadius: BorderRadius.circular(24.r),
      child: Obx(() {
        final live = _controller.entries.firstWhereOrNull(
          (e) => e.id == entryId,
        );
        final repayments = live?.repayments ?? widget.existingEntry!.repayments;
        final repaid = repayments.fold(0.0, (s, r) => s + r.amount);
        final isReceivable = (live?.type ?? widget.existingEntry!.type) == 'lent';
        final actionColor =
            isReceivable ? AppColors.success : AppColors.warning;
        final actionLabel = isReceivable ? "Receive" : "Repay";
        final actionIcon =
            isReceivable ? Icons.call_received : Icons.currency_rupee;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.repaymentHistory,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "${NumberFormat.simpleCurrency(name: currency).format(repaid)} repaid",
                  style: AppType.labelMedium(AppColors.success),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            if (repayments.isEmpty)
              Text(
                AppLocalizations.of(context)!.repaymentsRecordedYet,
                style: AppType.bodySmall(theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              )
            else
              for (var i = 0; i < repayments.length; i++) ...[
                _buildRepaymentRow(theme, entryId, repayments[i], i),
                if (i < repayments.length - 1)
                  Divider(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    height: 1,
                  ),
              ],
            if (!(live?.isSettled ?? widget.existingEntry!.isSettled)) ...[
              SizedBox(height: 16.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Get.to(
                    () => RepaymentScreen(entry: widget.existingEntry!),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: actionColor.withValues(alpha: 0.15),
                    foregroundColor: actionColor,
                    side: BorderSide(color: actionColor.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                  icon: Icon(actionIcon, size: 18.sp),
                  label: Text(
                    actionLabel,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      }),
    );
  }

  Widget _buildRepaymentRow(
    ThemeData theme,
    String entryId,
    LentRepayment repayment,
    int index,
  ) {
    final currency = _currencyController.currencyCode.value;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Icon(Icons.currency_rupee, size: 18.sp, color: AppColors.success),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  NumberFormat.simpleCurrency(
                    name: currency,
                  ).format(repayment.amount),
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  DateFormat('MMM dd, yyyy').format(repayment.date),
                  style: AppType.bodySmall(theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                if (repayment.note.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(
                    repayment.note,
                    style: AppType.bodySmall(theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: AppColors.error,
              size: 20,
            ),
            onPressed: () => _controller.deleteRepayment(entryId, index),
            tooltip: "Delete repayment",
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 56.h,
      child: Obx(
        () => ElevatedButton(
          onPressed: _controller.isSaving.value ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
          ),
          child: _controller.isSaving.value
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(
                  widget.existingEntry != null ? "Update Entry" : "Save Entry",
                  style: AppType.titleMedium(Colors.white),
                ),
        ),
      ),
    );
  }
}

/// Amount + date + note for a top-up. Owns its controllers: the dialog rebuilds
/// while the user types, so a controller created by the caller could outlive or
/// be replaced mid-edit.
class _AddTopUpDialog extends StatefulWidget {
  const _AddTopUpDialog();

  @override
  State<_AddTopUpDialog> createState() => _AddTopUpDialogState();
}

class _AddTopUpDialogState extends State<_AddTopUpDialog> {
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  void _save() {
    final amount =
        double.tryParse(_amountCtrl.text.replaceAll(',', '').trim()) ?? 0;
    if (amount <= 0) {
      ErrorHandler.showError("Enter a valid top-up amount");
      return;
    }
    Navigator.of(context).pop((
      amount: amount,
      date: _date,
      note: _noteCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.lentAddTopUp),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _amountCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.amount),
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _noteCtrl,
            decoration: InputDecoration(labelText: l10n.note),
          ),
          SizedBox(height: 12.h),
          TextButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(DateFormat('MMM dd, yyyy').format(_date)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.add)),
      ],
    );
  }
}
