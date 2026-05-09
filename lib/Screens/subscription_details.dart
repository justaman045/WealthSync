import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Animations
import 'package:money_control/Models/recurring_payment_model.dart';
import 'package:money_control/Services/recurring_service.dart';
import 'package:money_control/Screens/transaction_details.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Services/error_handler.dart';

class SubscriptionDetailsScreen extends StatefulWidget {
  final RecurringPayment payment;

  const SubscriptionDetailsScreen({super.key, required this.payment});

  @override
  State<SubscriptionDetailsScreen> createState() =>
      _SubscriptionDetailsScreenState();
}

class _SubscriptionDetailsScreenState extends State<SubscriptionDetailsScreen> {
  final RecurringService _service = RecurringService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF1A1A2E)
          : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          "Subscription Details",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_auth.currentUser?.email)
                .collection('recurring_payments')
                .doc(widget.payment.id)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const SizedBox();
              }
              final data = snapshot.data!.data();
              if (data == null) return const SizedBox();
              final paymentData = RecurringPayment.fromMap(
                snapshot.data!.id,
                data as Map<String, dynamic>,
              );

              return PopupMenuButton<String>(
                icon: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: textColor.withValues(alpha: 0.1)),
                  ),
                  child: Icon(
                    Icons.more_vert_rounded,
                    color: textColor,
                    size: 20.sp,
                  ),
                ),
                offset: const Offset(0, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  side: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                color: isDark ? const Color(0xFF25253B) : Colors.white,
                elevation: 10,
                onSelected: (value) {
                  if (value == 'toggle') {
                    _handleToggleStatus(paymentData);
                  } else if (value == 'skip') {
                    _handleSkip(paymentData);
                  } else if (value == 'delete') {
                    _handleDelete(paymentData);
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color:
                                (paymentData.isActive
                                        ? Colors.orange
                                        : Colors.green)
                                    .withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            paymentData.isActive
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: paymentData.isActive
                                ? Colors.orange
                                : Colors.green,
                            size: 18.sp,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          paymentData.isActive
                              ? 'Pause Payment'
                              : 'Resume Payment',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (paymentData.isActive)
                    PopupMenuItem<String>(
                      value: 'skip',
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.skip_next_rounded,
                              color: Colors.blue,
                              size: 18.sp,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            'Skip this Payment',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                            size: 18.sp,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        const Text(
                          'Delete',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          SizedBox(width: 8.w),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_auth.currentUser?.email)
            .collection('recurring_payments')
            .doc(widget.payment.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Subscription not found"));
          }

          final data = snapshot.data!.data();
          if (data == null) {
            return const Center(child: Text("Subscription data not found"));
          }
          final paymentData = RecurringPayment.fromMap(
            snapshot.data!.id,
            data as Map<String, dynamic>,
          );

          return SingleChildScrollView(
            padding: EdgeInsets.all(20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(isDark, textColor, paymentData),
                SizedBox(height: 24.h),
                if (paymentData.isActive) ...[
                  _buildActionButtons(isDark, textColor, paymentData),
                  SizedBox(height: 32.h),
                ],
                Text(
                  "Payment History",
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ).animate().fadeIn(delay: 300.ms).slideX(),
                SizedBox(height: 16.h),
                _buildHistoryList(isDark, textColor),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(
    bool isDark,
    Color textColor,
    RecurringPayment payment,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30.r,
            backgroundColor: payment.isActive
                ? const Color(0xFF6C63FF).withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
            child: Icon(
              payment.isActive
                  ? Icons.receipt_long_rounded
                  : Icons.pause_rounded,
              color: payment.isActive ? const Color(0xFF6C63FF) : Colors.grey,
              size: 30.sp,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            payment.title,
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            "${CurrencyController.to.currencySymbol.value}${payment.amount.toStringAsFixed(0)} / ${payment.frequency.name}",
            style: TextStyle(
              fontSize: 16.sp,
              color: textColor.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          if (!payment.isActive)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  "PAUSED",
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            ),
          SizedBox(height: 24.h),
          Divider(color: textColor.withValues(alpha: 0.1)),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoItem("Category", payment.category, textColor),
              _buildInfoItem(
                "Next Due",
                payment.isActive
                    ? DateFormat('MMM dd, yyyy').format(payment.nextDueDate)
                    : "Paused",
                textColor,
                isHighlight: payment.isActive,
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildInfoItem(
    String label,
    String value,
    Color textColor, {
    bool isHighlight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: textColor.withValues(alpha: 0.4),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: isHighlight ? const Color(0xFF6C63FF) : textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
    bool isDark,
    Color textColor,
    RecurringPayment payment,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showMarkPaidDialog(context, isDark, payment),
        icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
        label: const Text("Mark Paid"),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 12.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildHistoryList(bool isDark, Color textColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_auth.currentUser?.email)
          .collection('transactions')
          .where('recurringPaymentId', isEqualTo: widget.payment.id)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32.w),
              child: Text(
                "No payment history linked yet.",
                style: TextStyle(color: textColor.withValues(alpha: 0.4)),
              ),
            ),
          ).animate().fadeIn(delay: 400.ms);
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (c, i) => SizedBox(height: 12.h),
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final tx = TransactionModel.fromMap(
              doc.id,
              doc.data() as Map<String, dynamic>,
            );

            return GestureDetector(
                  onTap: () => Get.to(
                    () => TransactionResultScreen(
                      transaction: tx,
                      type: TransactionResultType.success,
                    ),
                  ),
                  child: Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10.w),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            color: Colors.green,
                            size: 18.sp,
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('MMM dd, yyyy').format(tx.date),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.sp,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                tx.note ?? 'Payment',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: textColor.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "${CurrencyController.to.currencySymbol.value}${tx.amount.toStringAsFixed(0)}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                            color: textColor,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: textColor.withValues(alpha: 0.3),
                          size: 20.sp,
                        ),
                      ],
                    ),
                  ),
                )
                .animate(delay: (index * 50).ms)
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
          },
        );
      },
    );
  }

  void _showMarkPaidDialog(
    BuildContext context,
    bool isDark,
    RecurringPayment payment,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        title: const Text("Mark as Paid?"),
        content: const Text(
          "This will update the due date and creating a transaction record.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              // Close dialog first
              Navigator.pop(context);

              await _service.markAsPaid(payment, createTransaction: true);
              ErrorHandler.showSuccess("Payment recorded");
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleToggleStatus(RecurringPayment payment) async {
    final newState = !payment.isActive;
    DateTime? nextDate;

    // If resuming, ask for Next Due Date
    if (newState) {
      nextDate = await showDatePicker(
        context: context,
        initialDate: payment.nextDueDate.isAfter(DateTime.now())
            ? payment.nextDueDate
            : DateTime.now(),
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
        helpText: "Select Next Due Date",
      );

      // If user cancelled date picker, cancel the resume action
      if (nextDate == null) return;
    }

    await _service.togglePaymentStatus(
      payment.id,
      newState,
      nextDueDate: nextDate,
    );

    ErrorHandler.showSuccess(newState ? "Subscription Resumed" : "Subscription Paused");
  }

  Future<void> _handleSkip(RecurringPayment payment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
          title: const Text("Skip this payment?"),
          content: Text(
            "This will advance the due date to the next cycle without recording a payment.",
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text("Skip"),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _service.markAsPaid(payment, createTransaction: false);
      ErrorHandler.showSuccess("Payment skipped. Next due date updated.");
    }
  }

  Future<void> _handleDelete(RecurringPayment payment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Subscription?"),
        content: const Text(
          "Are you sure you want to delete this subscription? Past transactions will remain, but future reminders will stop.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _service.deletePayment(payment.id);
      if (!mounted) return;
      Navigator.of(context).pop(); // Close screen
      Get.snackbar(
        "Deleted",
        "Subscription removed successfully",
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
