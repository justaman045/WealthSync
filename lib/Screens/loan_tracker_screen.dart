import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/loan_controller.dart';
import 'package:money_control/Models/loan_model.dart';

class LoanTrackerScreen extends StatelessWidget {
  const LoanTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = LoanController.to;
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
          title: const Text("Loan Tracker"),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddLoanSheet(context),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            "Add Loan",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: Obx(() {
          if (ctrl.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          if (ctrl.loans.isEmpty) {
            return _buildEmptyState(isDark);
          }
          return ListView(
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 100.h),
            children: [
              _buildSummaryCard(ctrl, isDark),
              SizedBox(height: 20.h),
              Text(
                "Active Loans",
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
              SizedBox(height: 12.h),
              ...ctrl.loans.map((loan) => _buildLoanCard(context, loan, ctrl, isDark)),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSummaryCard(LoanController ctrl, bool isDark) {
    final symbol = CurrencyController.to.currencySymbol.value;
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF3B39C4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Total Outstanding",
                  style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                ),
                SizedBox(height: 4.h),
                Text(
                  "$symbol${ctrl.totalOutstanding.toStringAsFixed(0)}",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 40.h, color: Colors.white24),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Monthly EMI",
                  style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                ),
                SizedBox(height: 4.h),
                Text(
                  "$symbol${ctrl.totalMonthlyEmi.toStringAsFixed(0)}/mo",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                  ),
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
    final surfaceColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white;
    final textPrimary = isDark ? Colors.white : AppColors.lightTextPrimary;
    final textSecondary = isDark ? Colors.white60 : AppColors.lightTextSecondary;

    return GestureDetector(
      onTap: () => _showAmortizationSheet(context, loan, isDark),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : AppColors.lightBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: _loanColor(loan.loanType).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(
                    _loanIcon(loan.loanType),
                    color: _loanColor(loan.loanType),
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loan.name,
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15.sp,
                        ),
                      ),
                      Text(
                        "${loan.loanType.name.capitalize} • ${loan.interestRate.toStringAsFixed(1)}% p.a.",
                        style: TextStyle(color: textSecondary, fontSize: 12.sp),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "$symbol${loan.emiAmount.toStringAsFixed(0)}/mo",
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                      ),
                    ),
                    Text(
                      "${loan.monthsPaid}/${loan.tenureMonths} mo paid",
                      style: TextStyle(color: textSecondary, fontSize: 11.sp),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Outstanding: $symbol${loan.outstandingBalance.toStringAsFixed(0)}",
                  style: TextStyle(color: textSecondary, fontSize: 12.sp),
                ),
                Text(
                  "${(loan.progressPercent * 100).toStringAsFixed(0)}% paid",
                  style: TextStyle(
                    color: _progressColor(loan.progressPercent),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: LinearProgressIndicator(
                value: loan.progressPercent,
                minHeight: 6.h,
                backgroundColor:
                    isDark ? Colors.white12 : const Color(0xFFE0E0E0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _progressColor(loan.progressPercent),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Started ${DateFormat('MMM yyyy').format(loan.startDate)}",
                  style: TextStyle(color: textSecondary, fontSize: 11.sp),
                ),
                GestureDetector(
                  onTap: () async {
                    final confirm = await _confirmDelete(context);
                    if (confirm == true) ctrl.deleteLoan(loan.id);
                  },
                  child: Text(
                    "Remove",
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_outlined,
            size: 64.sp,
            color: isDark ? Colors.white24 : Colors.black12,
          ),
          SizedBox(height: 16.h),
          Text(
            "No loans tracked yet",
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : AppColors.lightTextSecondary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            "Add a loan to track EMIs and\nsee your repayment schedule",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              color: isDark ? Colors.white38 : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ────────── Add Loan Bottom Sheet ──────────

  void _showAddLoanSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddLoanSheet(),
    );
  }

  // ────────── Amortization Detail Sheet ──────────

  void _showAmortizationSheet(BuildContext context, LoanModel loan, bool isDark) {
    final symbol = CurrencyController.to.currencySymbol.value;
    final schedule = loan.buildSchedule();
    final textPrimary = isDark ? Colors.white : AppColors.lightTextPrimary;
    final textSecondary = isDark ? Colors.white60 : AppColors.lightTextSecondary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            children: [
              SizedBox(height: 8.h),
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                "${loan.name} — Schedule",
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                "Total interest: $symbol${loan.totalInterestPayable.toStringAsFixed(0)}",
                style: TextStyle(color: textSecondary, fontSize: 12.sp),
              ),
              SizedBox(height: 12.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Row(
                  children: [
                    _scheduleHeader("Month", flex: 1, textSecondary: textSecondary),
                    _scheduleHeader("Principal", flex: 2, textSecondary: textSecondary),
                    _scheduleHeader("Interest", flex: 2, textSecondary: textSecondary),
                    _scheduleHeader("Balance", flex: 2, textSecondary: textSecondary),
                  ],
                ),
              ),
              Divider(
                color: isDark ? Colors.white12 : Colors.black12,
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
                      color: isPast
                          ? (isDark
                              ? Colors.white.withValues(alpha: 0.03)
                              : Colors.green.withValues(alpha: 0.03))
                          : Colors.transparent,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.h),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: Text(
                                "${e.month}",
                                style: TextStyle(
                                  color: isPast
                                      ? AppColors.success
                                      : textSecondary,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                "$symbol${e.principalPaid.toStringAsFixed(0)}",
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                "$symbol${e.interestPaid.toStringAsFixed(0)}",
                                style: TextStyle(
                                  color: AppColors.error.withValues(alpha: 0.8),
                                  fontSize: 12.sp,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                "$symbol${e.outstanding.toStringAsFixed(0)}",
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12.sp,
                                ),
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
        style: TextStyle(
          color: textSecondary,
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Remove Loan"),
        content: const Text(
          "This will remove the loan and its linked recurring payment (if any).",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text("Remove"),
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
        return const Color(0xFF00BCD4);
      case LoanType.car:
        return const Color(0xFFFF9800);
      case LoanType.personal:
        return AppColors.primary;
      case LoanType.education:
        return const Color(0xFF4CAF50);
      case LoanType.other:
        return Colors.grey;
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

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
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
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  "Add Loan",
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
                SizedBox(height: 20.h),

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
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                          ),
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
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 18.sp,
                            color: isDark
                                ? Colors.white54
                                : AppColors.lightTextSecondary),
                        SizedBox(width: 10.w),
                        Text(
                          "Loan started: ${DateFormat('d MMM yyyy').format(_startDate)}",
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : AppColors.lightTextPrimary,
                            fontSize: 14.sp,
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
                        "Create recurring payment for EMI",
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: isDark
                              ? Colors.white70
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),

                // Submit
                Obx(() => SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ElevatedButton(
                    onPressed: LoanController.to.isSaving.value ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                    child: LoanController.to.isSaving.value
                        ? const CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)
                        : Text(
                            "Add Loan",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                )),
                SizedBox(height: 8.h),
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
