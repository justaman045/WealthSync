import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:money_control/Models/cateogary.dart';
import 'package:money_control/Models/recurring_payment_model.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Config/app_strings.dart';
import 'package:money_control/Services/connectivity_controller.dart';
import 'package:money_control/Services/recurring_service.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:money_control/Utils/animation.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Screens/subscription_details.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:money_control/Utils/responsive.dart';
import 'package:money_control/Components/adaptive_panel.dart';
import 'package:money_control/Services/error_handler.dart';

class RecurringPaymentsScreen extends StatefulWidget {
  const RecurringPaymentsScreen({super.key});

  @override
  State<RecurringPaymentsScreen> createState() =>
      _RecurringPaymentsScreenState();
}

class _RecurringPaymentsScreenState extends State<RecurringPaymentsScreen> {
  /// Hoisted out of build(): a stream built inline re-registers its
  /// listener on every rebuild.
  Stream<List<RecurringPayment>>? _paymentsStream;

  final RecurringService _service = RecurringService();
  late final TransactionController _txController;
  RecurringPayment? _selectedPayment;
  Timer? _loadTimer;
  bool _loadTimedOut = false;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<TransactionController>()) {
      Get.put(TransactionController());
    }
    _txController = Get.find<TransactionController>();
    // Never let the list spinner run indefinitely: if the Firestore stream is
    // still waiting after a few seconds (no network, no cached data) fall back
    // to an offline note. The StreamBuilder repopulates on its own once the
    // stream emits.
    _loadTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _loadTimedOut = true);
    });
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Premium Gradient Background
    final gradientColors = isDark
        ? [
            AppColors.darkBackground, // Midnight Void
            AppColors.darkSurface.withValues(alpha: 0.95),
          ]
        : [
            AppColors.lightBackground, // Premium Light
            AppColors.lightBorder,
          ];

    final textColor = isDark ? Colors.white : AppColors.darkBackground;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            AppStrings.subscriptions,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20.sp,
              color: textColor,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: textColor,
              size: 20.sp,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        floatingActionButton: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primary], // Cyan Gradient
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 15.w,
                offset: Offset(0.w, 5.w),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: () => _showAddDialog(context, isDark),
            backgroundColor: Colors.transparent,
            elevation: 0,
            label: const Text(
              "Add Subscription",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            icon: const Icon(Icons.add_rounded, color: Colors.black),
          ),
        ),
        body: AdaptivePanel(
          master: RefreshIndicator(
            onRefresh: () => _txController.refreshData(),
            color: AppColors.primary,
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: Responsive.contentMaxWidth(context),
                ),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    // Monthly Summary Card
                    _MonthlyCommitmentCard(
                      isDark: isDark,
                      textColor: textColor,
                    ),

                    StreamBuilder<List<RecurringPayment>>(
                      stream: _paymentsStream ??= _service.getPayments(),
                      builder: (context, snapshot) {
                        final offline =
                            Get.isRegistered<ConnectivityController>() &&
                            !ConnectivityController.to.isOnline.value;
                        final waiting =
                            snapshot.connectionState == ConnectionState.waiting;
                        if (waiting && !_loadTimedOut && !offline) {
                          return SizedBox(
                            height: 400.h,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return SizedBox(
                            height: 400.h,
                            child: Center(
                              child: Text("Error: ${snapshot.error}"),
                            ),
                          );
                        }
                        if (!snapshot.hasData &&
                            waiting &&
                            (_loadTimedOut || offline)) {
                          return SizedBox(
                            height: 400.h,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.cloud_off_rounded,
                                    size: 48,
                                    color: textColor.withValues(alpha: 0.3),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    "Couldn't load subscriptions. Check your connection.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: textColor.withValues(alpha: 0.6),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return SizedBox(
                            height: 500.h,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                        padding: EdgeInsets.all(30.w),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.05,
                                                )
                                              : AppColors.lightSurfaceCard,
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF00E5FF,
                                              ).withValues(alpha: 0.1),
                                              blurRadius: 30.w,
                                              spreadRadius: 5.w,
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.subscriptions_outlined,
                                          size: 60.sp,
                                          color: textColor.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                      )
                                      .animate(
                                        onPlay: (c) => c.repeat(reverse: true),
                                      )
                                      .scale(
                                        begin: const Offset(1, 1),
                                        end: const Offset(1.05, 1.05),
                                        duration: const Duration(seconds: 2),
                                      ),
                                  SizedBox(height: 24.h),
                                  Text(
                                        "No subscriptions yet",
                                        style: TextStyle(
                                          color: textColor.withValues(
                                            alpha: 0.6,
                                          ),
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      )
                                      .animate()
                                      .fadeIn(delay: 200.ms)
                                      .slideY(begin: 0.2, end: 0),
                                  SizedBox(height: 8.h),
                                  Text(
                                    "Track Netflix, Rent, Spotify, etc.",
                                    style: TextStyle(
                                      color: textColor.withValues(alpha: 0.4),
                                      fontSize: 12.sp,
                                    ),
                                  ).animate().fadeIn(delay: 400.ms),
                                ],
                              ),
                            ),
                          );
                        }

                        final list = snapshot.data!;
                        return ListView.separated(
                          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 100.h),
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: list.length,
                          separatorBuilder: (c, i) => SizedBox(height: 16.h),
                          itemBuilder: (context, index) {
                            final item = list[index];
                            return animatedItem(
                              GestureDetector(
                                onTap: () {
                                  final isSplit =
                                      Responsive.isTablet(context) &&
                                      Responsive.isLandscape(context);
                                  if (isSplit) {
                                    setState(() => _selectedPayment = item);
                                  } else {
                                    Get.to(
                                      () => SubscriptionDetailsScreen(
                                        payment: item,
                                      ),
                                    );
                                  }
                                },
                                child: _buildCard(
                                  item,
                                  isDark,
                                  textColor,
                                  context,
                                ),
                              ),
                              index,
                              staggerMs: 100,
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          detail: _selectedPayment != null
              ? SubscriptionDetailsScreen(payment: _selectedPayment!)
              : _buildDetailPlaceholder(),
          showDetail: _selectedPayment != null,
        ),
      ),
    );
  }

  Widget _buildCard(
    RecurringPayment item,
    bool isDark,
    Color textColor,
    BuildContext context,
  ) {
    final now = DateTime.now();
    // Check if paid: If due date is NOT in current month AND is in future
    final isDueThisMonth =
        item.nextDueDate.year == now.year &&
        item.nextDueDate.month == now.month;
    final isPaid = !isDueThisMonth && item.nextDueDate.isAfter(now);
    final isPaused = !item.isActive;
    final isPending =
        item.isActive && !item.autoPay && !item.nextDueDate.isAfter(now);
    final isAutoMissed =
        item.isActive && item.autoPay && !item.nextDueDate.isAfter(now);

    return Opacity(
      opacity: isPaused ? 0.6 : (isPaid ? 0.8 : 1.0),
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
            color: isPaid
                ? AppColors.success.withValues(
                    alpha: 0.3,
                  ) // Green glow for paid
                : (isPending
                      ? Colors.orange.withValues(alpha: 0.3)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.5))),
            width: (isPaid || isPending) ? 1.5 : 1,
          ),
          gradient: isDark
              ? LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.05),
                    Colors.white.withValues(alpha: 0.01),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: isPaid
                  ? AppColors.success.withValues(alpha: 0.1)
                  : (isPending
                        ? Colors.orange.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: isDark ? 0.2 : 0.05)),
              blurRadius: 15.w,
              offset: Offset(0.w, 8.w),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPaused
                      ? [Colors.grey.shade700, Colors.grey.shade800]
                      : (isPending
                            ? [Colors.orange, Colors.deepOrange]
                            : (isPaid
                                  ? [
                                      AppColors.success,
                                      AppColors.success,
                                    ]
                                  : [
                                      AppColors.primary,
                                      AppColors.primaryPress,
                                    ])),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18.r),
                boxShadow: [
                  BoxShadow(
                    color:
                        (isPaused
                                ? Colors.grey
                                : (isPending
                                      ? Colors.orange
                                      : (isPaid
                                            ? AppColors.success
                                            : AppColors.primary)))
                            .withValues(alpha: 0.3),
                    blurRadius: 10.w,
                    offset: Offset(0.w, 4.w),
                  ),
                ],
              ),
              child: Icon(
                isPaused
                    ? Icons.pause_rounded
                    : (isPending
                          ? Icons.pending_actions_rounded
                          : (isPaid
                                ? Icons.check_circle_outline_rounded
                                : Icons.receipt_long_rounded)),
                color: Colors.white,
                size: 22.sp,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            letterSpacing: 0.3,
                            decoration: isPaused
                                ? TextDecoration.lineThrough
                                : null,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (item.autoPay) ...[
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF00B8D4,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6.r),
                            border: Border.all(
                              color: const Color(
                                0xFF00B8D4,
                              ).withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            "AUTO",
                            style: TextStyle(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: isPaused
                          ? Colors.orange.withValues(alpha: 0.1)
                          : (isPending
                                ? Colors.orange.withValues(alpha: 0.12)
                                : (isPaid
                                      ? const Color(
                                          0xFF00E676,
                                        ).withValues(alpha: 0.1)
                                      : textColor.withValues(alpha: 0.06))),
                      borderRadius: BorderRadius.circular(6.r),
                      border: isPaused
                          ? Border.all(
                              color: Colors.orange.withValues(alpha: 0.3),
                              width: 1,
                            )
                          : (isPending
                                ? Border.all(
                                    color: Colors.orange.withValues(alpha: 0.4),
                                    width: 1,
                                  )
                                : (isPaid
                                      ? Border.all(
                                          color: const Color(
                                            0xFF00E676,
                                          ).withValues(alpha: 0.3),
                                        )
                                      : null)),
                    ),
                    child: Text(
                      isPaused
                          ? "PAUSED"
                          : (isPending
                                ? "PENDING • Due ${DateFormat('MMM dd').format(item.nextDueDate)}"
                                : (isPaid
                                      ? "PAID • Due ${DateFormat('MMM dd').format(item.nextDueDate)}"
                                      : "${item.frequency.name.capitalizeFirst} • Due ${DateFormat('MMM dd').format(item.nextDueDate)}")),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: isPaused
                            ? Colors.orange
                            : (isPending
                                  ? Colors.orange
                                  : (isPaid
                                        ? AppColors.success
                                        : textColor.withValues(alpha: 0.6))),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isAutoMissed) ...[
                    SizedBox(height: 6.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6.r),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        "AUTO-PAY MISSED",
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.redAccent,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${CurrencyController.to.currencySymbol.value}${item.amount.toStringAsFixed(0)}",
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 8.h),
                // Edit only
                GestureDetector(
                  onTap: () => _showAddDialog(context, isDark, payment: item),
                  child: Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.edit_rounded,
                      color: textColor.withValues(alpha: 0.7),
                      size: 16.sp,
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

  Widget _buildDetailPlaceholder() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.darkBackground;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.subscriptions_outlined,
            size: 64.sp,
            color: textColor.withValues(alpha: 0.2),
          ),
          SizedBox(height: 16.h),
          Text(
            "Select a subscription to view details",
            style: TextStyle(
              color: textColor.withValues(alpha: 0.4),
              fontSize: 16.sp,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(
    BuildContext context,
    bool isDark, {
    RecurringPayment? payment,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      constraints: BoxConstraints(maxWidth: Responsive.sheetMaxWidth(context)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => _AddSubscriptionSheet(
        payment: payment,
        categories: _txController.categories,
        isDark: isDark,
        onSave: (p) => payment == null
            ? _service.addPayment(p)
            : _service.updatePayment(p),
      ),
    );
  }
}

class _AddSubscriptionSheet extends StatefulWidget {
  final RecurringPayment? payment;
  final List<CategoryModel> categories;
  final bool isDark;
  final Future<void> Function(RecurringPayment payment) onSave;

  const _AddSubscriptionSheet({
    required this.payment,
    required this.categories,
    required this.isDark,
    required this.onSave,
  });

  @override
  State<_AddSubscriptionSheet> createState() => _AddSubscriptionSheetState();
}

class _AddSubscriptionSheetState extends State<_AddSubscriptionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _amountCtrl;
  late RecurringFrequency _freq;
  late DateTime _nextPaymentDate;
  late bool _autoPay;
  late String _category;
  late final List<String> _sortedCategories;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.payment?.title);
    _amountCtrl = TextEditingController(
      text: widget.payment?.amount.toString(),
    );
    _freq = widget.payment?.frequency ?? RecurringFrequency.monthly;
    _nextPaymentDate =
        widget.payment?.nextDueDate ??
        DateTime.now().add(const Duration(days: 30));
    _autoPay = widget.payment?.autoPay ?? false;

    _category = widget.payment?.category ?? 'Utilities';
    final categoryNames = widget.categories.map((e) => e.name).toSet();
    if (_category.isNotEmpty) categoryNames.add(_category);
    if (categoryNames.isEmpty) categoryNames.add('General');
    _sortedCategories = categoryNames.toList()..sort();
    if (_category.isEmpty) _category = _sortedCategories.first;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickNextPaymentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextPaymentDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() => _nextPaymentDate = picked);
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final amount = RecurringPayment.roundAmount(
        double.tryParse(_amountCtrl.text) ?? 0,
      );
      if (amount <= 0) {
        ErrorHandler.showError(
          "Enter a valid amount greater than 0",
          title: "Invalid Amount",
        );
        return;
      }
      setState(() => _saving = true);
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final newPayment = RecurringPayment(
        id: widget.payment?.id ?? const Uuid().v4(),
        userId: userId,
        title: _titleCtrl.text.trim(),
        amount: amount,
        category: _category,
        frequency: _freq,
        startDate: widget.payment?.startDate ?? DateTime.now(),
        nextDueDate: _nextPaymentDate,
        isActive: widget.payment?.isActive ?? true,
        autoPay: _autoPay,
      );
      try {
        await widget.onSave(newPayment);
        if (!mounted) return;
        Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          setState(() => _saving = false);
          ErrorHandler.showError("Failed to save. Please try again.");
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final textColor = isDark ? Colors.white : AppColors.darkBackground;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24.w,
        24.h,
        24.w,
        MediaQuery.of(context).viewInsets.bottom + 24.h,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.payment == null
                    ? "New Subscription"
                    : "Edit Subscription",
                style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20.h),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: "Name (e.g. Netflix)",
                ),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Amount"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              SizedBox(height: 16.h),

              // Frequency
              DropdownButtonFormField<RecurringFrequency>(
                initialValue: _freq,
                items: RecurringFrequency.values
                    .map(
                      (f) => DropdownMenuItem(
                        value: f,
                        child: Text(f.name.capitalizeFirst ?? f.name),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _freq = v!),
                decoration: const InputDecoration(labelText: "Frequency"),
              ),

              SizedBox(height: 16.h),

              // Category Dropdown
              DropdownButtonFormField<String>(
                initialValue: _category,
                items: _sortedCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
                decoration: const InputDecoration(labelText: "Category"),
              ),

              SizedBox(height: 16.h),

              // Next Payment Date Picker
              GestureDetector(
                onTap: _pickNextPaymentDate,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 16.h,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Next Payment: ${DateFormat('MMM dd, yyyy').format(_nextPaymentDate)}",
                        style: TextStyle(fontSize: 16.sp),
                      ),
                      Icon(Icons.calendar_today, size: 20.sp),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 24.h),

              // Auto-pay toggle
              Material(
                color: _autoPay
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : textColor.withValues(alpha: 0.04),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  side: BorderSide(
                    color: _autoPay
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : textColor.withValues(alpha: 0.1),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 4.h,
                  ),
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _autoPay,
                    onChanged: (v) => setState(() => _autoPay = v ?? false),
                    title: Text(
                      "Auto-pay",
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    subtitle: Text(
                      _autoPay
                          ? "When due, a transaction is created automatically."
                          : "Remind me when due — I'll mark it paid manually.",
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                    secondary: Icon(
                      _autoPay
                          ? Icons.auto_awesome_rounded
                          : Icons.notifications_active_outlined,
                      color: _autoPay ? AppColors.primary : Colors.orange,
                      size: 22.sp,
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.primary,
                    checkColor: Colors.black,
                  ),
                ),
              ),

              SizedBox(height: 24.h),

              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: const Text(AppStrings.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Monthly Commitment summary card. Kept alive across scroll so the
// TweenAnimationBuilder count-up (and flutter_animate entrance) runs once on
// first load instead of restarting from 0 every time the card re-enters the
// viewport — the ListView otherwise destroys and recreates its State.
class _MonthlyCommitmentCard extends StatefulWidget {
  const _MonthlyCommitmentCard({required this.isDark, required this.textColor});

  final bool isDark;
  final Color textColor;

  @override
  State<_MonthlyCommitmentCard> createState() => _MonthlyCommitmentCardState();
}

class _MonthlyCommitmentCardState extends State<_MonthlyCommitmentCard>
    with AutomaticKeepAliveClientMixin {
  /// Hoisted out of build(): a stream built inline re-registers its
  /// listener on every rebuild.
  Stream<double>? _monthlyStream;
  final RecurringService _service = RecurringService();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<double>(
      stream: _monthlyStream ??= _service.getMonthlyTotal(),
      builder: (context, snapshot) {
        final total = snapshot.data ?? 0;
        return Container(
          width: double.infinity,
          margin: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 10.h),
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: widget.isDark
                ? AppColors.darkSurface.withValues(alpha: 0.6)
                : Colors.white,
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(
              color: widget.isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppColors.lightBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 20.w,
                offset: Offset(0.w, 10.w),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                "Monthly Commitment",
                style: TextStyle(
                  fontSize: 14.sp,
                  color: widget.textColor.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 12.h),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: total),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeOutExpo,
                builder: (context, value, child) {
                  return Text(
                    "${CurrencyController.to.currencySymbol.value}${value.toStringAsFixed(0)}",
                    style: TextStyle(
                      fontSize: 36.sp,
                      fontWeight: FontWeight.bold,
                      color: widget.textColor,
                      letterSpacing: -1.0,
                    ),
                  );
                },
              ),
            ],
          ),
        ).animate().fadeIn().slideY(begin: -0.2, end: 0);
      },
    );
  }
}
