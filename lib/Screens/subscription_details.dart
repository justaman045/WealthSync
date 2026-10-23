import 'package:money_control/l10n/app_localizations.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:money_control/Components/colors.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Animations
import 'package:money_control/Models/recurring_payment_model.dart';
import 'package:money_control/Services/recurring_service.dart';
import 'package:money_control/Screens/transaction_details.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Services/error_handler.dart';
import 'package:money_control/Utils/responsive.dart';

class SubscriptionDetailsScreen extends StatefulWidget {
  final RecurringPayment payment;

  const SubscriptionDetailsScreen({super.key, required this.payment});

  @override
  State<SubscriptionDetailsScreen> createState() =>
      _SubscriptionDetailsScreenState();
}

class _SubscriptionDetailsScreenState extends State<SubscriptionDetailsScreen> {
  /// Hoisted out of build(): a stream built inline re-registers its
  /// listener on every rebuild.
  Stream<DocumentSnapshot<Object?>>? _paymentStream;

  /// Same reasoning as [_paymentStream]: [_historyStream] issues live Firestore
  /// queries, so it must not be rebuilt on every `build()`.
  Stream<List<QueryDocumentSnapshot>>? _historyStreamCache;

  final RecurringService _service = RecurringService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Timer? _loadTimer;
  bool _loadTimedOut = false;

