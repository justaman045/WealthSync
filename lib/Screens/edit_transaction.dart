// lib/Screens/edit_transaction.dart

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

class TransactionEditScreen extends StatefulWidget {
  final TransactionModel transaction;

  const TransactionEditScreen({super.key, required this.transaction});

  @override
  State<TransactionEditScreen> createState() => _TransactionEditScreenState();
}

class _TransactionEditScreenState extends State<TransactionEditScreen> {
  final _formKey = GlobalKey<FormState>();

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

      setState(() {
        _categories = fetched;
        // If selected is null but transaction has one, pick it.
        // But wait, transaction stores String name.
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

    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF1E1E2C),
        elevation: 0,
        insetPadding: EdgeInsets.all(20.w),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24.r),
            gradient: const LinearGradient(
              colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 2,
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
                  color: Colors.white,
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
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: "Category Name",
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
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
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 16.sp,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  GestureDetector(
                    onTap: () async {
                      final text = controller.text.trim();
                      if (text.isEmpty) return;
                      // Logic to save
                      try {
                        final email = FirebaseAuth.instance.currentUser?.email;
                        if (email == null) return;
                        await FirebaseFirestore.instance
                            .collection("users")
                            .doc(email)
                            .collection("categories")
                            .add({"name": text});
                        await _loadCategories();
                        setState(() => _selectedCategory = text);
                        if (mounted) Navigator.pop(context);
                      } catch (e) {
                        // handle error
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
                            color: const Color(
                              0xFF6C63FF,
                            ).withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Text(
                        "Add",
                        style: TextStyle(
                          color: Colors.white,
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
    rawAmount = rawAmount.abs(); // Ensure positive input

    // Determine if expense
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
      // Try online save with timeout
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.email)
          .collection("transactions")
          .doc(updated.id)
          .set(txMap)
          .timeout(const Duration(seconds: 3));

      // JSON backup (non-blocking)
      if (user.email != null) {
        LocalBackupService.backupUserTransactions(user.email!);
      }

      _saving = false;

      // Check Budget Limit
      if (updated.category != null && user.email != null) {
        BudgetService.checkBudgetExceeded(
          userId: user.email!,
          category: updated.category!,
          newAmount: updated.amount,
        );
      }

      ErrorHandler.showSuccess("Transaction Updated");
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      // ----------------- OFFLINE PATH: queue update -----------------
      // final Map<String, dynamic> updateJson = {
      //   "operation": "update",
      //   "transactionId": updated.id,
      //   "user": user.email,
      //   "newData": txMap,
      // };

      await OfflineQueueService.savePending(
        txMap,
      ); // Using savePending from backup service logic mostly or direct offline queue

      _saving = false;

      if (mounted) {
        Get.snackbar(
          "Offline",
          "Saved locally",
          snackPosition: SnackPosition.BOTTOM,
          colorText: Colors.white,
          icon: const Icon(Icons.wifi_off, color: Colors.white),
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Edit Transaction'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18.sp,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1A1A2E), // Midnight Void Top
              const Color(
                0xFF16213E,
              ).withValues(alpha: 0.95), // Deep Blue Bottom
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
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

                  _fieldLabel("Amount"),
                  _amountField(_amountController),

                  _fieldLabel("Tax"),
                  _inputField(
                    controller: _taxController,
                    hint: "0.00",
                    isNumber: true,
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
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: _saving
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18.sp,
                                    color: Colors.white,
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
    );
  }

  // ------------------------------------------------------------------
  // WIDGETS
  // ------------------------------------------------------------------

  Widget _fieldLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(top: 20.h, bottom: 10.h),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white70,
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _glassBox({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05), // Dark Glass
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _amountField(TextEditingController c) {
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
                color: const Color(0xFF6C63FF), // Blurple
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
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: "0.00",
                hintStyle: TextStyle(color: Colors.white24, fontSize: 22.sp),
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
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white24,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _categorySelector() {
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
                : Colors.white.withValues(alpha: 0.1);

            return Padding(
              padding: EdgeInsets.only(right: 12.w),
              child: GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat.name),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? catColor.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(30.r),
                    border: Border.all(color: borderColor),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: catColor.withValues(alpha: 0.3),
                              blurRadius: 12,
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
                          color: isSelected ? catColor : Colors.white70,
                        ),
                        SizedBox(width: 8.w),
                      ],
                      Text(
                        cat.name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
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
          // Add Button
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
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2015),
          lastDate: DateTime(2100),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Color(0xFF6C63FF),
                  onPrimary: Colors.white,
                  surface: Color(0xFF1E1E2C),
                  onSurface: Colors.white,
                ),
                dialogTheme: DialogThemeData(
                  backgroundColor: const Color(0xFF1E1E2C),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) setState(() => _selectedDate = picked);
      },
      child: _glassBox(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
        child: Row(
          children: [
            Text(
              "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.white,
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
