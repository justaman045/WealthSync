import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Models/cateogary.dart';
import 'package:money_control/Services/offline_queue.dart';
import 'package:money_control/Services/local_backup_service.dart';
import 'package:money_control/Services/budget_service.dart';
import 'package:money_control/Utils/icon_helper.dart';
import 'package:money_control/Services/error_handler.dart';
import 'package:money_control/Services/category_service.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/responsive_form_row.dart';
import 'package:money_control/Utils/responsive.dart';

class TransactionEditScreen extends StatefulWidget {
  final TransactionModel transaction;

  const TransactionEditScreen({super.key, required this.transaction});

  @override
  State<TransactionEditScreen> createState() => _TransactionEditScreenState();
}

class _TransactionEditScreenState extends State<TransactionEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late ThemeData _cachedTheme;

  late TextEditingController _recipientNameController;
  late TextEditingController _amountController;
  late TextEditingController _taxController;
  late TextEditingController _noteController;

  List<CategoryModel> _categories = [];
  String? _selectedCategory;
  late DateTime _selectedDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _recipientNameController = TextEditingController(
      text: widget.transaction.recipientName,
    );
    _amountController = TextEditingController(
      text: widget.transaction.amount.abs().toString(),
    );
    _taxController = TextEditingController(
      text: widget.transaction.tax.toString(),
    );
    _noteController = TextEditingController(
      text: widget.transaction.note ?? '',
    );
    _selectedDate = widget.transaction.date;
    _loadCategories();
  }

  @override
  void dispose() {
    _recipientNameController.dispose();
    _amountController.dispose();
    _taxController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // LOAD CATEGORIES
  // ------------------------------------------------------------------
  Future<void> _loadCategories() async {
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    if (userEmail == null) return;

    try {
      final catSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userEmail)
          .collection('categories')
          .get();

      final fetched = catSnap.docs
          .map((doc) => CategoryModel.fromMap(doc.id, doc.data()))
          .toList();

      if (!mounted) return;
      setState(() {
        _categories = fetched;
        _selectedCategory ??= widget.transaction.category;
      });
    } catch (e) {
      debugPrint("Load category error: $e");
    }
  }

  // ------------------------------------------------------------------
  // ADD NEW CATEGORY
  // ------------------------------------------------------------------
  Future<void> _addNewCategoryDialog() async {
    final controller = TextEditingController();
    final isDark = _cachedTheme.brightness == Brightness.dark;

    try {
      await showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.8),
        builder: (_) => Dialog(
          backgroundColor: Get.isDarkMode ? AppColors.darkSurface : AppColors.lightSurface,
          elevation: 0,
          insetPadding: EdgeInsets.all(20.w),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.r),
            side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lightBorder.withValues(alpha: 0.1)),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24.r),
              gradient: LinearGradient(
                colors: Get.isDarkMode ? AppColors.darkGradient : AppColors.lightGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                  blurRadius: 20.w,
                  spreadRadius: 2.w,
                ),
              ],
            ),
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "New Category",
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 20.h),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lightBorder.withValues(alpha: 0.1),
                    ),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "Category Name",
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white.withValues(alpha: 0.3) : AppColors.lightTextTertiary,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          color: isDark ? Colors.white.withValues(alpha: 0.6) : AppColors.lightTextSecondary,
                          fontSize: 16.sp,
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    GestureDetector(
                      onTap: () async {
                        final text = controller.text.trim();
                        if (text.isEmpty) return;
                        try {
                          final email = FirebaseAuth.instance.currentUser?.email;
                          if (email == null) return;
                          await FirebaseFirestore.instance
                              .collection("users")
                              .doc(email)
                              .collection("categories")
                              .add({"name": text});
                          await _loadCategories();
                          if (!mounted) return;
                          setState(() => _selectedCategory = text);
                          if (mounted) Navigator.pop(context);
                        } catch (e) {
                          debugPrint("Create category error: $e");
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24.w,
                          vertical: 12.h,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFF00E5FF)],
                          ),
                          borderRadius: BorderRadius.circular(12.r),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                              blurRadius: 10.w,
                            ),
                          ],
                        ),
                        child: Text(
                          "Add",
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  // ------------------------------------------------------------------
  // SAVE TRANSACTION (ONLINE + OFFLINE)
  // ------------------------------------------------------------------
  Future<void> _saveTransaction() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Select category")));
      return;
    }

    _saving = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _saving = false;
      return;
    }

    double rawAmount = double.tryParse(_amountController.text.trim()) ?? 0;
    rawAmount = rawAmount.abs();

    final isExpense = user.uid == widget.transaction.senderId;
    final finalAmount = isExpense ? -rawAmount : rawAmount;

    final updated = TransactionModel(
      id: widget.transaction.id,
      senderId: widget.transaction.senderId,
      recipientId: widget.transaction.recipientId,
      recipientName: _recipientNameController.text.trim(),
      amount: finalAmount,
      currency: widget.transaction.currency,
      tax: double.tryParse(_taxController.text.trim()) ?? 0,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      category: _selectedCategory,
      date: _selectedDate,
      attachmentUrl: widget.transaction.attachmentUrl,
      status: widget.transaction.status,
      createdAt: widget.transaction.createdAt,
    );

    final txMap = updated.toMap();

    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.email)
          .collection("transactions")
          .doc(updated.id)
          .set(txMap)
          .timeout(const Duration(seconds: 3));

      final email = user.email;
      if (email != null) {
        LocalBackupService.backupUserTransactions(email);
      }

      _saving = false;

      if (updated.category != null && email != null) {
        BudgetService.checkBudgetExceeded(
          userId: email,
          category: updated.category!,
        );
      }

      ErrorHandler.showSuccess("Transaction Updated");
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      await OfflineQueueService.savePending(txMap);

      _saving = false;

      if (mounted) {
        final isDark = _cachedTheme.brightness == Brightness.dark;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Saved locally"),
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    }
  }

  // ------------------------------------------------------------------
  // UI
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    _cachedTheme = Theme.of(context);
    final isDark = _cachedTheme.brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Edit Transaction'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : AppColors.lightTextPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 18.sp,
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : AppColors.lightTextPrimary),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark ? AppColors.darkGradient : AppColors.lightGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24.w),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel("Recipient Name"),
                      _inputField(
                        controller: _recipientNameController,
                        hint: "Recipient Name",
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),

                      ResponsiveFormRow(
                        left: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel("Amount"),
                            _amountField(_amountController),
                          ],
                        ),
                        right: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel("Tax"),
                            _inputField(
                              controller: _taxController,
                              hint: "0.00",
                              isNumber: true,
                            ),
                          ],
                        ),
                      ),

                      _fieldLabel("Category"),
                      _categorySelector(),

                      _fieldLabel("Note"),
                      _inputField(
                        controller: _noteController,
                        hint: "Add a note...",
                        maxLines: 2,
                      ),

                      _fieldLabel("Date"),
                      _dateSelector(),

                  SizedBox(height: 40.h),
                  SizedBox(
                    width: double.infinity,
                    height: 54.h,
                    child: ElevatedButton(
                      onPressed: _saveTransaction,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28.r),
                        ),
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFF00E5FF)],
                          ),
                          borderRadius: BorderRadius.circular(28.r),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF6C63FF,
                              ).withValues(alpha: 0.4),
                              blurRadius: 10.w,
                              offset: Offset(0, 4.w),
                            ),
                          ],
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: _saving
                              ? CircularProgressIndicator(
                                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                )
                              : Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18.sp,
                                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);
  }

  // ------------------------------------------------------------------
  // WIDGETS
  // ------------------------------------------------------------------

  Widget _fieldLabel(String text) {
    final isDark = _cachedTheme.brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(top: 20.h, bottom: 10.h),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _glassBox({required Widget child, EdgeInsetsGeometry? padding}) {
    final isDark = _cachedTheme.brightness == Brightness.dark;
    return Container(
      padding: padding ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lightBorder.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10.w,
            offset: Offset(0, 4.w),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _amountField(TextEditingController c) {
    final isDark = _cachedTheme.brightness == Brightness.dark;
    return _glassBox(
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
              ),
            ),
            margin: EdgeInsets.all(8.w),
            child: Text(
              widget.transaction.currency,
              style: TextStyle(
                color: const Color(0xFF6C63FF),
                fontWeight: FontWeight.w800,
                fontSize: 15.sp,
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: c,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(
                fontSize: 22.sp,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: "0.00",
                hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.2), fontSize: 22.sp),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return "Required";
                if (double.tryParse(val) == null) return "Invalid";
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    bool isNumber = false,
    String? Function(String?)? validator,
  }) {
    final isDark = _cachedTheme.brightness == Brightness.dark;
    return _glassBox(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        validator: validator,
        style: TextStyle(
          fontSize: 16.sp,
          color: isDark ? Colors.white : AppColors.lightTextPrimary,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.2),
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _categorySelector() {
    final isDark = _cachedTheme.brightness == Brightness.dark;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ..._categories.map((cat) {
            final isSelected = _selectedCategory == cat.name;
            final catColor = cat.color != null
                ? Color(cat.color!)
                : const Color(0xFF00E5FF);
            final borderColor = isSelected
                ? catColor
                : isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lightBorder.withValues(alpha: 0.1);

            return Padding(
              padding: EdgeInsets.only(right: 12.w),
              child: GestureDetector(
                onTap: () {
                  if (_selectedCategory != cat.name) {
                    CategoryService.recordCorrection(
                      _recipientNameController.text.trim(),
                      cat.name,
                    );
                  }
                  setState(() => _selectedCategory = cat.name);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? catColor.withValues(alpha: 0.2)
                        : isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.035),
                    borderRadius: BorderRadius.circular(30.r),
                    border: Border.all(color: borderColor),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: catColor.withValues(alpha: 0.3),
                              blurRadius: 12.w,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      if (cat.iconCode != null) ...[
                        Icon(
                          IconHelper.getIconFromCode(cat.iconCode),
                          size: 18.sp,
                          color: isSelected ? catColor : (isDark ? Colors.white70 : AppColors.lightTextSecondary),
                        ),
                        SizedBox(width: 8.w),
                      ],
                      Text(
                        cat.name,
                        style: TextStyle(
                          color: isSelected ? (isDark ? Colors.white : AppColors.lightTextPrimary) : (isDark ? Colors.white70 : AppColors.lightTextSecondary),
                          fontWeight: FontWeight.w600,
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          GestureDetector(
            onTap: _addNewCategoryDialog,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30.r),
                border: Border.all(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.5),
                  style: BorderStyle.none,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.add_circle,
                    color: const Color(0xFF6C63FF),
                    size: 18.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    "Add Link",
                    style: TextStyle(
                      color: const Color(0xFF6C63FF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateSelector() {
    final isDark = _cachedTheme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2015),
          lastDate: DateTime(2100),
          builder: (context, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: isDark
                    ? const ColorScheme.dark(
                        primary: Color(0xFF6C63FF),
                        onPrimary: Colors.white,
                        surface: Color(0xFF1E1E2C),
                        onSurface: Colors.white,
                      )
                    : ColorScheme.light(
                        primary: const Color(0xFF6C63FF),
                        onPrimary: Colors.white,
                        surface: Colors.white,
                        onSurface: Colors.black,
                      ),
                dialogTheme: DialogThemeData(
                  backgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null && mounted) setState(() => _selectedDate = picked);
      },
      child: _glassBox(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
        child: Row(
          children: [
            Text(
              "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
              style: TextStyle(
                fontSize: 16.sp,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const Icon(Icons.calendar_today_outlined, color: Color(0xFF6C63FF)),
          ],
        ),
      ),
    );
  }
}