  @override
  void initState() {
    super.initState();
    _repairUnlinkedHistory();
    // Bound the doc/history spinners: after a few seconds with no Firestore
    // emission (no network, no cache) show an offline note instead of spinning
    // forever. The StreamBuilders repopulate on their own once the stream
    // emits.
    _loadTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _loadTimedOut = true);
    });
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    super.dispose();
  }

  // Backfill recurringPaymentId onto auto-pay transactions that lost their
  // link, so they show up in the history stream below. Fire-and-forget: the
  // StreamBuilder re-renders automatically once the backfill lands.
  Future<void> _repairUnlinkedHistory() async {
    try {
      await _service.repairUnlinkedTransactions(widget.payment);
    } catch (e) {
      debugPrint('repairUnlinkedTransactions failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.darkBackground;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.subscriptionDetails,
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
            stream: _paymentStream ??= FirebaseFirestore.instance
                .collection('users')
                .doc(_auth.currentUser?.email)
                .collection('recurring_payments')
                .doc(widget.payment.id)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const SizedBox();
              }
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
                offset: Offset(0, 50.w),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  side: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurface,
                elevation: 10.w,
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
                                        ? AppColors.warning
                                        : AppColors.success)
                                    .withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            paymentData.isActive
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: paymentData.isActive
                                ? AppColors.warning
                                : AppColors.success,
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
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.skip_next_rounded,
                              color: AppColors.primary,
                              size: 18.sp,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            AppLocalizations.of(context)!.skipPayment,
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
                            color: AppColors.error.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.error,
                            size: 18.sp,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        const Text(
                          'Delete',
                          style: TextStyle(
                            color: AppColors.error,
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
        stream: _paymentStream ??= FirebaseFirestore.instance
            .collection('users')
            .doc(_auth.currentUser?.email)
            .collection('recurring_payments')
            .doc(widget.payment.id)
            .snapshots(),
          builder: (context, snapshot) {
            final waiting = snapshot.connectionState == ConnectionState.waiting;
            if (waiting && !_loadTimedOut) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            }
            if (waiting && !snapshot.hasData) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(32.w),
                  child: Text(
                    AppLocalizations.of(context)!.couldnTLoadSubscriptionCheck,
                    style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 14),
                  ),
                ),
              );
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text(AppLocalizations.of(context)!.subscriptionFound));
          }

          final data = snapshot.data!.data();
          if (data == null) {
            return Center(child: Text(AppLocalizations.of(context)!.subscriptionDataFound));
          }
          if (data is! Map<String, dynamic>) {
            return Center(child: Text(AppLocalizations.of(context)!.invalidSubscriptionDataFormat));
          }
          final paymentData = RecurringPayment.fromMap(
            snapshot.data!.id,
            data,
          );

          return SingleChildScrollView(
            padding: EdgeInsets.all(20.w),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderCard(isDark, textColor, paymentData),
                SizedBox(height: 24.h),
                if (paymentData.isActive) ...[
                  _buildAutoPayToggle(isDark, textColor, paymentData),
                  SizedBox(height: 24.h),
                  _buildActionButtons(isDark, textColor, paymentData),
                  SizedBox(height: 32.h),
                ],
                Text(
                  AppLocalizations.of(context)!.paymentHistory,
                  style: AppType.titleMedium(textColor),
                ).animate().fadeIn(delay: 300.ms).slideX(),
                SizedBox(height: 16.h),
                _buildHistoryList(isDark, textColor),
                    ],
                  ),
                ),
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
            blurRadius: 20.w,
            offset: Offset(0, 10.w),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30.r,
            backgroundColor: payment.isActive
                ? (_isPending(payment)
                      ? AppColors.warning.withValues(alpha: 0.12)
                      : AppColors.primary.withValues(alpha: 0.1))
                : Colors.grey.withValues(alpha: 0.1),
            child: Icon(
              payment.isActive
                  ? (_isPending(payment)
                        ? Icons.pending_actions_rounded
                        : Icons.receipt_long_rounded)
                  : Icons.pause_rounded,
              color: payment.isActive
                  ? (_isPending(payment) ? AppColors.warning : AppColors.primary)
                  : Colors.grey,
              size: 30.sp,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            payment.title,
            style: AppType.titleLarge(textColor),
          ),
          SizedBox(height: 8.h),
          Text(
            "${CurrencyController.to.currencySymbol.value}${payment.amount.toStringAsFixed(0)} / ${payment.frequency.name}",
            style: AppType.bodyLarge(textColor.withValues(alpha: 0.6)),
          ),
          if (!payment.isActive || _isPending(payment) || payment.autoPay)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: payment.isActive && !_isPending(payment)
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: payment.isActive && !_isPending(payment)
                        ? AppColors.primary.withValues(alpha: 0.35)
                        : AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  !payment.isActive
                      ? "PAUSED"
                      : (_isPending(payment)
                            ? "PENDING — due ${DateFormat('MMM dd, yyyy').format(payment.nextDueDate)}"
                            : "AUTO-PAY ON"),
                  style: AppType.labelMedium(payment.isActive && !_isPending(payment)
                        ? AppColors.primary
                        : AppColors.warning),
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
                highlightColor: _isPending(payment) ? AppColors.error : null,
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
    Color? highlightColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppType.bodySmall(textColor.withValues(alpha: 0.4)),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: isHighlight
                ? (highlightColor ?? AppColors.primary)
                : textColor,
          ),
        ),
      ],
    );
  }

  bool _isPending(RecurringPayment payment) =>
      payment.isActive &&
      !payment.autoPay &&
      !payment.nextDueDate.isAfter(DateTime.now());

  Widget _buildAutoPayToggle(
    bool isDark,
    Color textColor,
    RecurringPayment payment,
  ) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: payment.autoPay,
            onChanged: (value) async {
              await _service.toggleAutoPay(payment.id, value);
              if (!mounted) return;
              ErrorHandler.showSuccess(
                value ? "Auto-pay enabled" : "Auto-pay disabled",
              );
            },
            title: Text(
              AppLocalizations.of(context)!.autoPay,
              style: AppType.labelLarge(textColor),
            ),
            subtitle: Text(
              payment.autoPay
                  ? "When due, a transaction is created automatically."
                  : "Remind me when due — I'll mark it paid manually.",
              style: AppType.bodySmall(textColor.withValues(alpha: 0.6)),
            ),
            secondary: Icon(
              payment.autoPay
                  ? Icons.auto_awesome_rounded
                  : Icons.notifications_active_outlined,
              color: payment.autoPay
                  ? AppColors.primary
                  : AppColors.warning,
              size: 22.sp,
            ),
            activeThumbColor: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    bool isDark,
    Color textColor,
    RecurringPayment payment,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: () => _showMarkPaidDialog(context, isDark, payment),
          icon: Icon(Icons.check_circle_outline_rounded, size: 18.sp),
          label: Text(AppLocalizations.of(context)!.markPaid),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 12.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        ),
        if (!payment.autoPay) ...[
          SizedBox(height: 12.h),
          OutlinedButton.icon(
            onPressed: () => _showLinkTransactionSheet(context, isDark, payment),
            icon: Icon(Icons.link_rounded, size: 18.sp),
            label: Text(AppLocalizations.of(context)!.linkTransaction),
            style: OutlinedButton.styleFrom(
              foregroundColor: textColor,
              side: BorderSide(
                color: textColor.withValues(alpha: 0.3),
              ),
              padding: EdgeInsets.symmetric(vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        ],
      ],
    ).animate().fadeIn(delay: 200.ms);
  }

  void _showLinkTransactionSheet(
    BuildContext context,
    bool isDark,
    RecurringPayment payment,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      constraints: BoxConstraints(maxWidth: Responsive.sheetMaxWidth(context)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => _LinkTransactionSheet(
        payment: payment,
        isDark: isDark,
      ),
    );
  }

  // Merged history stream. Primary: transactions explicitly linked via
  // recurringPaymentId. Fallback: transactions whose note starts with
  // "Auto-payment for <title>" — this catches legacy auto-pay transactions
  // that lost their link (older builds never wrote recurringPaymentId) or
  // whose link points to a recreated payment doc. Single-field queries only,
  // so no composite Firestore index is required.
  Stream<List<QueryDocumentSnapshot>> _historyStream() {
    final base = FirebaseFirestore.instance
        .collection('users')
        .doc(_auth.currentUser?.email)
        .collection('transactions');

    final linked =
        base.where('recurringPaymentId', isEqualTo: widget.payment.id).snapshots();

    final titlePrefix = 'Auto-payment for ${widget.payment.title}';
    final byNote = base
        .where('note', isGreaterThanOrEqualTo: titlePrefix)
        .where('note', isLessThan: '$titlePrefix\uf8ff');

    // Primary stream stays live; the note-prefix fallback is re-fetched on
    // every emission (its contents are legacy/slow-changing, so a one-shot
    // refresh is sufficient). The fallback must never block the merged stream:
    // while offline its `.get()` can hang indefinitely, so it is time-boxed
    // and skipped on failure.
    return linked.asyncMap((snap) async {
      final seen = <String>{};
      final docs = <QueryDocumentSnapshot>[];
      for (final doc in snap.docs) {
        if (seen.add(doc.id)) docs.add(doc);
      }
      try {
        final noteSnap = await byNote.get().timeout(const Duration(seconds: 5));
        for (final doc in noteSnap.docs) {
          if (seen.add(doc.id)) docs.add(doc);
        }
      } catch (_) {
        // Offline or timed out — the primary linked stream still rendered.
      }
      return docs;
    });
  }

  Widget _buildHistoryList(bool isDark, Color textColor) {
    return StreamBuilder<List<QueryDocumentSnapshot>>(
      stream: _historyStreamCache ??= _historyStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !_loadTimedOut) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(32.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: textColor.withValues(alpha: 0.4),
                      size: 32.sp,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      AppLocalizations.of(context)!.couldnTLoadPaymentHistory,
                      style: AppType.titleSmall(textColor.withValues(alpha: 0.6)),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      '${snapshot.error}',
                      style: AppType.labelSmall(textColor.withValues(alpha: 0.35)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32.w),
              child: Text(
                AppLocalizations.of(context)!.paymentHistoryLinkedYet,
                style: TextStyle(color: textColor.withValues(alpha: 0.4)),
              ),
            ),
          ).animate().fadeIn(delay: 400.ms);
        }

        // Sort in Dart — avoids a composite index (recurringPaymentId ASC,
        // date DESC) that Firestore does not auto-create.
        final docs = snapshot.data!.toList()
          ..sort((a, b) {
            final da = ((a.data() as Map<String, dynamic>?)?['date'] as dynamic)
                ?.toDate();
            final db = ((b.data() as Map<String, dynamic>?)?['date'] as dynamic)
                ?.toDate();
            return (db ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
              da ?? DateTime.fromMillisecondsSinceEpoch(0),
            );
          });

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (c, i) => SizedBox(height: 12.h),
          itemBuilder: (context, index) {
            final doc = docs[index];
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
                            color: AppColors.success.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            color: AppColors.success,
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
                                style: AppType.titleSmall(textColor),
                              ),
                              Text(
                                tx.note ?? 'Payment',
                                style: AppType.bodySmall(textColor.withValues(alpha: 0.5)),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "${CurrencyController.to.currencySymbol.value}${tx.amount.abs().toStringAsFixed(0)}",
                          style: AppType.titleMedium(textColor),
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
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        title: Text(AppLocalizations.of(context)!.markPaid2),
        content: Text(
          AppLocalizations.of(context)!.updateDueDateCreatingTransaction,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              // Close dialog first
              Navigator.pop(context);

              await _service.markAsPaid(payment, createTransaction: true);
              if (!mounted) return;
              ErrorHandler.showSuccess("Payment recorded");
            },
            child: Text(AppLocalizations.of(context)!.confirm),
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
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          title: Text(AppLocalizations.of(context)!.skipPayment2),
          content: Text(
            AppLocalizations.of(context)!.advanceDueDateNextCycle,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(AppLocalizations.of(context)!.skip),
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
        title: Text(AppLocalizations.of(context)!.deleteSubscription),
        content: Text(
          AppLocalizations.of(context)!.sureWantDeleteSubscriptionPast,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _service.deletePayment(payment.id);
      if (!mounted) return;
      ErrorHandler.showSuccess("Subscription removed successfully");
      Navigator.of(context).pop(); // Close screen
    }
  }
}

