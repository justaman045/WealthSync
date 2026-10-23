import 'package:money_control/l10n/app_localizations.dart';
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
import 'package:money_control/Components/empty_state.dart';
import 'package:money_control/Services/performance_controller.dart';

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
          title: Text(AppStrings.subscriptions),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        // The theme owns the FAB fill, foreground and shape. This used to be a
        // GradientContainer (both stops primary) around a transparent FAB with a
        // black label — the same indigo-on-black contrast bug the palette wave
        // fixed elsewhere, at 3.1:1.
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddDialog(context, isDark),
          icon: const Icon(Icons.add_rounded),
          label: Text(AppLocalizations.of(context)!.addSubscription),
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
                                    AppLocalizations.of(context)!.couldnTLoadSubscriptionsCheck,
                                    textAlign: TextAlign.center,
                                    style: AppType.bodySmall(
                                      isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Padding(
                            padding: EdgeInsets.only(top: AppSpace.s48.h),
                            child: EmptyStateWidget(
                              icon: Icons.subscriptions_outlined,
                              title: AppLocalizations.of(
                                context,
                              )!.subscriptionsYet,
                              subtitle: AppLocalizations.of(
                                context,
                              )!.trackNetflixRentSpotifyEtc,
                              actionLabel: AppLocalizations.of(
                                context,
                              )!.addSubscription,
                              onAction: () => _showAddDialog(context, isDark),
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
                              Semantics(
                                button: true,
                                child: GestureDetector(
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

    // One status colour drives the tile, badge and border: paid/pending/paused
    // were previously three hand-mixed gradients (two of which had both stops
    // equal, so they were not gradients) plus three ad-hoc box shadows.
    final statusColor = isPaused
        ? (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)
        : (isPending
              ? AppColors.warning
              : (isPaid ? AppColors.success : AppColors.primary));
    final m = AppLocalizations.of(context)!;

    return Opacity(
      opacity: isPaused ? 0.6 : (isPaid ? 0.8 : 1.0),
      child: Container(
        padding: EdgeInsets.all(AppSpace.s20.w),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.lg.r),
          border: Border.all(
            color: (isPaid || isPending)
                ? statusColor.withValues(alpha: 0.3)
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: (isPaid || isPending) ? 1.5 : 1,
          ),
          boxShadow: AppElevation.raised(isDark: isDark),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(AppSpace.s12.w),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(AppRadius.md.r),
                boxShadow: AppElevation.floating(
                  isDark: isDark,
                  tint: statusColor,
                ),
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
                          style: AppType.titleMedium(textColor).copyWith(
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
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.xs.r),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.auto,
                            style: AppType.labelSmall(AppColors.primary),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: AppSpace.s4.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpace.s8.w,
                      vertical: AppSpace.s4.h,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(
                        alpha: isPaused || isPending || isPaid ? 0.10 : 0.06,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.xs.r),
                      border: (isPaused || isPending || isPaid)
                          ? Border.all(
                              color: statusColor.withValues(alpha: 0.3),
                            )
                          : null,
                    ),
                    child: Text(
                      // These three labels were English literals inside string
                      // interpolation, which is why no audit saw them.
                      isPaused
                          ? m.recurringPausedLabel
                          : isPending
                          ? "${m.recurringPendingLabel} \u2022 ${m.due} ${DateFormat('MMM dd').format(item.nextDueDate)}"
                          : isPaid
                          ? "${m.recurringPaidLabel} \u2022 ${m.due} ${DateFormat('MMM dd').format(item.nextDueDate)}"
                          : "${item.frequency.name.capitalizeFirst} \u2022 ${m.due} ${DateFormat('MMM dd').format(item.nextDueDate)}",
                      style: AppType.labelSmall(
                        (isPaused || isPending || isPaid)
                            ? statusColor
                            : (isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary),
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
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6.r),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.autoPAYMISSED,
                        style: AppType.labelSmall(AppColors.error),
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
                  style: AppType.titleMedium(textColor),
                ),
                SizedBox(height: AppSpace.s4.h),
                // Was a 28 dp GestureDetector: below the 48 dp guideline, with
                // no ripple, no tooltip and nothing for a screen reader.
                IconButton(
                  onPressed: () => _showAddDialog(context, isDark, payment: item),
                  tooltip: m.recurringEditTooltip,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.edit_rounded,
                    size: 18.sp,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
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
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.subscriptions_outlined,
            size: 64.sp,
            color: textColor.withValues(alpha: 0.2),
          ),
          SizedBox(height: AppSpace.s16.h),
          Text(
            AppLocalizations.of(context)!.selectSubscriptionViewDetails,
            textAlign: TextAlign.center,
            style: AppType.bodyLarge(
              isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextTertiary,
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
          ErrorHandler.showError(
            AppLocalizations.of(context)!.recurringSaveFailed,
          );
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
                    ? AppLocalizations.of(context)!.recurringNewSubscription
                    : AppLocalizations.of(context)!.recurringEditSubscription,
                style: AppType.titleLarge(textColor),
              ),
              SizedBox(height: AppSpace.s20.h),
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.recurringNameLabel,
                ),
                validator: (v) => v!.isEmpty
                    ? AppLocalizations.of(context)!.recurringRequired
                    : null,
              ),
              SizedBox(height: AppSpace.s16.h),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.amount,
                ),
                validator: (v) => v!.isEmpty
                    ? AppLocalizations.of(context)!.recurringRequired
                    : null,
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
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.recurringFrequencyLabel,
                ),
              ),

              SizedBox(height: 16.h),

              // Category Dropdown
              DropdownButtonFormField<String>(
                initialValue: _category,
                items: _sortedCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.recurringCategoryLabel,
                ),
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
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.xs.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${AppLocalizations.of(context)!.recurringNextPaymentLabel} ${DateFormat('MMM dd, yyyy').format(_nextPaymentDate)}",
                        style: AppType.bodyLarge(textColor),
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
                      AppLocalizations.of(context)!.autoPay,
                      style: AppType.labelLarge(textColor),
                    ),
                    subtitle: Text(
                      _autoPay
                          ? AppLocalizations.of(context)!.recurringAutoPayHint
                          : AppLocalizations.of(context)!.recurringManualPayHint,
                      style: AppType.bodySmall(
                        isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    secondary: Icon(
                      _autoPay
                          ? Icons.auto_awesome_rounded
                          : Icons.notifications_active_outlined,
                      color: _autoPay ? AppColors.primary : AppColors.warning,
                      size: 22.sp,
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.primary,
                    checkColor: Colors.white,
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
    final lite = PerformanceController.to.liteMode.value;
    return StreamBuilder<double>(
      stream: _monthlyStream ??= _service.getMonthlyTotal(),
      builder: (context, snapshot) {
        final total = snapshot.data ?? 0;
        final amount = Text(
          "${CurrencyController.to.currencySymbol.value}${total.toStringAsFixed(0)}",
          style: AppType.displaySmall(widget.textColor),
        );
        final card = Container(
          width: double.infinity,
          margin: EdgeInsets.fromLTRB(
            AppSpace.s20.w,
            AppSpace.s8.h,
            AppSpace.s20.w,
            AppSpace.s8.h,
          ),
          padding: EdgeInsets.all(AppSpace.s24.w),
          decoration: BoxDecoration(
            color: widget.isDark
                ? AppColors.darkSurfaceCard
                : AppColors.lightSurfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.xl.r),
            border: Border.all(
              color: widget.isDark
                  ? AppColors.darkBorder
                  : AppColors.lightBorder,
            ),
            boxShadow: AppElevation.floating(
              isDark: widget.isDark,
              tint: AppColors.primary,
            ),
          ),
          child: Column(
            children: [
              Text(
                AppLocalizations.of(context)!.monthlyCommitment,
                style: AppType.bodyMedium(
                  widget.isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              SizedBox(height: AppSpace.s12.h),
              // The count-up used to run unconditionally, including in lite mode.
              if (lite)
                amount
              else
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: total),
                  duration: AppMotion.countUp,
                  curve: AppMotion.emphasized,
                  builder: (context, value, child) {
                    return Text(
                      "${CurrencyController.to.currencySymbol.value}${value.toStringAsFixed(0)}",
                      style: AppType.displaySmall(widget.textColor),
                    );
                  },
                ),
            ],
          ),
        );
        if (lite) return card;
        return card.animate().fadeIn(duration: AppMotion.slow).slideY(
          begin: -0.2,
          end: 0,
          curve: AppMotion.standard,
        );
      },
    );
  }
}
