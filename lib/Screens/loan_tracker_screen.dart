import 'package:money_control/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/loan_controller.dart';
import 'package:money_control/Models/loan_model.dart';
import 'package:money_control/Utils/responsive.dart';
import 'package:money_control/Components/empty_state.dart';

class LoanTrackerScreen extends StatefulWidget {
  const LoanTrackerScreen({super.key});

  @override
  State<LoanTrackerScreen> createState() => _LoanTrackerScreenState();
}

class _LoanTrackerScreenState extends State<LoanTrackerScreen> {
  late final LoanController ctrl;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<LoanController>()) Get.put(LoanController());
    ctrl = Get.find<LoanController>();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
          title: Text(AppLocalizations.of(context)!.loanTracker),
        ),
        // The theme already paints the FAB primary with an on-primary label.
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddLoanSheet(context),
          icon: const Icon(Icons.add),
          label: Text(AppLocalizations.of(context)!.addLoan),
        ),
        body: Obx(() {
          if (ctrl.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          if (ctrl.loans.isEmpty) {
            return _buildEmptyState();
          }
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
              child: ListView(
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 100.h),
                children: [
                  _buildSummaryCard(ctrl, isDark),
                  SizedBox(height: 20.h),
                  Text(
                    AppLocalizations.of(context)!.activeLoans,
                    style: AppType.titleMedium(
                      isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  SizedBox(height: AppSpace.s12.h),
                  ...ctrl.loans.map((loan) => _buildLoanCard(context, loan, ctrl, isDark)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSummaryCard(LoanController ctrl, bool isDark) {
    final symbol = CurrencyController.to.currencySymbol.value;
    final l10n = AppLocalizations.of(context)!;
    // `onPrimary` is what the theme pairs with the primary fill; the labels
    // used to hard-code white at 70% and 24%, which is the same value but not
    // tied to the fill it sits on.
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final onPrimaryMuted = onPrimary.withValues(alpha: 0.8);

    return Container(
      padding: EdgeInsets.all(AppSpace.s20.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryPress],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
        boxShadow: AppElevation.floating(
          isDark: isDark,
          tint: AppColors.primary,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.totalOutstanding,
                  style: AppType.bodySmall(onPrimaryMuted),
                ),
                SizedBox(height: AppSpace.s4.h),
                Text(
                  "$symbol${ctrl.totalOutstanding.toStringAsFixed(0)}",
                  style: AppType.titleLarge(onPrimary),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 40.h,
            color: onPrimary.withValues(alpha: 0.24),
          ),
          SizedBox(width: AppSpace.s16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.monthlyEMI, style: AppType.bodySmall(onPrimaryMuted)),
                SizedBox(height: AppSpace.s4.h),
                Text(
                  l10n.loanMonthlyAmount(
                    "$symbol${ctrl.totalMonthlyEmi.toStringAsFixed(0)}",
                  ),
                  style: AppType.titleLarge(onPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanCard(
    BuildContext context,
    LoanModel loan,
    LoanController ctrl,
    bool isDark,
  ) {
    final symbol = CurrencyController.to.currencySymbol.value;
    final l10n = AppLocalizations.of(context)!;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: () => _showAmortizationSheet(context, loan, isDark),
        child: Container(
          margin: EdgeInsets.only(bottom: AppSpace.s12.h),
          padding: EdgeInsets.all(AppSpace.s16.w),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceCard
                : AppColors.lightSurfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppSpace.s8.w),
                    decoration: BoxDecoration(
                      color: _loanColor(loan.loanType).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.sm.r),
                    ),
                    child: Icon(
                      _loanIcon(loan.loanType),
                      color: _loanColor(loan.loanType),
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: AppSpace.s12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loan.name, style: AppType.labelLarge(textPrimary)),
                        Text(
                          l10n.loanRatePerAnnum(
                            loan.loanType.name.capitalize ??
                                loan.loanType.name,
                            loan.interestRate.toStringAsFixed(1),
                          ),
                          style: AppType.bodySmall(textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        l10n.loanMonthlyAmount(
                          "$symbol${loan.emiAmount.toStringAsFixed(0)}",
                        ),
                        style: AppType.titleSmall(AppColors.primary),
                      ),
                      Text(
                        l10n.loanMonthsPaidOf(
                          loan.monthsPaid,
                          loan.tenureMonths,
                        ),
                        style: AppType.labelSmall(textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: AppSpace.s12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.loanOutstanding(
                      "$symbol${loan.outstandingBalance.toStringAsFixed(0)}",
                    ),
                    style: AppType.bodySmall(textSecondary),
                  ),
                  Text(
                    l10n.loanPercentPaid(
                      (loan.progressPercent * 100).toStringAsFixed(0),
                    ),
                    style: AppType.bodySmall(
                      _progressColor(loan.progressPercent),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpace.s8.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xs.r),
                child: LinearProgressIndicator(
                  value: loan.progressPercent,
                  minHeight: 6.h,
                  backgroundColor: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightActionSurface,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _progressColor(loan.progressPercent),
                  ),
                ),
              ),
              SizedBox(height: AppSpace.s8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.loanStartedOn(
                      DateFormat('MMM yyyy').format(loan.startDate),
                    ),
                    style: AppType.labelSmall(textSecondary),
                  ),
                  // A bare Text inside a GestureDetector: no ripple, no button
                  // semantics, and a tap target the height of 11 pt type.
                  TextButton(
                    onPressed: () async {
                      final confirm = await _confirmDelete(context);
                      if (confirm == true) ctrl.deleteLoan(loan.id);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpace.s8.w,
                      ),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: AppType.labelSmall(AppColors.error),
                    ),
                    child: Text(l10n.remove),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return EmptyStateWidget(
      icon: Icons.account_balance_outlined,
      title: l10n.loansTrackedYet,
      subtitle: l10n.addLoanTrackEMIsSee,
      actionLabel: l10n.addLoan,
      onAction: () => _showAddLoanSheet(context),
    );
  }

  // ────────── Add Loan Bottom Sheet ──────────

  void _showAddLoanSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(maxWidth: Responsive.sheetMaxWidth(context)),
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddLoanSheet(),
    );
  }

  // ────────── Amortization Detail Sheet ──────────

  void _showAmortizationSheet(BuildContext context, LoanModel loan, bool isDark) {
    final symbol = CurrencyController.to.currencySymbol.value;
    final l10n = AppLocalizations.of(context)!;
    final schedule = loan.buildSchedule();
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(maxWidth: Responsive.sheetMaxWidth(context)),
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl.r),
            ),
          ),
          child: Column(
            children: [
              SizedBox(height: AppSpace.s8.h),
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(AppRadius.pill.r),
                ),
              ),
              SizedBox(height: AppSpace.s16.h),
              Text(
                l10n.loanScheduleTitle(loan.name),
                style: AppType.titleMedium(textPrimary),
              ),
              SizedBox(height: AppSpace.s4.h),
              Text(
                l10n.loanTotalInterest(
                  "$symbol${loan.totalInterestPayable.toStringAsFixed(0)}",
                ),
                style: AppType.bodySmall(textSecondary),
              ),
              SizedBox(height: AppSpace.s12.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpace.s16.w),
                child: Row(
                  children: [
                    _scheduleHeader(
                      l10n.loanMonthCol,
                      flex: 1,
                      textSecondary: textSecondary,
                    ),
                    _scheduleHeader(
                      l10n.loanPrincipalCol,
                      flex: 2,
                      textSecondary: textSecondary,
                    ),
                    _scheduleHeader(
                      l10n.loanInterestCol,
                      flex: 2,
                      textSecondary: textSecondary,
                    ),
                    _scheduleHeader(
                      l10n.loanBalanceCol,
                      flex: 2,
                      textSecondary: textSecondary,
                    ),
                  ],
                ),
              ),
              Divider(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                height: 1,
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  itemCount: schedule.length,
                  itemBuilder: (_, i) {
                    final e = schedule[i];
                    final isPast = e.month <= loan.monthsPaid;
                    return Container(
                      // Paid rows are tinted with the same success wash in both
                      // modes, so the schedule reads the same either way.
                      color: isPast
                          ? AppColors.success.withValues(alpha: 0.04)
                          : Colors.transparent,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.h),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: Text(
                                "${e.month}",
                                style: AppType.bodySmall(isPast
                                      ? AppColors.success
                                      : textSecondary),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                "$symbol${e.principalPaid.toStringAsFixed(0)}",
                                style: AppType.bodySmall(textPrimary),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                "$symbol${e.interestPaid.toStringAsFixed(0)}",
                                style: AppType.bodySmall(AppColors.error.withValues(alpha: 0.8)),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                "$symbol${e.outstanding.toStringAsFixed(0)}",
                                style: AppType.bodySmall(textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scheduleHeader(String label,
      {required int flex, required Color textSecondary}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: AppType.labelSmall(textSecondary),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.removeLoan),
        content: Text(
          AppLocalizations.of(context)!.removeLoanItsLinkedRecurring,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(AppLocalizations.of(context)!.remove),
          ),
        ],
      ),
    );
  }

  IconData _loanIcon(LoanType type) {
    switch (type) {
      case LoanType.home:
        return Icons.home_outlined;
      case LoanType.car:
        return Icons.directions_car_outlined;
      case LoanType.personal:
        return Icons.person_outline;
      case LoanType.education:
        return Icons.school_outlined;
      case LoanType.other:
        return Icons.account_balance_outlined;
    }
  }

  Color _loanColor(LoanType type) {
    switch (type) {
      case LoanType.home:
        return AppColors.accent;
      case LoanType.car:
        return AppColors.warning;
      case LoanType.personal:
        return AppColors.primary;
      case LoanType.education:
        return AppColors.success;
      case LoanType.other:
        // Neutral on purpose: "Other" is the absence of a category, so it gets
        // the tertiary text token rather than a sixth accent colour.
        return AppColors.lightTextTertiary;
    }
  }

  Color _progressColor(double progress) {
    if (progress >= 0.75) return AppColors.success;
    if (progress >= 0.4) return AppColors.warning;
    return AppColors.error;
  }
}

// ──────────────────────────────────────────────────
//  Add Loan Bottom Sheet (StatefulWidget)
// ──────────────────────────────────────────────────

class _AddLoanSheet extends StatefulWidget {
  const _AddLoanSheet();

  @override
  State<_AddLoanSheet> createState() => _AddLoanSheetState();
}

class _AddLoanSheetState extends State<_AddLoanSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _principalCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _tenureCtrl = TextEditingController();

  LoanType _selectedType = LoanType.personal;
  DateTime _startDate = DateTime.now();
  bool _createRecurring = true;
  double? _calculatedEmi;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _principalCtrl.dispose();
    _rateCtrl.dispose();
    _tenureCtrl.dispose();
    super.dispose();
  }

  void _recalcEmi() {
    final p = double.tryParse(_principalCtrl.text) ?? 0;
    final r = double.tryParse(_rateCtrl.text) ?? 0;
    final n = int.tryParse(_tenureCtrl.text) ?? 0;
    if (p > 0 && n > 0) {
      setState(() {
        _calculatedEmi = LoanModel.calcEmi(p, r, n);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await LoanController.to.addLoan(
      name: _nameCtrl.text,
      loanType: _selectedType,
      principalAmount: double.tryParse(_principalCtrl.text) ?? 0,
      interestRate: double.tryParse(_rateCtrl.text) ?? 0,
      tenureMonths: int.tryParse(_tenureCtrl.text) ?? 0,
      startDate: _startDate,
      createRecurring: _createRecurring,
    );
    if (success && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final symbol = CurrencyController.to.currencySymbol.value;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: EdgeInsets.all(AppSpace.s24.w),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl.r),
          ),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                      borderRadius: BorderRadius.circular(AppRadius.pill.r),
                    ),
                  ),
                ),
                SizedBox(height: AppSpace.s20.h),
                Text(
                  AppLocalizations.of(context)!.addLoan,
                  style: AppType.titleMedium(
                    isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                SizedBox(height: AppSpace.s20.h),

                // Loan Name
                _buildField(
                  controller: _nameCtrl,
                  label: "Loan Name",
                  hint: "e.g. HDFC Home Loan",
                  isDark: isDark,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? "Required" : null,
                ),

                // Loan Type
                SizedBox(height: 4.h),
                DropdownButtonFormField<LoanType>(
                  // ignore: deprecated_member_use
                  value: _selectedType,
                  decoration: InputDecoration(
                    labelText: "Loan Type",
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: LoanType.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.name.capitalize!),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedType = v!),
                ),
                SizedBox(height: 16.h),

                // Principal & Rate row
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        controller: _principalCtrl,
                        label: "Principal ($symbol)",
                        hint: "500000",
                        isDark: isDark,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _recalcEmi(),
                        validator: (v) =>
                            double.tryParse(v ?? '') == null ? "Invalid" : null,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _buildField(
                        controller: _rateCtrl,
                        label: "Rate (% p.a.)",
                        hint: "8.5",
                        isDark: isDark,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => _recalcEmi(),
                        validator: (v) =>
                            double.tryParse(v ?? '') == null ? "Invalid" : null,
                      ),
                    ),
                  ],
                ),

                // Tenure
                _buildField(
                  controller: _tenureCtrl,
                  label: "Tenure (months)",
                  hint: "240",
                  isDark: isDark,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _recalcEmi(),
                  validator: (v) =>
                      int.tryParse(v ?? '') == null ? "Invalid" : null,
                ),

                // EMI Preview
                if (_calculatedEmi != null)
                  Container(
                    padding: EdgeInsets.all(12.w),
                    margin: EdgeInsets.only(bottom: 16.h),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calculate_outlined,
                            color: AppColors.primary, size: 18.sp),
                        SizedBox(width: 8.w),
                        Text(
                          "Monthly EMI: $symbol${_calculatedEmi!.toStringAsFixed(0)}",
                          style: AppType.titleSmall(AppColors.primary),
                        ),
                      ],
                    ),
                  ),

                // Start Date
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _startDate = picked);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 16.w, vertical: 14.h),
                    margin: EdgeInsets.only(bottom: 16.h),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceCard
                          : AppColors.lightSurfaceCard,
                      borderRadius: BorderRadius.circular(AppRadius.sm.r),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 18.sp,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        SizedBox(width: AppSpace.s8.w),
                        Text(
                          l10n.loanStartedOn(
                            DateFormat('d MMM yyyy').format(_startDate),
                          ),
                          style: AppType.bodyMedium(
                            isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Create recurring payment toggle
                Row(
                  children: [
                    Switch(
                      value: _createRecurring,
                      onChanged: (v) => setState(() => _createRecurring = v),
                      activeThumbColor: AppColors.primary,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.createRecurringPaymentEMI,
                        style: AppType.bodySmall(
                          isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),

                // Submit
                // Indigo fill with a near-black label in light mode was 3.1:1;
                // FilledButton takes fill and label from the theme.
                Obx(
                  () => SizedBox(
                    width: double.infinity,
                    height: 52.h,
                    child: FilledButton(
                      onPressed: LoanController.to.isSaving.value
                          ? null
                          : _submit,
                      child: LoanController.to.isSaving.value
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(AppLocalizations.of(context)!.addLoan),
                    ),
                  ),
                ),
                SizedBox(height: AppSpace.s8.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: keyboardType == TextInputType.number ||
                keyboardType ==
                    const TextInputType.numberWithOptions(decimal: true)
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
            : null,
        onChanged: onChanged,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