class _LinkTransactionSheet extends StatefulWidget {
  final RecurringPayment payment;
  final bool isDark;

  const _LinkTransactionSheet({
    required this.payment,
    required this.isDark,
  });

  @override
  State<_LinkTransactionSheet> createState() => _LinkTransactionSheetState();
}

class _LinkTransactionSheetState extends State<_LinkTransactionSheet> {
  late final TransactionController _txController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<TransactionController>()) {
      Get.put(TransactionController());
    }
    _txController = Get.find<TransactionController>();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<TransactionModel> get _candidates {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final txs = _txController.transactions
        .where((t) => uid != null && t.senderId == uid)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return txs;
    return txs.where((t) {
      final haystack =
          '${t.recipientName} ${t.note ?? ''} ${t.category ?? ''}'.toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  Future<void> _link(TransactionModel tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? AppColors.darkSurface : Colors.white,
        title: Text(AppLocalizations.of(context)!.linkTransaction2),
        content: Text(
          'Link this transaction to "${widget.payment.title}"? '
          'The next due date will advance by one cycle from the transaction date.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context)!.link),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pop(); // Close the sheet

    try {
      await RecurringService().linkTransaction(
        payment: widget.payment,
        transactionId: tx.id,
      );
      if (!mounted) return;
      ErrorHandler.showSuccess("Transaction linked to ${widget.payment.title}");
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.showError("Failed to link transaction. Please try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final textColor = isDark ? Colors.white : AppColors.darkBackground;
    final candidates = _candidates;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24.w,
        24.h,
        24.w,
        MediaQuery.of(context).viewInsets.bottom + 24.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.linkTransaction,
                  style: AppType.titleLarge(textColor),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Icon(
                  Icons.close_rounded,
                  color: textColor.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            "Select a transaction to link to ${widget.payment.title}",
            style: AppType.bodySmall(textColor.withValues(alpha: 0.6)),
          ),
          SizedBox(height: 16.h),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: "Search transactions...",
              hintStyle: TextStyle(color: textColor.withValues(alpha: 0.4)),
              prefixIcon: Icon(Icons.search_rounded, color: textColor),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 400.h),
            child: candidates.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.w),
                      child: Text(
                        AppLocalizations.of(context)!.transactionsFound,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: candidates.length,
                    separatorBuilder: (c, i) => SizedBox(height: 8.h),
                    itemBuilder: (context, index) {
                      final tx = candidates[index];
                      final isLinkedHere =
                          tx.recurringPaymentId == widget.payment.id;
                      final linkedElsewhere =
                          tx.recurringPaymentId != null && !isLinkedHere;
                      return InkWell(
                        onTap: () => _link(tx),
                        borderRadius: BorderRadius.circular(12.r),
                        child: Container(
                          padding: EdgeInsets.all(14.w),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.grey.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(10.w),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.arrow_upward_rounded,
                                  color: AppColors.error,
                                  size: 16.sp,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tx.recipientName.isEmpty
                                          ? (tx.note ?? "Transaction")
                                          : tx.recipientName,
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      DateFormat('MMM dd, yyyy').format(tx.date),
                                      style: AppType.bodySmall(textColor.withValues(alpha: 0.5)),
                                    ),
                                  ],
                                ),
                              ),
                              if (isLinkedHere) ...[
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6.w,
                                    vertical: 2.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6.r),
                                  ),
                                  child: Text(
                                    AppLocalizations.of(context)!.linked,
                                    style: AppType.labelSmall(AppColors.success),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                              ] else if (linkedElsewhere) ...[
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppColors.warning,
                                  size: 16.sp,
                                ),
                                SizedBox(width: 8.w),
                              ],
                              Text(
                                "${CurrencyController.to.currencySymbol.value}${tx.amount.abs().toStringAsFixed(0)}",
                                style: AppType.labelLarge(textColor),
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
    );
  }
}
