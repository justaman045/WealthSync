import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Controllers/lent_money_controller.dart';
import 'package:money_control/Models/lent_money_model.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Services/error_handler.dart';

class AddLentMoneyScreen extends StatefulWidget {
  final LentMoneyModel? existingEntry;
  const AddLentMoneyScreen({super.key, this.existingEntry});

  @override
  State<AddLentMoneyScreen> createState() => _AddLentMoneyScreenState();
}

class _AddLentMoneyScreenState extends State<AddLentMoneyScreen> {
  final LentMoneyController _controller = Get.put(LentMoneyController());
  final CurrencyController _currencyController = Get.find();

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedType = 'lent'; // 'lent' or 'borrowed'

  @override
  void initState() {
    super.initState();
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAmountField(context),
              SizedBox(height: 16.h),
              _buildTypeSelector(context),
              SizedBox(height: 24.h),
              _buildDetailsForm(context),
              SizedBox(height: 32.h),
              _buildSaveButton(),
            ],
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
        segments: const [
          ButtonSegment(
            value: 'lent',
            icon: Icon(Icons.arrow_downward),
            label: Text('Lent to Friend'),
          ),
          ButtonSegment(
            value: 'borrowed',
            icon: Icon(Icons.arrow_upward),
            label: Text('Borrowed from Friend'),
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
                  ? Colors.greenAccent.withValues(alpha: 0.2)
                  : Colors.orangeAccent.withValues(alpha: 0.2);
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.selected)) {
              return _selectedType == 'lent' ? Colors.green : Colors.orange;
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
            "Amount",
            style: TextStyle(
              fontSize: 14.sp,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
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
          _buildInputRow(
            icon: Icons.person_outline,
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: "Friend's Name",
              ),
            ),
          ),
          Divider(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            height: 32.h,
          ),
          _buildInputRow(
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
        Icon(icon, color: const Color(0xFF6C63FF), size: 24.sp),
        SizedBox(width: 16.w),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 56.h,
      child: Obx(
        () => ElevatedButton(
          onPressed: _controller.isSaving.value ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
          ),
          child: _controller.isSaving.value
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(
                  widget.existingEntry != null ? "Update Entry" : "Save Entry",
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
