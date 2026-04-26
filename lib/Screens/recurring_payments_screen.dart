import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:money_control/Models/recurring_payment_model.dart';
import 'package:money_control/Services/recurring_service.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Screens/subscription_details.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RecurringPaymentsScreen extends StatefulWidget {
  const RecurringPaymentsScreen({super.key});

  @override
  State<RecurringPaymentsScreen> createState() =>
      _RecurringPaymentsScreenState();
}

class _RecurringPaymentsScreenState extends State<RecurringPaymentsScreen> {
  final RecurringService _service = RecurringService();
  final TransactionController _txController = Get.find<TransactionController>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Premium Gradient Background
    final gradientColors = isDark
        ? [
            const Color(0xFF1A1A2E), // Midnight Void
            const Color(0xFF16213E).withValues(alpha: 0.95),
          ]
        : [
            const Color(0xFFF5F7FA), // Premium Light
            const Color(0xFFC3CFE2),
          ];

    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

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
            "Subscriptions",
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
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        floatingActionButton: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              colors: [Color(0xFF00E5FF), Color(0xFF00B8D4)], // Cyan Gradient
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                blurRadius: 15,
                offset: const Offset(0, 5),
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
        body: RefreshIndicator(
          onRefresh: () async {
            // Simulate refresh delay
            await Future.delayed(const Duration(seconds: 1));
          },
          color: const Color(0xFF00E5FF),
          backgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              // Monthly Summary Card
              StreamBuilder<double>(
                stream: _service.getMonthlyTotal(),
                builder: (context, snapshot) {
                  final total = snapshot.data ?? 0;
                  return Container(
                    width: double.infinity,
                    margin: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 10.h),
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E1E2C).withValues(alpha: 0.6)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(24.r),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.white,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF6C63FF,
                          ).withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          "Monthly Commitment",
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: textColor.withValues(alpha: 0.6),
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
                                color: textColor,
                                letterSpacing: -1.0,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: -0.2, end: 0);
                },
              ),

              StreamBuilder<List<RecurringPayment>>(
                stream: _service.getPayments(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return SizedBox(
                      height: 400.h,
                      child: const Center(child: CircularProgressIndicator()),
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
                                    color: Colors.white.withValues(alpha: 0.05),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF00E5FF,
                                        ).withValues(alpha: 0.1),
                                        blurRadius: 30,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.subscriptions_outlined,
                                    size: 60.sp,
                                    color: textColor.withValues(alpha: 0.3),
                                  ),
                                )
                                .animate(onPlay: (c) => c.repeat(reverse: true))
                                .scale(
                                  begin: const Offset(1, 1),
                                  end: const Offset(1.05, 1.05),
                                  duration: const Duration(seconds: 2),
                                ),
                            SizedBox(height: 24.h),
                            Text(
                                  "No subscriptions yet",
                                  style: TextStyle(
                                    color: textColor.withValues(alpha: 0.6),
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
                      return GestureDetector(
                            onTap: () => Get.to(
                              () => SubscriptionDetailsScreen(payment: item),
                            ),
                            child: _buildCard(item, isDark, textColor, context),
                          )
                          .animate(delay: (index * 100).ms)
                          .fadeIn(duration: 400.ms)
                          .slideX(begin: 0.1, end: 0, curve: Curves.easeOut);
                    },
                  );
                },
              ),
            ],
          ),
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
                ? const Color(0xFF00E676).withValues(
                    alpha: 0.3,
                  ) // Green glow for paid
                : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.5)),
            width: isPaid ? 1.5 : 1,
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
                  ? const Color(0xFF00E676).withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
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
                      : (isPaid
                            ? [const Color(0xFF00E676), const Color(0xFF00C853)]
                            : [
                                const Color(0xFF6C63FF),
                                const Color(0xFF4834D4),
                              ]),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18.r),
                boxShadow: [
                  BoxShadow(
                    color:
                        (isPaused
                                ? Colors.grey
                                : (isPaid
                                      ? const Color(0xFF00E676)
                                      : const Color(0xFF6C63FF)))
                            .withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                isPaused
                    ? Icons.pause_rounded
                    : (isPaid
                          ? Icons.check_circle_outline_rounded
                          : Icons.receipt_long_rounded),
                color: Colors.white,
                size: 22.sp,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      letterSpacing: 0.3,
                      decoration: isPaused ? TextDecoration.lineThrough : null,
                    ),
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
                          : (isPaid
                                ? const Color(0xFF00E676).withValues(alpha: 0.1)
                                : textColor.withValues(alpha: 0.06)),
                      borderRadius: BorderRadius.circular(6.r),
                      border: isPaused
                          ? Border.all(
                              color: Colors.orange.withValues(alpha: 0.3),
                              width: 1,
                            )
                          : (isPaid
                                ? Border.all(
                                    color: const Color(
                                      0xFF00E676,
                                    ).withValues(alpha: 0.3),
                                  )
                                : null),
                    ),
                    child: Text(
                      isPaused
                          ? "PAUSED"
                          : (isPaid
                                ? "PAID • Due ${DateFormat('MMM dd').format(item.nextDueDate)}"
                                : "${item.frequency.name.capitalizeFirst} • Due ${DateFormat('MMM dd').format(item.nextDueDate)}"),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: isPaused
                            ? Colors.orange
                            : (isPaid
                                  ? const Color(0xFF00E676)
                                  : textColor.withValues(alpha: 0.6)),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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

  void _showAddDialog(
    BuildContext context,
    bool isDark, {
    RecurringPayment? payment,
  }) {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: payment?.title);
    final amountCtrl = TextEditingController(text: payment?.amount.toString());
    RecurringFrequency freq = payment?.frequency ?? RecurringFrequency.monthly;
    DateTime nextPaymentDate =
        payment?.nextDueDate ?? DateTime.now().add(const Duration(days: 30));

    // Category Logic
    final categories = _txController.categories;
    String category = payment?.category ?? 'Utilities';

    // Ensure category exists in list (optional but good for UX)
    // If exact match not found, we keep the string but it might not show as selected if we enforce strict values.
    // However, DropdownButton requires the value to be in the items list.
    // Let's create a safe list including the current category if it's missing.
    final categoryNames = categories.map((e) => e.name).toSet();
    if (category.isNotEmpty) categoryNames.add(category);
    final sortedCategories = categoryNames.toList()..sort();

    // Default if empty
    if (category.isEmpty && sortedCategories.isNotEmpty) {
      category = sortedCategories.first;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24.w,
                24.h,
                24.w,
                MediaQuery.of(context).viewInsets.bottom + 24.h,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment == null
                          ? "New Subscription"
                          : "Edit Subscription",
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    TextFormField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: "Name (e.g. Netflix)",
                      ),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    SizedBox(height: 16.h),
                    TextFormField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Amount"),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    SizedBox(height: 16.h),

                    // Frequency
                    DropdownButtonFormField<RecurringFrequency>(
                      initialValue: freq,
                      items: RecurringFrequency.values
                          .map(
                            (f) => DropdownMenuItem(
                              value: f,
                              child: Text(f.name.capitalizeFirst!),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setModalState(() => freq = v!),
                      decoration: const InputDecoration(labelText: "Frequency"),
                    ),

                    SizedBox(height: 16.h),

                    // Category Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      items: sortedCategories
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) => setModalState(() => category = v!),
                      decoration: const InputDecoration(labelText: "Category"),
                    ),

                    SizedBox(height: 16.h),

                    // Next Payment Date Picker
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: nextPaymentDate,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365 * 2),
                          ),
                        );
                        if (picked != null) {
                          setModalState(() => nextPaymentDate = picked);
                        }
                      },
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
                              "Next Payment: ${DateFormat('MMM dd, yyyy').format(nextPaymentDate)}",
                              style: TextStyle(fontSize: 16.sp),
                            ),
                            const Icon(Icons.calendar_today, size: 20),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 24.h),

                    SizedBox(
                      width: double.infinity,
                      height: 50.h,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            final amount = double.tryParse(amountCtrl.text) ?? 0;
                            if (amount <= 0) {
                              Get.snackbar("Invalid Amount", "Enter a valid amount greater than 0");
                              return;
                            }
                            final userId =
                                FirebaseAuth.instance.currentUser?.uid ?? '';
                            final newPayment = RecurringPayment(
                              id: payment?.id ?? const Uuid().v4(),
                              userId: userId,
                              title: titleCtrl.text.trim(),
                              amount: amount,
                              category: category,
                              frequency: freq,
                              startDate: payment?.startDate ?? DateTime.now(),
                              nextDueDate: nextPaymentDate,
                              isActive: true,
                            );

                            try {
                              if (payment == null) {
                                await _service.addPayment(newPayment);
                              } else {
                                await _service.updatePayment(newPayment);
                              }
                              if (context.mounted) Navigator.pop(context);
                            } catch (e) {
                              if (context.mounted) {
                                Get.snackbar("Error", "Failed to save. Please try again.");
                              }
                            }
                          }
                        },
                        child: const Text("Save"),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
