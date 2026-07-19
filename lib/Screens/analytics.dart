// --- imports ---
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Utils/responsive.dart';
import 'package:money_control/Components/pro_lock_widget.dart';
import 'package:money_control/Components/adaptive_scaffold.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Screens/analytics_trends.dart';
import 'package:money_control/Screens/transaction_history.dart';
import 'package:money_control/Services/export_service.dart';
import 'package:money_control/Controllers/tutorial_controller.dart';

import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/subscription_controller.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Controllers/loan_controller.dart';
import 'package:money_control/Services/recurring_service.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:money_control/Components/colors.dart';

import 'package:flutter/rendering.dart' as rendering;

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

// -------------------------------

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late final TransactionController _transactionController;

  late final String uid;
  late final String? email;

  ThemeData _cachedTheme = _dummyTheme;
  bool _cachedIsDark = false;
  static final ThemeData _dummyTheme = ThemeData();

  bool get isDark => _cachedIsDark;

  // Restored State Variables
  final ValueNotifier<bool> _isBottomBarVisible = ValueNotifier(true);
  Worker? _txWorker;
  Worker? _loadingWorker;
  int _touchedIndex = -1;
  final GlobalKey _keyChart = GlobalKey();
  final ScreenshotController _screenshotController = ScreenshotController();

  // ---- PERIOD SELECTION ----
  String _period = "This Month";
  DateTimeRange? _customRange;

  final List<String> _periodOptions = [
    "Last Month",
    "This Month",
    "Last 3 Months",
    "Last 6 Months",
    "This Year",
    "Last Year",
    "All Time",
    "Custom Range",
  ];

  String? _categoryFilter;
  int _calendarMonthOffset = 0;
  Map<int, List<String>> _calendarDayEvents = {};

  List<TransactionModel>? _filteredCache;
  String? _filteredCachePeriod;
  String? _filteredCacheCategory;
  DateTimeRange? _filteredCacheCustomRange;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<TransactionController>()) {
      Get.put(TransactionController());
    }
    _transactionController = Get.find<TransactionController>();
    final user = FirebaseAuth.instance.currentUser;
    uid = user?.uid ?? "";
    email = user?.email;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      TutorialController.showAnalyticsTutorial(context, keyChart: _keyChart);
    });
    _loadCalendarEvents();
    _txWorker = ever(_transactionController.transactions, (_) {
      if (mounted) setState(() {});
    });
    _loadingWorker = ever(_transactionController.isLoading, (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadCalendarEvents() async {
    final now = DateTime.now();
    final displayMonth = DateTime(now.year, now.month + _calendarMonthOffset, 1);
    final daysInMonth = DateTime(displayMonth.year, displayMonth.month + 1, 0).day;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    final Map<int, List<String>> events = {};

    // Salary: largest income credit in the displayed month
    double maxCredit = 0;
    int? salaryDay;
    for (final tx in _transactionController.transactions) {
      if (tx.recipientId != currentUid) continue;
      if (tx.date.year != displayMonth.year || tx.date.month != displayMonth.month) continue;
      if (tx.amount.abs() > maxCredit) {
        maxCredit = tx.amount.abs();
        salaryDay = tx.date.day;
      }
    }
    if (salaryDay != null && maxCredit > 0) {
      events[salaryDay] = [...(events[salaryDay] ?? []), 'salary'];
    }

    // Loan EMI days from startDate day-of-month
    try {
      for (final loan in LoanController.to.loans) {
        final day = loan.startDate.day.clamp(1, daysInMonth);
        events[day] = [...(events[day] ?? []), 'emi'];
      }
    } catch (e) {
      debugPrint("Calendar loan events error: $e");
    }

    // Recurring payments (async stream) — use startDate day-of-month so
    // dots appear on the correct day for any displayed month, not just next due month
    try {
      final payments = await RecurringService().getPayments().first;
      final lastDayOfDisplay = DateTime(displayMonth.year, displayMonth.month + 1, 0);
      for (final p in payments) {
        if (!p.isActive) continue;
        if (p.startDate.isAfter(lastDayOfDisplay)) continue;
        final day = p.startDate.day.clamp(1, daysInMonth);
        events[day] = [...(events[day] ?? []), 'bill'];
      }
    } catch (e) {
      debugPrint("Calendar recurring events error: $e");
    }

    if (mounted) setState(() => _calendarDayEvents = events);
  }

  @override
  void dispose() {
    _txWorker?.dispose();
    _loadingWorker?.dispose();
    _isBottomBarVisible.dispose();
    super.dispose();
  }

  List<TransactionModel> get _all => _transactionController.transactions;
  bool get _loading => _transactionController.isLoading.value;

  String get _periodLabel {
    if (_period == "Custom Range" && _customRange != null) {
      final fmt = DateFormat('MMM d');
      return '${fmt.format(_customRange!.start)} – ${fmt.format(_customRange!.end)}';
    }
    return _period;
  }

  // ---------------- DATE RANGES ---------------------

  DateTimeRange _getDateRange() {
    final now = DateTime.now();

    switch (_period) {
      case "Last Month":
        final prev = DateTime(now.year, now.month - 1, 1);
        return DateTimeRange(
          start: prev,
          end: DateTime(prev.year, prev.month + 1, 1),
        );

      case "This Month":
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 1),
        );

      case "Last 3 Months":
        return DateTimeRange(
          start: DateTime(now.year, now.month - 2, 1),
          end: DateTime(now.year, now.month + 1, 1),
        );

      case "Last 6 Months":
        return DateTimeRange(
          start: DateTime(now.year, now.month - 5, 1),
          end: DateTime(now.year, now.month + 1, 1),
        );

      case "This Year":
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year + 1, 1, 1),
        );

      case "Last Year":
        return DateTimeRange(
          start: DateTime(now.year - 1, 1, 1),
          end: DateTime(now.year, 1, 1),
        );

      case "All Time":
        return DateTimeRange(start: DateTime(2000), end: DateTime(2100));

      case "Custom Range":
        if (_customRange != null) {
          return DateTimeRange(
            start: _customRange!.start,
            end: _customRange!.end.add(const Duration(days: 1)),
          );
        }
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 1),
        );

      default:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 1),
        );
    }
  }

  // --------------- FILTERED TRANSACTIONS ----------------

  List<TransactionModel> get _filtered {
    if (_filteredCache != null &&
        _filteredCachePeriod == _period &&
        _filteredCacheCategory == _categoryFilter &&
        _filteredCacheCustomRange == _customRange) {
      return _filteredCache!;
    }
    final range = _getDateRange();
    _filteredCache = _all.where((tx) {
      final inRange =
          tx.date.compareTo(range.start) >= 0 &&
          tx.date.compareTo(range.end) < 0;
      final catMatch =
          _categoryFilter == null || tx.category == _categoryFilter;
      return inRange && catMatch;
    }).toList();
    _filteredCachePeriod = _period;
    _filteredCacheCategory = _categoryFilter;
    _filteredCacheCustomRange = _customRange;
    return _filteredCache!;
  }

  // ---------------- QUICK OVERVIEW AGGREGATION ----------------

  // Daily totals
  (double income, double expense) get _todayTotals {
    final today = DateTime.now();
    final filtered = _all.where(
      (tx) =>
          tx.date.year == today.year &&
          tx.date.month == today.month &&
          tx.date.day == today.day,
    );

    double i = 0, e = 0;
    for (var tx in filtered) {
      if (tx.recipientId == uid) i += tx.amount;
      if (tx.senderId == uid) e += tx.amount.abs() + tx.tax;
    }
    return (i, e);
  }

  // Weekly totals
  (double income, double expense) get _thisWeekTotals {
    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1)); // Monday start
    final weekEnd = weekStart.add(const Duration(days: 7));

    final filtered = _all.where(
      (tx) => !tx.date.isBefore(weekStart) && tx.date.isBefore(weekEnd),
    );

    double i = 0, e = 0;
    for (var tx in filtered) {
      if (tx.recipientId == uid) i += tx.amount;
      if (tx.senderId == uid) e += tx.amount.abs() + tx.tax;
    }
    return (i, e);
  }

  // Monthly totals
  (double income, double expense) get _thisMonthTotals {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);

    final filtered = _all.where(
      (tx) => tx.date.compareTo(start) >= 0 && tx.date.compareTo(end) < 0,
    );

    double i = 0, e = 0;
    for (var tx in filtered) {
      if (tx.recipientId == uid) i += tx.amount;
      if (tx.senderId == uid) e += tx.amount.abs() + tx.tax;
    }
    return (i, e);
  }

  // --------------- AGGREGATION ------------------------

  double get totalIncome {
    return _filtered.fold(0, (prev, tx) {
      if (tx.recipientId == uid) return prev + tx.amount;
      return prev;
    });
  }

  double get totalExpense {
    return _filtered.fold(0, (prev, tx) {
      if (tx.senderId == uid) return prev + tx.amount.abs() + tx.tax;
      return prev;
    });
  }

  double get netBalance => totalIncome - totalExpense;

  // Spending by category
  Map<String, double> get spendingByCategory {
    final Map<String, double> map = {};
    for (var tx in _filtered.where((t) => t.senderId == uid)) {
      map[tx.category ?? "Other"] =
          (map[tx.category ?? "Other"] ?? 0) + tx.amount.abs() + tx.tax;
    }
    return map;
  }

  // Monthly trend
  List<_MonthPoint> get _monthlyTrend {
    final map = <String, _MonthPoint>{};
    for (var tx in _filtered) {
      final key = "${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}";
      map.putIfAbsent(
        key,
        () =>
            _MonthPoint(label: "${_monthAbbr(tx.date.month)} ${tx.date.year}"),
      );

      if (tx.recipientId == uid) map[key]!.income += tx.amount;
      if (tx.senderId == uid) map[key]!.expense += (tx.amount.abs() + tx.tax);
    }

    final keys = map.keys.toList()..sort((a, b) => a.compareTo(b));

    return keys.map((k) => map[k]!).toList();
  }

  String _monthAbbr(int m) {
    const list = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return list[(m - 1).clamp(0, 11)];
  }

  // ---------------- EXPORT --------------------------

  Future<void> _exportCsv() async {
    final SubscriptionController subscriptionController = Get.find();
    if (!subscriptionController.isPro) {
      _showProLockModal(
        "Data Export",
        "Export your transaction history as CSV.",
      );
      return;
    }
    await ExportService.exportTransactionsCSV(_filtered);
  }

  Future<void> _exportPdf() async {
    final SubscriptionController subscriptionController = Get.find();
    if (!subscriptionController.isPro) {
      _showProLockModal(
        "Data Export",
        "Generate detailed PDF reports for analysis.",
      );
      return;
    }
    await ExportService.exportAnalyticsPDF(
      filtered: _filtered,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netBalance: netBalance,
      periodLabel: _periodLabel,
    );
  }

  Future<void> _shareReport() async {
    final SubscriptionController subscriptionController = Get.find();
    if (!subscriptionController.isPro) {
      _showProLockModal("Share Report", "Share your monthly report as an image.");
      return;
    }
    try {
      final Uint8List? image = await _screenshotController.capture(pixelRatio: 2.0);
      if (image == null) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(image, name: 'money_control_report.png', mimeType: 'image/png')],
          text: 'My $_periodLabel Financial Report — Money Control',
        ),
      );
    } catch (e) {
      debugPrint("Share report error: $e");
    }
  }

  Future<void> _exportTaxSummary() async {
    final SubscriptionController subscriptionController = Get.find();
    if (!subscriptionController.isPro) {
      _showProLockModal("Tax Summary", "Export categorized annual tax summary PDF.");
      return;
    }
    await ExportService.exportTaxSummaryPDF(
      filtered: _filtered,
      periodLabel: _periodLabel,
    );
  }

  void _showProLockModal(String title, String description) {
    final isDark = _cachedIsDark;
    showModalBottomSheet(
      context: context,
      constraints: BoxConstraints(maxWidth: Responsive.sheetMaxWidth(context)),
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (context) =>
          ProLockWidget(title: title, description: description),
    );
  }

  // ================================================================
  // UI
  // ================================================================

  @override
  Widget build(BuildContext context) {
    _cachedTheme = Theme.of(context);
    _cachedIsDark = _cachedTheme.brightness == Brightness.dark;
    final isDark = _cachedIsDark;
    return AdaptiveScaffold(
      currentIndex: 1,
      isVisible: _isBottomBarVisible,
      backgroundColor: Colors.transparent,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark ? AppColors.darkGradient : AppColors.lightGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      appBar: AppBar(
          title: Text(
            "Analytics & Reports",
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
          ),
          actions: [
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
              color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
              surfaceTintColor: isDark ? AppColors.darkSurface : Colors.white,
              onSelected: (v) {
                if (v == "csv") {
                  _exportCsv();
                } else if (v == "pdf") {
                  _exportPdf();
                } else if (v == "tax") {
                  _exportTaxSummary();
                } else if (v == "share") {
                  _shareReport();
                }
              },
              itemBuilder: (ctx) {
                final c = isDark ? Colors.white : AppColors.lightTextPrimary;
                return [
                  PopupMenuItem(
                    value: "share",
                    child: Row(children: [
                      Icon(Icons.share_outlined, color: c, size: 18.sp),
                      SizedBox(width: 10.w),
                      Text("Share Report", style: TextStyle(color: c)),
                    ]),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: "csv",
                    child: Row(children: [
                      Icon(Icons.table_chart_outlined, color: c, size: 18.sp),
                      SizedBox(width: 10.w),
                      Text("Export CSV", style: TextStyle(color: c)),
                    ]),
                  ),
                  PopupMenuItem(
                    value: "pdf",
                    child: Row(children: [
                      Icon(Icons.picture_as_pdf_outlined, color: c, size: 18.sp),
                      SizedBox(width: 10.w),
                      Text("Export PDF", style: TextStyle(color: c)),
                    ]),
                  ),
                  PopupMenuItem(
                    value: "tax",
                    child: Row(children: [
                      Icon(Icons.receipt_long_outlined, color: c, size: 18.sp),
                      SizedBox(width: 10.w),
                      Text("Tax Summary PDF", style: TextStyle(color: c)),
                    ]),
                  ),
                ];
              },
            ),
          ],
        ),
        extendBody: true,
        body: NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (notification.direction == rendering.ScrollDirection.reverse) {
              if (_isBottomBarVisible.value) _isBottomBarVisible.value = false;
            } else if (notification.direction ==
                rendering.ScrollDirection.forward) {
              if (!_isBottomBarVisible.value) _isBottomBarVisible.value = true;
            }
            return true;
          },
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
                )
              : Screenshot(
                  controller: _screenshotController,
                  child: _buildBody(),
                ),
        ),
    );
  }

  Widget _buildBody() {
    final categories = spendingByCategory.keys.toList();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 100.h),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ------------ FILTER SECTION ------------------
          _StaggeredSlideFade(
            delay: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : AppColors.lightBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.05),
                    blurRadius: 15.r,
                    offset: Offset(0, 8.h),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Data Filters",
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF00E5FF,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Icon(
                          Icons.filter_list,
                          size: 18.sp,
                          color: const Color(0xFF00E5FF),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _dropdown<String>(
                          label: "Period",
                          value: _period,
                          items: _periodOptions,
                          onChanged: (v) async {
                            final SubscriptionController subCtrl = Get.find();
                            if (!subCtrl.isPro && v != "This Month") {
                              _showProLockModal(
                                "Advanced Analytics",
                                "Unlock full history and custom date ranges.",
                              );
                              return;
                            }
                            if (v == "Custom Range") {
                              final picked = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                                initialDateRange: _customRange ?? DateTimeRange(
                                  start: DateTime.now().subtract(const Duration(days: 30)),
                                  end: DateTime.now(),
                                ),
                              );
                               if (picked == null) return;
                               if (!mounted) return;
                               setState(() {
                                _customRange = picked;
                                _period = v;
                                _filteredCache = null;
                              });
                            } else {
                              setState(() { _period = v; _filteredCache = null; });
                            }
                          },
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: _dropdown<String?>(
                          label: "Category",
                          value: _categoryFilter,
                          items: [null, ...categories],
                          format: (v) => v ?? "All Categories",
                          onChanged: (v) => setState(() { _categoryFilter = v; _filteredCache = null; }),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 30.h),

          // -------- Summary Cards (Icons + Gradients) ----------
          _StaggeredSlideFade(
            delay: 100,
            child: Text(
              "Financial Summary",
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(height: 16.h),
          _StaggeredSlideFade(
            delay: 150,
            child: Row(
              children: [
                Expanded(
                  child: _summary(
                    "Income",
                    totalIncome,
                    const Color(0xFF00E5FF),
                    Icons.arrow_upward_rounded,
                    onTap: () => Get.to(() => TransactionHistoryScreen(initialTab: 1, filterMonth: DateTime.now())),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: _summary(
                    "Expenses",
                    totalExpense,
                    const Color(0xFFFF2975),
                    Icons.arrow_downward_rounded,
                    onTap: () => Get.to(() => TransactionHistoryScreen(initialTab: 2, filterMonth: DateTime.now())),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          _StaggeredSlideFade(
            delay: 200,
            child: _summary(
              "Net Balance",
              netBalance,
              netBalance >= 0
                  ? const Color(0xFF00E5FF)
                  : const Color(0xFFFF2975),
              Icons.account_balance_wallet_rounded,
              isWide: true,
              onTap: () => Get.to(() => TransactionHistoryScreen(initialTab: 0, filterMonth: DateTime.now())),
            ),
          ),

          SizedBox(height: 24.h),

          _StaggeredSlideFade(
            delay: 250,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  Get.to(() => const AnalyticsTrendsScreen());
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(30.r),
                    border: Border.all(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.5),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.insights,
                          color: const Color(0xFF6C63FF),
                          size: 18.sp,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          "View Advanced Category Trends",
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 14.sp,
                          color: isDark ? Colors.white54 : AppColors.lightTextSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: 32.h),

          // ------------ QUICK OVERVIEW (Progress Style) ------------------
          _StaggeredSlideFade(delay: 300, child: _quickOverviewCard()),

          SizedBox(height: 32.h),

          // ------------- TREND CHART -------------------
          _StaggeredSlideFade(delay: 400, child: _buildTrendChart()),

          SizedBox(height: 32.h),

          // ------------- PIE CHART -------------------
          _StaggeredSlideFade(delay: 500, child: _buildPieChart()),

          SizedBox(height: 32.h),

          // ------------- SPENDING HEATMAP -------------------
          _StaggeredSlideFade(delay: 600, child: _buildHeatmap()),

          SizedBox(height: 32.h),

          // ------------- MERCHANT INSIGHTS -------------------
          _StaggeredSlideFade(delay: 700, child: _buildMerchantInsights()),

          SizedBox(height: 32.h),

          // ------------- SALARY DETECTION -------------------
          _StaggeredSlideFade(delay: 800, child: _buildSalaryDetection()),

          SizedBox(height: 32.h),

          // ------------- SPENDING PERSONALITY -------------------
          _StaggeredSlideFade(delay: 900, child: _buildSpendingPersonality()),

          SizedBox(height: 50.h),
        ],
      ),
        ),
      ),
    );
  }

  // ---------- QUICK OVERVIEW CARD UI (Updated) -----------

  Color _c([double opacity = 1]) =>
      isDark ? Colors.white.withValues(alpha: opacity) : AppColors.lightTextPrimary.withValues(alpha: opacity);
  Color _glassBg() => isDark
      ? Colors.white.withValues(alpha: 0.05)
      : AppColors.lightSurface;
  Color _glassBorder() => isDark
      ? Colors.white.withValues(alpha: 0.1)
      : AppColors.lightBorder;

  Widget _quickOverviewCard() {
    final (dIncome, dExpense) = _todayTotals;
    final (wIncome, wExpense) = _thisWeekTotals;
    final (mIncome, mExpense) = _thisMonthTotals;

    final maxVal = [
      dIncome,
      dExpense,
      wIncome,
      wExpense,
      mIncome,
      mExpense,
    ].fold<double>(0, (p, e) => e > p ? e : p);

    return Container(
      padding: EdgeInsets.all(22.w),
      decoration: BoxDecoration(
        color: _glassBg(),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: _glassBorder()),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 15.r,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flash_on_rounded, size: 20.sp, color: Colors.amber),
              SizedBox(width: 8.w),
              Text(
                "Quick Overview",
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  color: _c(),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          _quickHistogramRow("Today", dIncome, dExpense, maxVal),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Divider(color: _glassBorder()),
          ),

          _quickHistogramRow("This Week", wIncome, wExpense, maxVal),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Divider(color: _glassBorder()),
          ),

          _quickHistogramRow("This Month", mIncome, mExpense, maxVal),
        ],
      ),
    );
  }

  Widget _quickHistogramRow(
    String label,
    double inc,
    double exp,
    double maxVal,
  ) {
    final safeMax = maxVal <= 0 ? 1 : maxVal;
    final incRatio = (inc / safeMax).clamp(0.0, 1.0);
    final expRatio = (exp / safeMax).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: _c(0.9),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),

        Row(
          children: [
            SizedBox(
              width: 40.w,
              child: Text(
                "In",
                style: TextStyle(
                  fontSize: 11.sp,
                  color: const Color(0xFF00E5FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Container(
                    height: 6.h,
                    decoration: BoxDecoration(
                      color: _glassBg(),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: incRatio > 0 ? incRatio : 0.01,
                    child: Container(
                      height: 6.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF),
                        borderRadius: BorderRadius.circular(10.r),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                            blurRadius: 6.r,
                            spreadRadius: 1.r,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            SizedBox(
              width: 60.w,
              child: Text(
                "${CurrencyController.to.currencySymbol.value}${inc.toStringAsFixed(0)}",
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: _c(0.7),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),

        Row(
          children: [
            SizedBox(
              width: 40.w,
              child: Text(
                "Out",
                style: TextStyle(
                  fontSize: 11.sp,
                  color: const Color(0xFFFF2975),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Container(
                    height: 6.h,
                    decoration: BoxDecoration(
                      color: _glassBg(),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: expRatio > 0 ? expRatio : 0.01,
                    child: Container(
                      height: 6.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF2975),
                        borderRadius: BorderRadius.circular(10.r),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF2975).withValues(alpha: 0.4),
                            blurRadius: 6.r,
                            spreadRadius: 1.r,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            SizedBox(
              width: 60.w,
              child: Text(
                "${CurrencyController.to.currencySymbol.value}${exp.toStringAsFixed(0)}",
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: _c(0.7),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------- Reusable dropdown with label -----------

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required Function(T) onChanged,
    String Function(T)? format,
  }) {
    final isDark = _cachedIsDark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            color: isDark ? Colors.white.withValues(alpha: 0.6) : AppColors.lightTextSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 6.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lightBorder,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              icon: Icon(
                Icons.keyboard_arrow_down,
                size: 18.sp,
                color: isDark ? Colors.white.withValues(alpha: 0.5) : AppColors.lightTextTertiary,
              ),
              items: items
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        format?.call(e) ?? e.toString(),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => onChanged(v as T),
            ),
          ),
        ),
      ],
    );
  }

  Widget _summary(
    String label,
    double amount,
    Color color,
    IconData icon, {
    bool isWide = false,
    VoidCallback? onTap,
  }) {
    final isDark = _cachedIsDark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
      width: isWide ? double.infinity : null,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 12.r,
            offset: Offset(0, 6.h),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 10.r,
                  spreadRadius: 1.r,
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 22.sp),
          ),
          SizedBox(width: 16.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: isDark ? Colors.white.withValues(alpha: 0.6) : AppColors.lightTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                "${CurrencyController.to.currencySymbol.value}${amount.toStringAsFixed(0)}",
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    ),  // Container
    );  // GestureDetector
  }

  // ================= TREND CHART ===================


  Widget _buildTrendChart() {
    final isDark = _cachedIsDark;
    final data = _monthlyTrend;
    if (data.isEmpty) {
      return _emptyCard("Not enough data for trend.");
    }

    // If only 1 month -> show bar chart comparison
    if (data.length == 1) {
      return _buildSingleMonthComparisonCard(data.first);
    }

    final maxY = data.fold<double>(
      0,
      (v, e) => [v, e.income, e.expense].reduce((a, b) => a > b ? a : b),
    );

    return Container(
      key: _keyChart,
      height: 300.h,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 15.r,
            spreadRadius: -2,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Monthly Trend",
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
              Row(
                children: [
                  _legendDot(const Color(0xFF00E5FF)),
                  Text(
                    " In ",
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white.withValues(alpha: 0.7) : AppColors.lightTextSecondary,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  _legendDot(const Color(0xFFFF2975)),
                  Text(
                    " Out",
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white.withValues(alpha: 0.7) : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 20.h),

          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY <= 0 ? 1 : maxY * 1.2,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.lightBorder.withValues(alpha: 0.3),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= data.length) return const SizedBox();
                        final parts = data[i].label.split(' ');
                        return Padding(
                          padding: EdgeInsets.only(top: 8.0.h),
                          child: Text(
                            parts.first,
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: isDark ? Colors.white.withValues(alpha: 0.6) : AppColors.lightTextTertiary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                lineBarsData: [
                  // Income
                  LineChartBarData(
                    spots: [
                      for (int i = 0; i < data.length; i++)
                        FlSpot(i.toDouble(), data[i].income),
                    ],
                    color: const Color(0xFF00E5FF),
                    isCurved: true,
                    curveSmoothness: 0.3,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                            radius: 4.r,
                            color: const Color(0xFF00E5FF),
                            strokeWidth: 2.r,
                            strokeColor: isDark ? const Color(0xFF16213E) : AppColors.lightSurface,
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                    ),
                  ),
                  // Expense
                  LineChartBarData(
                    spots: [
                      for (int i = 0; i < data.length; i++)
                        FlSpot(i.toDouble(), data[i].expense),
                    ],
                    color: const Color(0xFFFF2975),
                    isCurved: true,
                    curveSmoothness: 0.3,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                            radius: 4.r,
                            color: const Color(0xFFFF2975),
                            strokeWidth: 2.r,
                            strokeColor: isDark ? const Color(0xFF16213E) : AppColors.lightSurface,
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFFFF2975).withValues(alpha: 0.1),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        (isDark ? const Color(0xFF16213E) : AppColors.lightSurface).withValues(alpha: 0.9),
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipBorder: BorderSide(
                      color: isDark ? Colors.white.withValues(alpha: 0.2) : AppColors.lightBorder,
                      width: 1,
                    ),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          "${CurrencyController.to.currencySymbol.value}${spot.y.toStringAsFixed(0)}",
                          TextStyle(
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleMonthComparisonCard(_MonthPoint point) {
    final isDark = _cachedIsDark;
    final maxY = [point.income, point.expense].reduce((a, b) => a > b ? a : b);
    final safeMax = maxY <= 0 ? 1.0 : maxY;

    return Container(
      height: 280.h,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 15.r,
            spreadRadius: -2,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Current Period",
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                  Text(
                    point.label,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: isDark ? Colors.white.withValues(alpha: 0.6) : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: 16.h),

          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: safeMax * 1.1,
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, meta) {
                        return Padding(
                          padding: EdgeInsets.only(top: 8.0.h),
                          child: Text(
                            v == 0 ? "Income" : "Expense",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.sp,
                              color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: point.income,
                        color: const Color(0xFF00E5FF),
                        width: 28.w,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: point.expense,
                        color: const Color(0xFFFF2975),
                        width: 28.w,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color c) => Container(
    width: 10.w,
    height: 10.h,
    margin: EdgeInsets.only(right: 4.w),
    decoration: BoxDecoration(
      color: c,
      borderRadius: BorderRadius.circular(50.r),
      boxShadow: [
        BoxShadow(
          color: c.withValues(alpha: 0.4),
          blurRadius: 4.r,
          spreadRadius: 1.r,
        ),
      ],
    ),
  );

  Widget _buildPieChart() {
    final data = spendingByCategory;
    if (data.isEmpty) return const SizedBox.shrink();

    final total = totalExpense;
    if (total <= 0) return const SizedBox.shrink();

    final sortedKeys = data.keys.toList()
      ..sort((a, b) => data[b]!.compareTo(data[a]!));

    Map<String, double> finalMap = {};
    if (sortedKeys.length > 5) {
      for (int i = 0; i < 5; i++) {
        finalMap[sortedKeys[i]] = data[sortedKeys[i]]!;
      }
      double otherSum = 0;
      for (int i = 5; i < sortedKeys.length; i++) {
        otherSum += data[sortedKeys[i]]!;
      }
      finalMap["Others"] = otherSum;
    } else {
      finalMap = data;
    }

    int i = 0;
    final List<Color> colors = [
      const Color(0xFF00E5FF),
      const Color(0xFF2979FF),
      const Color(0xFF651FFF),
      const Color(0xFFFF4081),
      const Color(0xFFFF9100),
      Colors.grey,
    ];

    final isDark = _cachedIsDark;
    final sections = finalMap.entries.map((e) {
      final val = e.value;
      final pct = (val / total * 100).toStringAsFixed(1);
      final color = colors[i % colors.length];

      final isTouched = i == _touchedIndex;
      final fontSize = isTouched ? 14.sp : 10.sp;
      final radius = isTouched ? 60.r : 50.r;

      i++;
      return PieChartSectionData(
        value: val,
        title: isTouched ? "$pct%" : "$pct%",
        color: color,
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black45, blurRadius: 2)],
        ),
      );
    }).toList();

    return GlassContainer(
      padding: EdgeInsets.all(20.w),
      borderRadius: BorderRadius.circular(24.r),
      child: Column(
        children: [
          Text(
            "Expense Breakdown",
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          SizedBox(height: 24.h),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              _touchedIndex = -1;
                              return;
                            }
                            _touchedIndex = pieTouchResponse
                                .touchedSection!
                                .touchedSectionIndex;
                          });
                        },
                      ),
                      sections: sections,
                      centerSpaceRadius: 30.r,
                      sectionsSpace: 2.r,
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: finalMap.entries.toList().asMap().entries.map((e) {
                    final index = e.key;
                    final entry = e.value;
                    final color = colors[index % colors.length];
                    return Padding(
                      padding: EdgeInsets.only(bottom: 8.h),
                      child: Row(
                        children: [
                          Container(
                            width: 10.w,
                            height: 10.w,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                                fontSize: 12.sp,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String text) {
    final isDark = _cachedIsDark;
    return Container(
      height: 200.h,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lightBorder,
        ),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: isDark ? Colors.white.withValues(alpha: 0.7) : AppColors.lightTextSecondary,
          ),
        ),
      ),
    );
  }

  // ------------- SPENDING HEATMAP -------------------
  Widget _buildHeatmap() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final displayMonth = DateTime(now.year, now.month + _calendarMonthOffset, 1);
    final daysInMonth = DateTime(displayMonth.year, displayMonth.month + 1, 0).day;
    final theme = _cachedTheme;
    final isDark = _cachedIsDark;
    final sym = CurrencyController.to.currencySymbol.value;

    // Build daily spend map for the displayed month
    final Map<int, double> daySpend = {};
    for (final tx in _transactionController.transactions) {
      if (tx.senderId != uid) continue;
      if (tx.date.year != displayMonth.year || tx.date.month != displayMonth.month) continue;
      daySpend[tx.date.day] = (daySpend[tx.date.day] ?? 0) + tx.amount.abs();
    }
    final maxSpend = daySpend.values.fold(0.0, (a, b) => b > a ? b : a);
    final firstDayOffset = displayMonth.weekday % 7; // Sun=0

    final dayEvents = _calendarDayEvents;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: isDark ? Colors.transparent : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month navigation header
          Row(
            children: [
              Text(
                'Spending Heatmap',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() => _calendarMonthOffset--);
                  _loadCalendarEvents();
                },
                child: Icon(Icons.chevron_left, size: 22.sp, color: theme.textTheme.bodySmall?.color),
              ),
              SizedBox(width: 4.w),
              Text(
                DateFormat('MMM yyyy').format(displayMonth),
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: theme.textTheme.bodyMedium?.color),
              ),
              SizedBox(width: 4.w),
              GestureDetector(
                onTap: _calendarMonthOffset < 0
                    ? () {
                        setState(() => _calendarMonthOffset++);
                        _loadCalendarEvents();
                      }
                    : null,
                child: Icon(
                  Icons.chevron_right,
                  size: 22.sp,
                  color: _calendarMonthOffset < 0
                      ? theme.textTheme.bodySmall?.color
                      : (isDark ? Colors.white24 : AppColors.lightTextTertiary),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((label) {
              return Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 4.h),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 4.w,
              mainAxisSpacing: 4.h,
              childAspectRatio: 0.85,
            ),
            itemCount: firstDayOffset + daysInMonth,
            itemBuilder: (context, index) {
              if (index < firstDayOffset) return const SizedBox.shrink();
              final day = index - firstDayOffset + 1;
              final spend = daySpend[day] ?? 0;
              final intensity = maxSpend > 0 ? (spend / maxSpend) : 0.0;
              final bgColor = spend == 0
                  ? Colors.green.withValues(alpha: 0.08)
                  : Color.lerp(Colors.green.shade200, Colors.green.shade900, intensity)!;
              final isToday = _calendarMonthOffset == 0 && day == now.day;
              final events = dayEvents[day] ?? [];
              final hasSalary = events.contains('salary');
              final hasBill = events.contains('bill') || events.contains('emi');

              return GestureDetector(
                onTap: () {
                  final date = DateTime(displayMonth.year, displayMonth.month, day);
                  Get.to(() => TransactionHistoryScreen(filterDate: date));
                },
                child: Tooltip(
                  message: '$sym${spend.toStringAsFixed(0)}',
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(4.r),
                      border: Border.all(
                        color: isToday ? const Color(0xFF00E5FF) : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 8.sp,
                            color: intensity > 0.6 ? Colors.white : theme.textTheme.bodySmall?.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (hasSalary || hasBill)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (hasSalary)
                                Container(
                                  width: 4.w,
                                  height: 4.w,
                                  margin: EdgeInsets.only(right: 1.w),
                                  decoration: const BoxDecoration(
                                    color: Colors.cyanAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              if (hasBill)
                                Container(
                                  width: 4.w,
                                  height: 4.w,
                                  decoration: const BoxDecoration(
                                    color: Colors.amber,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 12.w,
            runSpacing: 4.h,
            children: [
              _heatmapLegend(Colors.green.shade200, 'Low spend'),
              _heatmapLegend(Colors.green.shade900, 'High spend'),
              _heatmapLegend(Colors.cyanAccent, 'Salary'),
              _heatmapLegend(Colors.amber, 'Bill/EMI due'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heatmapLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10.w,
          height: 10.w,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2.r)),
        ),
        SizedBox(width: 4.w),
        Text(label, style: TextStyle(fontSize: 10.sp, color: _cachedTheme.textTheme.bodySmall?.color)),
      ],
    );
  }

  // ------------- MERCHANT INSIGHTS -------------------
  Widget _buildMerchantInsights() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    final theme = _cachedTheme;
    final isDark = _cachedIsDark;
    final sym = CurrencyController.to.currencySymbol.value;

    final Map<String, ({int count, double total})> merchants = {};
    for (final tx in _filtered) {
      if (tx.senderId != uid) continue;
      final name = tx.recipientName.isEmpty ? 'Unknown' : tx.recipientName;
      final existing = merchants[name];
      if (existing == null) {
        merchants[name] = (count: 1, total: tx.amount.abs());
      } else {
        merchants[name] = (count: existing.count + 1, total: existing.total + tx.amount.abs());
      }
    }

    if (merchants.isEmpty) return const SizedBox.shrink();

    final sorted = merchants.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));
    final top5 = sorted.take(5).toList();

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: isDark ? Colors.transparent : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Merchants',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12.h),
          ...top5.map((e) => Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: Row(
              children: [
                Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      e.key.isNotEmpty ? e.key[0].toUpperCase() : '?',
                      style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFF00E5FF), fontSize: 14.sp),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.key, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      Text('${e.value.count} transaction${e.value.count > 1 ? 's' : ''}', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Text(
                  '$sym${e.value.total.toStringAsFixed(0)}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp, color: const Color(0xFFFF5252)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ------------- SALARY DETECTION -------------------
  Widget _buildSalaryDetection() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    final theme = _cachedTheme;
    final isDark = _cachedIsDark;
    final sym = CurrencyController.to.currencySymbol.value;

    // Pre-filter: exclude obvious non-salary credits by recipient name only
    final nonSalaryPattern = RegExp(
      r'emi|loan|payoff|pay off|installment|settlement|disburs',
      caseSensitive: false,
    );
    final candidateCredits = _all.where((tx) {
      if (tx.recipientId != uid) return false;
      return !nonSalaryPattern.hasMatch(tx.recipientName);
    }).toList();

    if (candidateCredits.length < 2) return const SizedBox.shrink();

    final amounts = candidateCredits.map((tx) => tx.amount.abs()).toList()..sort();
    final median = amounts.length % 2 == 1
        ? amounts[amounts.length ~/ 2]
        : (amounts[amounts.length ~/ 2 - 1] + amounts[amounts.length ~/ 2]) / 2;
    final maxCredit = amounts.last;

    // Likely salary: largest credit is > 3× median
    if (maxCredit <= median * 3) return const SizedBox.shrink();

    final salaryTx = candidateCredits.firstWhere(
      (tx) => tx.amount.abs() == maxCredit,
      orElse: () => candidateCredits.last,
    );

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF69F0AE).withValues(alpha: 0.08) : const Color(0xFF69F0AE).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: const Color(0xFF69F0AE).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: const BoxDecoration(color: Color(0xFF69F0AE), shape: BoxShape.circle),
            child: Icon(Icons.account_balance_wallet_outlined, color: Colors.black, size: 20.sp),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Salary Detected',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF69F0AE)),
                ),
                Text(
                  '${salaryTx.recipientName.isEmpty ? 'Largest credit' : salaryTx.recipientName} — $sym${maxCredit.toStringAsFixed(0)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // ------------- SPENDING PERSONALITY -------------------

  ({String label, String emoji, String description, Color color}) get _spendingPersonality {
    final income = totalIncome;
    final expense = totalExpense;
    final byCategory = spendingByCategory;
    final allSpend = byCategory.values.fold<double>(0, (a, b) => a + b);

    // Saving rate
    if (income > 0 && (income - expense) / income >= 0.40) {
      return (
        label: 'Smart Saver',
        emoji: '💰',
        description: 'You save over 40% of your income — great financial discipline!',
        color: const Color(0xFF69F0AE),
      );
    }

    if (allSpend > 0 && byCategory.isNotEmpty) {
      final top = byCategory.entries.reduce((a, b) => a.value > b.value ? a : b);
      final topPct = top.value / allSpend;
      final cat = top.key.toLowerCase();

      if (topPct >= 0.30 &&
          (cat.contains('food') || cat.contains('dining') || cat.contains('grocer') ||
           cat.contains('restaurant') || cat.contains('eat'))) {
        return (
          label: 'Foodie',
          emoji: '🍔',
          description: 'Food & dining makes up ${(topPct * 100).toStringAsFixed(0)}% of your spending.',
          color: const Color(0xFFFF8A65),
        );
      }

      if (topPct >= 0.25 &&
          (cat.contains('travel') || cat.contains('transport') || cat.contains('fuel') ||
           cat.contains('cab') || cat.contains('bus') || cat.contains('uber') || cat.contains('auto'))) {
        return (
          label: 'Commuter',
          emoji: '🚌',
          description: 'Transport accounts for ${(topPct * 100).toStringAsFixed(0)}% of your expenses.',
          color: const Color(0xFF4FC3F7),
        );
      }

      if (topPct >= 0.30 &&
          (cat.contains('shopping') || cat.contains('clothing') || cat.contains('fashion') ||
           cat.contains('apparel') || cat.contains('shoes'))) {
        return (
          label: 'Shopaholic',
          emoji: '🛍️',
          description: 'Shopping takes ${(topPct * 100).toStringAsFixed(0)}% of your budget.',
          color: const Color(0xFFE040FB),
        );
      }

      if (topPct >= 0.25 &&
          (cat.contains('entertainment') || cat.contains('leisure') || cat.contains('movie') ||
           cat.contains('game') || cat.contains('fun') || cat.contains('sport'))) {
        return (
          label: 'Fun Seeker',
          emoji: '🎉',
          description: 'Entertainment & leisure is your top spending category.',
          color: const Color(0xFFFFD54F),
        );
      }
    }

    // Average spend per transaction
    final sendTxs = _filtered.where((tx) => tx.senderId == uid).toList();
    if (sendTxs.isNotEmpty) {
      final avg = expense / sendTxs.length;
      if (avg > 5000) {
        return (
          label: 'Big Spender',
          emoji: '💸',
          description: 'Your average transaction is over ${CurrencyController.to.currencySymbol.value}5,000 — you go big.',
          color: const Color(0xFFFF5252),
        );
      }
      // Frequent spender: >20 transactions in last 30 days
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      final recentCount = _all
          .where((tx) => tx.senderId == uid && tx.date.isAfter(cutoff))
          .length;
      if (recentCount > 20) {
        return (
          label: 'Frequent Spender',
          emoji: '⚡',
          description: '$recentCount transactions in the last 30 days — always on the move.',
          color: const Color(0xFFFFB300),
        );
      }
    }

    if (income == 0) {
      return (
        label: 'Just Getting Started',
        emoji: '🌱',
        description: 'Add more transactions to unlock your spending personality.',
        color: const Color(0xFFA5D6A7),
      );
    }

    return (
      label: 'Balanced Spender',
      emoji: '⚖️',
      description: 'Your spending is well-distributed across categories.',
      color: const Color(0xFF80CBC4),
    );
  }

  Widget _buildSpendingPersonality() {
    final theme = _cachedTheme;
    final isDark = _cachedIsDark;
    final p = _spendingPersonality;
    final income = totalIncome;
    final expense = totalExpense;
    final rawRate = income > 0 ? (income - expense) / income : 0.0;
    final isDeficit = rawRate < 0;
    final savingRate = rawRate.clamp(0.0, 1.0);
    final rateColor = isDeficit ? Colors.redAccent : p.color;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: p.color.withValues(alpha: isDark ? 0.08 : 0.1),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: p.color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(color: p.color.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: Text(p.emoji, style: TextStyle(fontSize: 20.sp)),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Spending Personality',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: p.color,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      p.label,
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            p.description,
            style: TextStyle(fontSize: 13.sp, color: theme.textTheme.bodyMedium?.color),
          ),
          if (income > 0) ...[
            SizedBox(height: 14.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Saving rate', style: TextStyle(fontSize: 12.sp, color: theme.textTheme.bodyMedium?.color)),
                Text(
                  '${(rawRate * 100).toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: rateColor),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(6.r),
              child: LinearProgressIndicator(
                value: savingRate,
                minHeight: 6.h,
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation(rateColor),
              ),
            ),
            if (isDeficit) ...[
              SizedBox(height: 4.h),
              Text(
                'Spending exceeds income by ${((-rawRate) * 100).toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 11.sp, color: Colors.redAccent),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// --- Model for chart ---
class _MonthPoint {
  String label;
  double income = 0;
  double expense = 0;

  _MonthPoint({required this.label});
}

// ============================================
// ANIMATION HELPERS
// ============================================

class _StaggeredSlideFade extends StatefulWidget {
  final Widget child;
  final int delay;

  const _StaggeredSlideFade({required this.child, this.delay = 0});

  @override
  State<_StaggeredSlideFade> createState() => _StaggeredSlideFadeState();
}

class _StaggeredSlideFadeState extends State<_StaggeredSlideFade>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnim = CurvedAnimation(parent: _controller!, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller!, curve: Curves.easeOutQuad));

    if (widget.delay == 0) {
      _controller?.forward();
    } else {
      Future.delayed(Duration(milliseconds: widget.delay), () {
        if (mounted) _controller?.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(position: _slideAnim, child: widget.child),
    );
  }
}

// ... (existing imports)

// ... (in _AnalyticsScreenState)
