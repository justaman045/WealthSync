// lib/Screens/add_transaction.dart

import 'package:confetti/confetti.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:pattern_formatter/pattern_formatter.dart';
import 'package:money_control/l10n/app_localizations.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/feature_gate.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Config/app_strings.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Models/cateogary.dart';
import 'package:money_control/Screens/add_transaction_from_recipt.dart';
import 'package:money_control/Screens/upi_payment_screen.dart';
import 'package:money_control/Utils/icon_helper.dart';
import 'package:money_control/Controllers/tutorial_controller.dart';
import 'package:money_control/Services/error_handler.dart';
import 'package:money_control/Services/performance_controller.dart';
import 'package:money_control/Utils/responsive.dart';
import 'package:money_control/Components/responsive_form_row.dart';
import 'package:money_control/Utils/num_parse.dart';

enum PaymentType { send, receive }

class PaymentScreen extends StatefulWidget {
  final PaymentType type;
  final String? cateogary;

  const PaymentScreen({super.key, required this.type, this.cateogary});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final TransactionController _transactionController;
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final TextEditingController _newCategory = TextEditingController();

  final GlobalKey _keyCategory = GlobalKey();
  final GlobalKey _keyReceipt = GlobalKey();
  late final ConfettiController _confettiController;
  final TextEditingController _categorySearch = TextEditingController();

