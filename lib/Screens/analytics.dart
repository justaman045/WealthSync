// --- imports ---
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Components/pro_lock_widget.dart';
import 'package:money_control/Components/bottom_nav_bar.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Screens/analytics_trends.dart';
import 'package:money_control/Services/export_service.dart';
import 'package:money_control/Controllers/tutorial_controller.dart';

import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/subscription_controller.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:flutter/rendering.dart' as rendering;

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

// -------------------------------

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final TransactionController _transactionController = Get.find();

  late final String uid;
  late final String? email;

  // Restored State Variables
  final ValueNotifier<bool> _isBottomBarVisible = ValueNotifier(true);
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

  List<TransactionModel>? _filteredCache;
  String? _filteredCachePeriod;
  String? _filteredCacheCategory;
  DateTimeRange? _filteredCacheCustomRange;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    uid = user?.uid ?? "";
    email = user?.email;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      TutorialController.showAnalyticsTutorial(context, keyChart: _keyChart);
    });
  }

  @override
  void dispose() {
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
    return list[m - 1];
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
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/money_control_report.png');
      await file.writeAsBytes(image);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'My $_periodLabel Financial Report — Money Control',
        ),
      );
    } catch (_) {}
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A1A2E), // Midnight Void Top
            const Color(0xFF16213E).withValues(alpha: 0.95), // Deep Blue Bottom
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "Analytics & Reports",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              color: const Color(0xFF1A1A2E),
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
              itemBuilder: (ctx) => const [
                PopupMenuItem(
                  value: "share",
                  child: Row(children: [
                    Icon(Icons.share_outlined, color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Text("Share Report", style: TextStyle(color: Colors.white)),
                  ]),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: "csv",
                  child: Row(children: [
                    Icon(Icons.table_chart_outlined, color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Text("Export CSV", style: TextStyle(color: Colors.white)),
                  ]),
                ),
                PopupMenuItem(
                  value: "pdf",
                  child: Row(children: [
                    Icon(Icons.picture_as_pdf_outlined, color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Text("Export PDF", style: TextStyle(color: Colors.white)),
                  ]),
                ),
                PopupMenuItem(
                  value: "tax",
                  child: Row(children: [
                    Icon(Icons.receipt_long_outlined, color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Text("Tax Summary PDF", style: TextStyle(color: Colors.white)),
                  ]),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        extendBody: true,
        bottomNavigationBar: ValueListenableBuilder<bool>(
          valueListenable: _isBottomBarVisible,
          builder: (context, visible, child) {
            return AnimatedSlide(
              duration: const Duration(milliseconds: 200),
              offset: visible ? Offset.zero : const Offset(0, 1),
              child: child,
            );
          },
          child: const BottomNavBar(currentIndex: 1),
        ),
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
      ),
    );
  }

  Widget _buildBody() {
    final categories = spendingByCategory.keys.toList();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 100.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ------------ FILTER SECTION ------------------
          _StaggeredSlideFade(
            delay: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05), // Dark Glass
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
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
                          color: Colors.white,
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
                color: Colors.white,
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
                    const Color(0xFF00E5FF), // Neon Cyan
                    Icons.arrow_upward_rounded,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: _summary(
                    "Expenses",
                    totalExpense,
                    const Color(0xFFFF2975), // Neon Pink
                    Icons.arrow_downward_rounded,
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
            ),
          ),

          SizedBox(height: 24.h),

          _StaggeredSlideFade(
            delay: 250,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AnalyticsTrendsScreen(),
                    ),
                  );
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
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white54,
                        size: 12.sp,
                      ),
                    ],
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
    );
  }

  // ---------- QUICK OVERVIEW CARD UI (Updated) -----------

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
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
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
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          _quickHistogramRow("Today", dIncome, dExpense, maxVal),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Divider(color: Colors.white.withValues(alpha: 0.1)),
          ),

          _quickHistogramRow("This Week", wIncome, wExpense, maxVal),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Divider(color: Colors.white.withValues(alpha: 0.1)),
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
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),

        // Income Row
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
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: incRatio > 0 ? incRatio : 0.01,
                    child: Container(
                      height: 6.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF00E5FF,
                            ).withValues(alpha: 0.4),
                            blurRadius: 6,
                            spreadRadius: 1,
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
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),

        // Expense Row
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
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: expRatio > 0 ? expRatio : 0.01,
                    child: Container(
                      height: 6.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF2975),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFFF2975,
                            ).withValues(alpha: 0.4),
                            blurRadius: 6,
                            spreadRadius: 1,
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
                  color: Colors.white.withValues(alpha: 0.7),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            color: Colors.white.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 6.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF16213E),
              icon: Icon(
                Icons.keyboard_arrow_down,
                size: 18.sp,
                color: Colors.white.withValues(alpha: 0.5),
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
                          color: Colors.white,
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
  }) {
    return Container(
      width: isWide ? double.infinity : null,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
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
                  blurRadius: 10,
                  spreadRadius: 1,
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
                  color: Colors.white.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                "${CurrencyController.to.currencySymbol.value}${amount.toStringAsFixed(0)}",
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= TREND CHART ===================

  Widget _buildTrendChart() {
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
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 15,
            spreadRadius: -2,
            offset: const Offset(0, 8),
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
                  color: Colors.white,
                ),
              ),
              // Legend
              Row(
                children: [
                  _legendDot(const Color(0xFF00E5FF)),
                  Text(
                    " In ",
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  _legendDot(const Color(0xFFFF2975)),
                  Text(
                    " Out",
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withValues(alpha: 0.7),
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
                    color: Colors.white.withValues(alpha: 0.05),
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
                        // Show concise labels
                        final parts = data[i].label.split(
                          ' ',
                        ); // "Jan 2024" -> "Jan"
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            parts.first,
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                    ), // Clean look, remove left axis
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
                            radius: 4,
                            color: const Color(0xFF00E5FF),
                            strokeWidth: 2,
                            strokeColor: const Color(0xFF16213E),
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
                            radius: 4,
                            color: const Color(0xFFFF2975),
                            strokeWidth: 2,
                            strokeColor: const Color(0xFF16213E),
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
                        const Color(0xFF16213E).withValues(alpha: 0.9),
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipBorder: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          "${CurrencyController.to.currencySymbol.value}${spot.y.toStringAsFixed(0)}",
                          const TextStyle(
                            color: Colors.white,
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
    final maxY = [point.income, point.expense].reduce((a, b) => a > b ? a : b);
    final safeMax = maxY <= 0 ? 1.0 : maxY;

    return Container(
      height: 280.h,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 15,
            spreadRadius: -2,
            offset: const Offset(0, 8),
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
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    point.label,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.white.withValues(alpha: 0.6),
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
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            v == 0 ? "Income" : "Expense",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.sp,
                              color: Colors.white,
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
                        borderRadius: BorderRadius.circular(4),
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
                        borderRadius: BorderRadius.circular(4),
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
    width: 10,
    height: 10,
    margin: EdgeInsets.only(right: 4.w),
    decoration: BoxDecoration(
      color: c,
      borderRadius: BorderRadius.circular(50),
      boxShadow: [
        BoxShadow(
          color: c.withValues(alpha: 0.4),
          blurRadius: 4,
          spreadRadius: 1,
        ),
      ],
    ),
  );

  Widget _buildPieChart() {
    final data = spendingByCategory;
    if (data.isEmpty) return const SizedBox.shrink();

    final total = totalExpense;
    if (total <= 0) return const SizedBox.shrink();

    // Sort descending
    final sortedKeys = data.keys.toList()
      ..sort((a, b) => data[b]!.compareTo(data[a]!));

    // Limit to top 5 + "Others"
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

    // Pie chart needs sections
    int i = 0;
    final List<Color> colors = [
      const Color(0xFF00E5FF), // Cyan
      const Color(0xFF2979FF), // Blue
      const Color(0xFF651FFF), // Deep Purple
      const Color(0xFFFF4081), // Pink Accent
      const Color(0xFFFF9100), // Orange Accent
      Colors.grey,
    ];

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
              color: Colors.white,
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
                      sectionsSpace: 2,
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
                                color: Colors.white70,
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
    return Container(
      height: 200.h,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
      ),
    );
  }

  // ------------- SPENDING HEATMAP -------------------
  Widget _buildHeatmap() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Build daily spend map for this month
    final Map<int, double> daySpend = {};
    for (final tx in _filtered) {
      if (tx.senderId != uid) continue;
      if (tx.date.year != now.year || tx.date.month != now.month) continue;
      daySpend[tx.date.day] = (daySpend[tx.date.day] ?? 0) + tx.amount.abs();
    }
    final maxSpend = daySpend.values.fold(0.0, (a, b) => b > a ? b : a);

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spending Heatmap',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16.h),
          Wrap(
            spacing: 4.w,
            runSpacing: 4.h,
            children: List.generate(daysInMonth, (i) {
              final day = i + 1;
              final spend = daySpend[day] ?? 0;
              final intensity = maxSpend > 0 ? (spend / maxSpend) : 0.0;
              final color = spend == 0
                  ? Colors.green.withValues(alpha: 0.08)
                  : Color.lerp(
                      Colors.green.shade200,
                      Colors.green.shade900,
                      intensity,
                    )!;
              return Tooltip(
                message: 'Day $day: ${CurrencyController.to.currencySymbol.value}${spend.toStringAsFixed(0)}',
                child: Container(
                  width: 28.w,
                  height: 28.w,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4.r),
                    border: Border.all(
                      color: day == now.day
                          ? const Color(0xFF00E5FF)
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 9.sp,
                        color: intensity > 0.6 ? Colors.white : theme.textTheme.bodySmall?.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Container(width: 12.w, height: 12.w, decoration: BoxDecoration(color: Colors.green.shade200, borderRadius: BorderRadius.circular(2.r))),
              SizedBox(width: 4.w),
              Text('Low', style: TextStyle(fontSize: 10.sp, color: theme.textTheme.bodySmall?.color)),
              SizedBox(width: 12.w),
              Container(width: 12.w, height: 12.w, decoration: BoxDecoration(color: Colors.green.shade900, borderRadius: BorderRadius.circular(2.r))),
              SizedBox(width: 4.w),
              Text('High', style: TextStyle(fontSize: 10.sp, color: theme.textTheme.bodySmall?.color)),
            ],
          ),
        ],
      ),
    );
  }

  // ------------- MERCHANT INSIGHTS -------------------
  Widget _buildMerchantInsights() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24.r),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sym = CurrencyController.to.currencySymbol.value;

    final credits = _filtered
        .where((tx) => tx.recipientId == uid)
        .map((tx) => tx.amount.abs())
        .toList();

    if (credits.length < 2) return const SizedBox.shrink();

    credits.sort();
    final median = credits[credits.length ~/ 2];
    final maxCredit = credits.last;

    // Likely salary: largest credit is > 3× median
    if (maxCredit <= median * 3) return const SizedBox.shrink();

    final salaryTx = _filtered.firstWhere(
      (tx) => tx.recipientId == uid && tx.amount.abs() == maxCredit,
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
          description: 'Your average transaction is over ₹5,000 — you go big.',
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final p = _spendingPersonality;
    final income = totalIncome;
    final expense = totalExpense;
    final savingRate = income > 0 ? ((income - expense) / income).clamp(0.0, 1.0) : 0.0;

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
                  '${(savingRate * 100).toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: p.color),
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
                valueColor: AlwaysStoppedAnimation(p.color),
              ),
            ),
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
