import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/lent_money_controller.dart';
import 'package:money_control/Services/error_handler.dart';

class _Participant {
  TextEditingController nameCtrl;
  TextEditingController amountCtrl;
  _Participant() : nameCtrl = TextEditingController(), amountCtrl = TextEditingController();
  void dispose() {
    nameCtrl.dispose();
    amountCtrl.dispose();
  }
}

class SplitBillScreen extends StatefulWidget {
  const SplitBillScreen({super.key});

  @override
  State<SplitBillScreen> createState() => _SplitBillScreenState();
}

class _SplitBillScreenState extends State<SplitBillScreen> {
  final _totalCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final List<_Participant> _participants = [_Participant(), _Participant()];
  bool _evenSplit = true;
  bool _isSaving = false;

  // Called only on USER input to total field (onChanged fires for user only, not programmatic)
  void _onTotalChanged(String val) {
    if (_evenSplit) _distributeEvenly();
    setState(() {});
  }

  // Called only on USER input to participant amount field
  void _onParticipantAmountChanged(int idx, String val) {
    final mine = double.tryParse(val) ?? 0;

    if (_evenSplit) {
      if (mine > 0) {
        // Mirror the same amount to all other participants and sync total
        final newTotal = mine * _participants.length;
        _totalCtrl.text = newTotal.toStringAsFixed(2);
        for (int j = 0; j < _participants.length; j++) {
          if (j != idx) {
            _participants[j].amountCtrl.text = mine.toStringAsFixed(2);
          }
        }
      }
    } else {
      // Auto-populate total from sum of all participants
      final sum = _participants.fold<double>(0, (s, p) => s + (double.tryParse(p.amountCtrl.text) ?? 0));
      if (sum > 0) _totalCtrl.text = sum.toStringAsFixed(2);
    }
    setState(() {});
  }

  void _distributeEvenly() {
    final total = double.tryParse(_totalCtrl.text) ?? 0;
    if (total <= 0 || _participants.isEmpty) return;
    final share = total / _participants.length;
    for (int i = 0; i < _participants.length; i++) {
      // Give the last participant the remainder to avoid rounding drift
      if (i == _participants.length - 1) {
        final alreadyAllocated = _participants
            .take(i)
            .fold<double>(0, (s, p) => s + (double.tryParse(p.amountCtrl.text) ?? 0));
        _participants[i].amountCtrl.text = (total - alreadyAllocated).toStringAsFixed(2);
      } else {
        _participants[i].amountCtrl.text = share.toStringAsFixed(2);
      }
    }
  }

  void _onEvenSplitToggled(bool val) {
    setState(() => _evenSplit = val);
    if (val) {
      final total = double.tryParse(_totalCtrl.text) ?? 0;
      if (total > 0) {
        _distributeEvenly();
      } else {
        // Infer total from participants and then distribute evenly
        final sum = _participants.fold<double>(0, (s, p) => s + (double.tryParse(p.amountCtrl.text) ?? 0));
        if (sum > 0) {
          _totalCtrl.text = sum.toStringAsFixed(2);
          _distributeEvenly();
        }
      }
    }
  }

  void _addParticipant() {
    setState(() {
      _participants.add(_Participant());
      if (_evenSplit) _distributeEvenly();
    });
  }

  void _removeParticipant(int i) {
    if (_participants.length <= 2) return;
    _participants[i].dispose();
    setState(() {
      _participants.removeAt(i);
      if (_evenSplit) _distributeEvenly();
    });
  }

  double get _participantTotal =>
      _participants.fold<double>(0, (s, p) => s + (double.tryParse(p.amountCtrl.text) ?? 0));

  Future<void> _submit() async {
    double total = double.tryParse(_totalCtrl.text) ?? 0;
    if (total <= 0) total = _participantTotal;
    if (total <= 0) {
      ErrorHandler.showError("Enter a valid total amount.");
      return;
    }
    for (int i = 0; i < _participants.length; i++) {
      if (_participants[i].nameCtrl.text.trim().isEmpty) {
        ErrorHandler.showError("Name is required for participant ${i + 1}.");
        return;
      }
      final share = double.tryParse(_participants[i].amountCtrl.text) ?? 0;
      if (share <= 0) {
        ErrorHandler.showError("Invalid amount for ${_participants[i].nameCtrl.text.trim()}.");
        return;
      }
    }

    setState(() => _isSaving = true);
    final note = _noteCtrl.text.trim().isEmpty ? "Split bill" : _noteCtrl.text.trim();
    int successCount = 0;
    if (!Get.isRegistered<LentMoneyController>()) Get.put(LentMoneyController());
    final ctrl = Get.find<LentMoneyController>();

    for (final p in _participants) {
      final share = double.tryParse(p.amountCtrl.text) ?? 0;
      final ok = await ctrl.addEntry(
        friendName: p.nameCtrl.text.trim(),
        amount: share,
        note: note,
        dateLent: DateTime.now(),
        type: 'lent',
      );
      if (ok) successCount++;
    }

    if (mounted) setState(() => _isSaving = false);
    if (successCount > 0 && mounted) {
      ErrorHandler.showSuccess("Split bill created: $successCount entries added.");
      Get.back();
    } else {
      ErrorHandler.showError("Failed to create entries. Please try again.");
    }
  }

