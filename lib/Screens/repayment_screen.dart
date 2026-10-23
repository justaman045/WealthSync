import 'package:money_control/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/lent_money_controller.dart';
import 'package:money_control/Models/lent_money_model.dart';
import 'package:money_control/Services/error_handler.dart';
import 'package:money_control/Utils/responsive.dart';

class RepaymentScreen extends StatefulWidget {
  final LentMoneyModel entry;
  const RepaymentScreen({super.key, required this.entry});

  @override
  State<RepaymentScreen> createState() => _RepaymentScreenState();
}

class _RepaymentScreenState extends State<RepaymentScreen> {
  late final LentMoneyController _controller;
  late final CurrencyController _currencyController;
  final TextEditingController _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedDirection = 'received';

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<LentMoneyController>()) Get.put(LentMoneyController());
    _controller = Get.find<LentMoneyController>();
    if (!Get.isRegistered<CurrencyController>()) Get.put(CurrencyController());
    _currencyController = Get.find<CurrencyController>();
    _selectedDirection = widget.entry.type == 'borrowed' ? 'paid' : 'received';
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      if (!mounted) return;
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    final amt =
        double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
    if (amt <= 0) {
      ErrorHandler.showError("Enter a valid amount");
      return;
    }
    if (amt > widget.entry.remainingAmount + 0.001) {
      ErrorHandler.showError("Amount exceeds outstanding balance");
      return;
    }

    final success = await _controller.addRepayment(
      entryId: widget.entry.id,
      amount: amt,
      date: _selectedDate,
    );
    if (success) {
      ErrorHandler.showSuccess("Payment recorded");
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
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
            widget.entry.type == 'lent' ? "Receive Money" : "Repay Money",
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.contentMaxWidth(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSummaryCard(context),
                  SizedBox(height: 16.h),
                  _buildDirectionSelector(context),
                  SizedBox(height: 24.h),
                  _buildAmountField(context),
                  SizedBox(height: 24.h),
                  _buildDateField(context),
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

  Widget _buildSummaryCard(BuildContext context) {
    final theme = Theme.of(context);
    final currency = _currencyController.currencyCode.value;
    final isReceivable = widget.entry.type == 'lent';
    final color = isReceivable ? AppColors.success : AppColors.warning;

    return Obx(() {
      final live = _controller.entries.firstWhereOrNull(
        (e) => e.id == widget.entry.id,
      );
      final entry = live ?? widget.entry;
      return GlassContainer(
        padding: EdgeInsets.all(20.w),
        borderRadius: BorderRadius.circular(20.r),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isReceivable ? Icons.arrow_downward : Icons.arrow_upward,
                size: 22.sp,
                color: color,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.friendName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    "${isReceivable ? 'Lent to' : 'Borrowed from'} ${DateFormat('MMM dd, yyyy').format(entry.dateLent)}",
                    style: AppType.bodySmall(theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppLocalizations.of(context)!.outstanding,
                  style: AppType.bodySmall(theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                SizedBox(height: 4.h),
                Text(
                  NumberFormat.simpleCurrency(name: currency).format(
                    entry.remainingAmount,
                  ),
                  style: AppType.titleMedium(color),
                ),
                Text(
                  "of ${NumberFormat.simpleCurrency(name: currency).format(entry.amount)}",
                  style: AppType.bodySmall(theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildDirectionSelector(BuildContext context) {
    return GlassContainer(
      padding: EdgeInsets.all(8.w),
      borderRadius: BorderRadius.circular(20.r),
      child: SegmentedButton<String>(
        segments: [
          ButtonSegment(
            value: 'received',
            icon: Icon(Icons.arrow_downward),
            label: Text(AppLocalizations.of(context)!.received),
          ),
          ButtonSegment(
            value: 'paid',
            icon: Icon(Icons.arrow_upward),
            label: Text(AppLocalizations.of(context)!.paid),
          ),
        ],
        selected: {_selectedDirection},
        onSelectionChanged: (Set<String> newSelection) {
          setState(() {
            _selectedDirection = newSelection.first;
          });
        },
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.selected)) {
                return _selectedDirection == 'received'
                    ? AppColors.success.withValues(alpha: 0.2)
                    : AppColors.warning.withValues(alpha: 0.2);
              }
              return Colors.transparent;
            },
          ),
          foregroundColor: WidgetStateProperty.resolveWith<Color>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.selected)) {
                return _selectedDirection == 'received'
                    ? AppColors.success
                    : AppColors.warning;
              }
              return Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7);
            },
          ),
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
                  autofocus: true,
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

  Widget _buildDateField(BuildContext context) {
    return GlassContainer(
      padding: EdgeInsets.all(20.w),
      borderRadius: BorderRadius.circular(24.r),
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined, color: AppColors.primary, size: 24.sp),
          SizedBox(width: 16.w),
          Expanded(
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
                  AppLocalizations.of(context)!.recordPayment,
                  style: AppType.titleMedium(Colors.white),
                ),
        ),
      ),
    );
  }
}