  String? selectedCategory;
  String _categoryQuery = '';
  DateTime selectedDate = DateTime.now();
  Worker? _categoryAutoSelectWorker;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<TransactionController>()) {
      Get.put(TransactionController());
    }
    _transactionController = Get.find<TransactionController>();
    _confettiController = ConfettiController(
      duration: const Duration(milliseconds: 800),
    );
    // Initialize selected category if passed from widget
    if (widget.cateogary != null) {
      selectedCategory = widget.cateogary;
    }

    // Auto-select first category once when categories load — not inside Obx
    if (selectedCategory == null) {
      if (_transactionController.categories.isNotEmpty) {
        selectedCategory = _transactionController.categories.first.name;
      } else {
        _categoryAutoSelectWorker = ever(_transactionController.categories, (
          cats,
        ) {
          if (cats.isNotEmpty && selectedCategory == null && mounted) {
            setState(() => selectedCategory = cats.first.name);
            _categoryAutoSelectWorker?.dispose();
            _categoryAutoSelectWorker = null;
          }
        });
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      TutorialController.showAddTransactionTutorial(
        context,
        keyCategory: _keyCategory,
        keyReceipt: widget.type == PaymentType.send ? _keyReceipt : null,
      );
    });
  }

  @override
  void dispose() {
    _categoryAutoSelectWorker?.dispose();
    _confettiController.dispose();
    _categorySearch.dispose();
    _amount.dispose();
    _name.dispose();
    _note.dispose();
    _newCategory.dispose();
    super.dispose();
  }

  Future<void> _addCategoryDialog() async {
    _newCategory.clear();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.all(20.w),
        child: GlassContainer(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.newCategory,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
              SizedBox(height: 20.h),
              GlassContainer(
                margin: EdgeInsets.zero,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                borderRadius: BorderRadius.circular(16.r),
                child: TextField(
                  controller: _newCategory,
                  autofocus: true,
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: AppLocalizations.of(context)!.categoryNameHint,
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withValues(
                        alpha: 0.5,
                      ),
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
                      AppLocalizations.of(context)!.cancel,
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.7,
                        ),
                        fontSize: 16.sp,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  GestureDetector(
                    onTap: () async {
                      final success = await _transactionController.addCategory(
                        _newCategory.text.trim(),
                      );
                      if (success) {
                        if (!mounted) return;
                        setState(() {
                          selectedCategory = _newCategory.text.trim();
                        });
                        if (mounted) Navigator.pop(context);
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.w,
                        vertical: 12.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12.r),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 10.w,
                          ),
                        ],
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.add,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : AppColors.lightTextPrimary,
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

  Future<void> _deleteCategory(CategoryModel category) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Text(
          AppLocalizations.of(context)!.deleteCategoryTitle,
          style: theme.textTheme.titleLarge,
        ),
        content: Text(
          AppLocalizations.of(context)!.deleteCategoryContent(category.name),
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(
              AppLocalizations.of(context)!.delete,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await _transactionController.deleteCategory(category);
    if (success && selectedCategory == category.name) {
      if (!mounted) return;
      setState(() {
        selectedCategory = null;
        if (_transactionController.categories.isNotEmpty) {
          selectedCategory = _transactionController.categories.first.name;
        }
      });
    }
  }

  Future<void> saveTransaction() async {
    if (selectedCategory == null) {
      ErrorHandler.showError(
        AppLocalizations.of(context)!.selectCategoryError,
        title: AppLocalizations.of(context)!.error,
      );
      return;
    }

    // Remove commas from the formatted text before parsing
    String cleanAmount = _amount.text.replaceAll(',', '').trim();
    final amountVal = double.tryParse(cleanAmount) ?? 0;

    if (!isValidAmount(amountVal)) {
      ErrorHandler.showError("Please enter a valid amount");
      return;
    }

    if (_name.text.trim().isEmpty) {
      ErrorHandler.showError("Please enter a valid name");
      return;
    }

    final success = await _transactionController.saveTransaction(
      amount: amountVal,
      name: _name.text.trim(),
      note: _note.text.trim(),
      category: selectedCategory!,
      date: selectedDate,
      type: widget.type == PaymentType.send ? 'send' : 'receive',
      currency: CurrencyController.to.currencyCode.value,
    );

    if (success) {
      _confettiController.play();
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == PaymentType.send
        ? AppLocalizations.of(context)!.sendMoney
        : AppLocalizations.of(context)!.receiveMoney;
    final nameLabel = widget.type == PaymentType.send
        ? AppLocalizations.of(context)!.recipient
        : AppLocalizations.of(context)!.sender;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Stack(
      children: [
        Scaffold(
          extendBodyBehindAppBar: true,
          appBar: _buildAppBar(title, theme, isDark),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? AppColors.darkGradient
                    : AppColors.lightGradient,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: Responsive.contentMaxWidth(context),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 20.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ResponsiveFormRow(
                          left: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _fieldLabel(
                                AppLocalizations.of(context)!.amount,
                                theme,
                              ),
                              _amountField(_amount, theme),
                            ],
                          ),
                          right: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _fieldLabel(nameLabel, theme),
                              _inputField(
                                controller: _name,
                                hint: AppLocalizations.of(
                                  context,
                                )!.enterNameHint,
                                theme: theme,
                              ),
                            ],
                          ),
                        ),
                        _fieldLabel(
                          AppLocalizations.of(context)!.selectCategory,
                          theme,
                        ),
                        _categorySelector(theme),
                        ResponsiveFormRow(
                          left: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _fieldLabel(
                                AppLocalizations.of(context)!.note,
                                theme,
                              ),
                              _inputField(
                                controller: _note,
                                hint: AppLocalizations.of(context)!.addNoteHint,
                                maxLines: 2,
                                theme: theme,
                              ),
                            ],
                          ),
                          right: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _fieldLabel(
                                AppLocalizations.of(context)!.date,
                                theme,
                              ),
                              _dateSelector(theme),
                            ],
                          ),
                        ),
                        SizedBox(height: 40.h),
                        _submitButton(
                          context: context,
                          label: widget.type == PaymentType.send
                              ? AppStrings.sendCta
                              : AppStrings.receiveCta,
                          onTap: saveTransaction,
                        ),
                        if (widget.type == PaymentType.send && !kIsWeb) ...[
                          SizedBox(height: 12.h),
                          FeatureVisible(
                            flagKey: 'upi_pay',
                            child: _upiPayButton(context),
                          ),
                        ],
                        SizedBox(height: 20.h),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: PerformanceController.to.liteMode.value
              ? const SizedBox.shrink()
              : ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  numberOfParticles: 30,
                  maxBlastForce: 20,
                  minBlastForce: 8,
                  gravity: 0.3,
                  colors: const [
                    AppColors.primary,
                    AppColors.success,
                    AppColors.error,
                    Color(0xFFFFD740),
                  ],
                ),
        ),
      ],
    );
  }

  AppBar _buildAppBar(String title, ThemeData theme, bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
      ),
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new,
          color: theme.colorScheme.onSurface,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        if (widget.type == PaymentType.send)
          IconButton(
            key: _keyReceipt,
            icon: Icon(
              Icons.qr_code_scanner,
              color: theme.colorScheme.onSurface,
            ),
            onPressed: () {
              Get.to(() => const ReceiptScanPage());
            },
          ),
      ],
    );
  }

  Widget _fieldLabel(String text, ThemeData theme) {
    return Padding(
      padding: EdgeInsets.only(top: 20.h, bottom: 10.h),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _amountField(TextEditingController c, ThemeData theme) {
    return GlassContainer(
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Obx(
              () => Text(
                CurrencyController.to.currencyCode.value,
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15.sp,
                ),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: TextField(
              controller: c,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [ThousandsFormatter(allowFraction: true)],
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: "0.00",
                hintStyle: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.4,
                  ),
                  fontSize: 22.sp,
                ),
              ),
              style: TextStyle(
                fontSize: 22.sp,
                color: theme.textTheme.bodyLarge?.color,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required ThemeData theme,
    int maxLines = 1,
  }) {
    return GlassContainer(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
            fontSize: 18.sp,
            fontWeight: FontWeight.w500,
          ),
          contentPadding: EdgeInsets.zero,
        ),
        style: TextStyle(
          fontSize: 18.sp,
          color: theme.textTheme.bodyLarge?.color,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _categorySelector(ThemeData theme) {
    return Obx(() {
      final categories = _transactionController.categories;

      final filteredCats = _categoryQuery.isEmpty
          ? categories
          : categories
                .where(
                  (c) => c.name.toLowerCase().contains(
                    _categoryQuery.toLowerCase(),
                  ),
                )
                .toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (categories.length > 8) ...[
            GlassContainer(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
              child: TextField(
                controller: _categorySearch,
                decoration: InputDecoration(
                  hintText: 'Search categories...',
                  hintStyle: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.4,
                    ),
                    fontSize: 14.sp,
                  ),
                  border: InputBorder.none,
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18.sp,
                    color: theme.iconTheme.color,
                  ),
                  isDense: true,
                ),
                style: TextStyle(
                  fontSize: 14.sp,
                  color: theme.textTheme.bodyLarge?.color,
                ),
                onChanged: (v) => setState(() => _categoryQuery = v),
              ),
            ),
            SizedBox(height: 10.h),
          ],
          SingleChildScrollView(
            key: _keyCategory,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...filteredCats.map((cat) {
                  final isSelected = selectedCategory == cat.name;
                  final catColor = cat.color != null
                      ? Color(cat.color!)
                      : AppColors.secondary;
                  final borderColor = isSelected
                      ? catColor
                      : theme.dividerColor.withValues(alpha: 0.3);

                  return Padding(
                    padding: EdgeInsets.only(right: 12.w),
                    child: GestureDetector(
                      onTap: () => setState(() => selectedCategory = cat.name),
                      onLongPress: () => _deleteCategory(cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 12.h,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? catColor.withValues(alpha: 0.25)
                              : theme.cardColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(24.r),
                          border: Border.all(color: borderColor, width: 1.5),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: catColor.withValues(alpha: 0.3),
                                    blurRadius: 12.w,
                                    spreadRadius: -2.w,
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
                                color: isSelected
                                    ? catColor
                                    : theme.textTheme.bodyMedium?.color,
                              ),
                              SizedBox(width: 8.w),
                            ],
                            Text(
                              cat.name,
                              style: TextStyle(
                                color: isSelected
                                    ? theme.textTheme.bodyLarge?.color
                                    : theme.textTheme.bodyMedium?.color,
                                fontWeight: FontWeight.w600,
                                fontSize: 15.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                // ADD BUTTON
                GestureDetector(
                  onTap: _addCategoryDialog,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 14.h,
                    ),
                    decoration: BoxDecoration(
                      color: theme.cardColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(24.r),
                      border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.add,
                          color: theme.textTheme.bodyMedium?.color,
                          size: 20.sp,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          AppLocalizations.of(context)!.add,
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color,
                            fontSize: 15.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _dateSelector(ThemeData theme) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime(2015),
          lastDate: DateTime(2100),
        );
        if (picked != null && mounted) setState(() => selectedDate = picked);
      },
      child: GlassContainer(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
        child: Row(
          children: [
            Text(
              "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
              style: TextStyle(
                fontSize: 18.sp,
                color: theme.textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(Icons.calendar_today_outlined, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _submitButton({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Obx(
      () => GestureDetector(
        onTap: _transactionController.isSaving.value
            ? null
            : () {
                HapticFeedback.mediumImpact();
                onTap();
              },
        child: Container(
          width: double.infinity,
          height: 54.h,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(27.r),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 15.w,
                offset: Offset(0, 8.w),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: _transactionController.isSaving.value
              ? SizedBox(
                  width: 24.w,
                  height: 24.h,
                  child: CircularProgressIndicator(
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                    letterSpacing: 1.5,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _upiPayButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () async {
        if (!ensureFeatureVisible(context, 'upi_pay')) return;
        final saved = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const UpiPaymentScreen()),
        );
        if (saved == true && mounted) {
          Navigator.of(this.context).pop();
        }
      },
      child: Container(
        width: double.infinity,
        height: 50.h,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.049),
          borderRadius: BorderRadius.circular(27.r),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, color: AppColors.primary, size: 18.sp),
            SizedBox(width: 8.w),
            Text(
              "Scan & Pay with UPI",
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
