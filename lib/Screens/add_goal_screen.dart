import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/goals_controller.dart';
import 'package:money_control/Utils/responsive.dart';
import 'package:money_control/Components/responsive_form_row.dart';

class AddGoalScreen extends StatefulWidget {
  const AddGoalScreen({super.key});

  @override
  State<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen> {
  late final GoalsController _ctrl;
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _emoji = '🎯';
  DateTime? _targetDate;

  static const _emojis = [
    '🎯', '🏠', '🚗', '✈️', '📱', '💍', '🎓', '💪', '🌴', '🎸', '🏋️', '💰', '🛍️', '🏖️', '📚',
  ];

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _targetDate = picked);
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Goal name is required")),
      );
      return;
    }
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid target amount")),
      );
      return;
    }
    final ok = await _ctrl.addGoal(
      name: name,
      targetAmount: amount,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      targetDate: _targetDate,
      emoji: _emoji,
    );
    if (ok && mounted) Get.back();
  }

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<GoalsController>()) {
      Get.put(GoalsController());
    }
    _ctrl = GoalsController.to;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sym = CurrencyController.to.currencySymbol.value;

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
          title: const Text("New Goal"),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel("Pick an emoji"),
              SizedBox(height: 10.h),
              SizedBox(
                height: 50.h,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _emojis.length,
                  separatorBuilder: (_, __) => SizedBox(width: 8.w),
                  itemBuilder: (_, i) {
                    final e = _emojis[i];
                    final selected = e == _emoji;
                    return GestureDetector(
                      onTap: () => setState(() => _emoji = e),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 46.w,
                        height: 46.w,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: selected ? AppColors.primary : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Center(child: Text(e, style: TextStyle(fontSize: 22.sp))),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 24.h),
              ResponsiveFormRow(
                left: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel("Goal name"),
                    SizedBox(height: 8.h),
                    _buildTextField(
                      controller: _nameCtrl,
                      hint: "e.g. Emergency Fund, New iPhone",
                    ),
                  ],
                ),
                right: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel("Target amount"),
                    SizedBox(height: 8.h),
                    _buildTextField(
                      controller: _amountCtrl,
                      hint: "0.00",
                      prefix: "$sym ",
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              ResponsiveFormRow(
                left: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel("Description (optional)"),
                    SizedBox(height: 8.h),
                    _buildTextField(
                      controller: _descCtrl,
                      hint: "Why are you saving for this?",
                      maxLines: 2,
                    ),
                  ],
                ),
                right: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel("Target date (optional)"),
                    SizedBox(height: 8.h),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_outlined,
                                size: 18.sp, color: AppColors.secondary),
                            SizedBox(width: 10.w),
                            Text(
                              _targetDate != null
                                  ? DateFormat('MMM d, yyyy').format(_targetDate!)
                                  : "No deadline",
                              style: TextStyle(
                                fontSize: 15.sp,
                                color: _targetDate != null
                                    ? theme.textTheme.bodyLarge?.color
                                    : theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                            const Spacer(),
                            if (_targetDate != null)
                              GestureDetector(
                                onTap: () => setState(() => _targetDate = null),
                                child: Icon(Icons.close, size: 16.sp, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 36.h),
              Obx(() => SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: _ctrl.isSaving.value ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                  ),
                  child: _ctrl.isSaving.value
                      ? SizedBox(
                          width: 22.w,
                          height: 22.h,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          "Create Goal",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              )),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 13.sp,
      fontWeight: FontWeight.w600,
      color: Colors.white54,
      letterSpacing: 0.8,
    ),
  );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    String? prefix,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(
        color: Theme.of(context).textTheme.bodyLarge?.color,
        fontSize: 15.sp,
      ),
      decoration: InputDecoration(
        prefixText: prefix,
        prefixStyle: TextStyle(fontSize: 15.sp, color: Theme.of(context).textTheme.bodyMedium?.color),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey, fontSize: 14.sp),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