  @override
  void dispose() {
    _totalCtrl.dispose();
    _noteCtrl.dispose();
    for (final p in _participants) {
      p.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sym = CurrencyController.to.currencySymbol.value;
    final enteredTotal = double.tryParse(_totalCtrl.text) ?? 0;
    final splitTotal = _participantTotal;
    final hasDiscrepancy = enteredTotal > 0 && (enteredTotal - splitTotal).abs() > 0.01;

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
          title: const Text("Split a Bill"),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel("Total bill amount"),
              SizedBox(height: 8.h),
              _buildTextField(
                controller: _totalCtrl,
                hint: "0.00",
                prefix: "$sym ",
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                isDark: isDark,
                theme: theme,
                onChanged: _onTotalChanged,
              ),
              SizedBox(height: 20.h),
              _sectionLabel("Description (optional)"),
              SizedBox(height: 8.h),
              _buildTextField(
                controller: _noteCtrl,
                hint: "e.g. Dinner at restaurant",
                isDark: isDark,
                theme: theme,
              ),
              SizedBox(height: 20.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _sectionLabel("Participants"),
                  Row(
                    children: [
                      Text(
                        "Even split",
                        style: TextStyle(fontSize: 13.sp, color: theme.textTheme.bodyMedium?.color),
                      ),
                      SizedBox(width: 8.w),
                      Switch.adaptive(
                        value: _evenSplit,
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
                        onChanged: _onEvenSplitToggled,
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              ...List.generate(_participants.length, (i) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: Row(
                    children: [
                      Container(
                        width: 32.w,
                        height: 32.w,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            "${i + 1}",
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        flex: 5,
                        child: _buildTextField(
                          controller: _participants[i].nameCtrl,
                          hint: "Name",
                          isDark: isDark,
                          theme: theme,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        flex: 3,
                        child: _buildTextField(
                          controller: _participants[i].amountCtrl,
                          hint: "0.00",
                          prefix: "$sym ",
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          isDark: isDark,
                          theme: theme,
                          onChanged: (val) => _onParticipantAmountChanged(i, val),
                        ),
                      ),
                      SizedBox(width: 6.w),
                      GestureDetector(
                        onTap: _participants.length > 2 ? () => _removeParticipant(i) : null,
                        child: Icon(
                          Icons.remove_circle_outline,
                          color: _participants.length > 2
                              ? AppColors.error
                              : Colors.grey.withValues(alpha: 0.3),
                          size: 22.sp,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              TextButton.icon(
                onPressed: _addParticipant,
                icon: Icon(Icons.person_add_outlined, size: 18.sp, color: AppColors.secondary),
                label: Text(
                  "Add person",
                  style: TextStyle(color: AppColors.secondary, fontSize: 14.sp),
                ),
              ),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: hasDiscrepancy
                      ? AppColors.error.withValues(alpha: 0.08)
                      : AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: hasDiscrepancy
                        ? AppColors.error.withValues(alpha: 0.3)
                        : AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Split across ${_participants.length} people",
                          style: TextStyle(fontSize: 13.sp, color: theme.textTheme.bodyMedium?.color),
                        ),
                        if (hasDiscrepancy)
                          Text(
                            "Doesn't match total ($sym${enteredTotal.toStringAsFixed(2)})",
                            style: TextStyle(fontSize: 11.sp, color: AppColors.error),
                          ),
                      ],
                    ),
                    Text(
                      "$sym${splitTotal.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: hasDiscrepancy ? AppColors.error : theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          "Create Split Entries",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              SizedBox(height: 32.h),
            ],
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
    required bool isDark,
    required ThemeData theme,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 14.sp),
      decoration: InputDecoration(
        prefixText: prefix,
        prefixStyle: TextStyle(fontSize: 14.sp, color: theme.textTheme.bodyMedium?.color),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey, fontSize: 13.sp),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
