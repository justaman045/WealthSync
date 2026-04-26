import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Models/transaction.dart';

class AnalyticsTrendsScreen extends StatefulWidget {
  const AnalyticsTrendsScreen({super.key});

  @override
  State<AnalyticsTrendsScreen> createState() => _AnalyticsTrendsScreenState();
}

class _AnalyticsTrendsScreenState extends State<AnalyticsTrendsScreen> {
  final TransactionController _controller = Get.find();

  // Filter State
  String? _selectedCategory = "All Categories";
  // ignore: unused_field
  final String _defaultCategory = "All Categories";

  String _selectedRange = "6 Months";
  final List<String> _rangeOptions = [
    "3 Months",
    "6 Months",
    "1 Year",
    "All Time",
  ];

  String get uid => FirebaseAuth.instance.currentUser?.uid ?? "";

  // Helpers to get data
  List<TransactionModel> get _expenses {
    return _controller.transactions.where((tx) => tx.senderId == uid).toList();
  }

  List<String> get _categories {
    final cats = _expenses.map((e) => e.category ?? "Other").toSet().toList()
      ..sort();
    return ["All Categories", ...cats];
  }

  // Chart Data Calculation
  (List<FlSpot>, double) _calculateChartData() {
    final expenses = _expenses;
    if (expenses.isEmpty) return ([], 100.0);

    // Ensure selected category is valid
    final currentCats = _categories;
    String cat = _selectedCategory ?? "All Categories";
    if (!currentCats.contains(cat)) {
      cat = "All Categories";
    }

    final Map<int, double> monthlySum = {};

    for (var tx in expenses) {
      if (cat == "All Categories" || tx.category == cat) {
        final key = tx.date.year * 100 + tx.date.month;
        monthlySum[key] = (monthlySum[key] ?? 0) + tx.amount.abs();
      }
    }

    final sortedKeys = monthlySum.keys.toList()..sort();

    // Filter keys based on range
    int count;
    switch (_selectedRange) {
      case "3 Months":
        count = 3;
        break;
      case "6 Months":
        count = 6;
        break;
      case "1 Year":
        count = 12;
        break;
      default:
        count = 9999;
        break;
    }

    final displayKeys = sortedKeys.length > count
        ? sortedKeys.sublist(sortedKeys.length - count)
        : sortedKeys;

    List<FlSpot> spots = [];
    double maxVal = 0;

    for (int i = 0; i < displayKeys.length; i++) {
      final key = displayKeys[i];
      final val = monthlySum[key]!;
      spots.add(FlSpot(i.toDouble(), val));
      if (val > maxVal) maxVal = val;
    }

    return (spots, maxVal > 0 ? maxVal * 1.2 : 100.0);
  }

  // Helper for bottom titles (X axis)
  String _getMonthLabel(int index) {
    final expenses = _expenses;
    if (expenses.isEmpty) return "";

    String cat = _selectedCategory ?? "All Categories";
    // Check validity inside the getter logic if needed, but for display it's ok.

    final Map<int, double> monthlySum = {};
    for (var tx in expenses) {
      if (cat == "All Categories" || tx.category == cat) {
        final key = tx.date.year * 100 + tx.date.month;
        monthlySum[key] = (monthlySum[key] ?? 0) + tx.amount;
      }
    }
    final sortedKeys = monthlySum.keys.toList()..sort();

    int count;
    switch (_selectedRange) {
      case "3 Months":
        count = 3;
        break;
      case "6 Months":
        count = 6;
        break;
      case "1 Year":
        count = 12;
        break;
      default:
        count = 9999;
        break;
    }

    final displayKeys = sortedKeys.length > count
        ? sortedKeys.sublist(sortedKeys.length - count)
        : sortedKeys;

    if (index < 0 || index >= displayKeys.length) return "";

    final key = displayKeys[index];
    final year = key ~/ 100;
    final month = key % 100;

    const months = [
      "",
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
    return "${months[month]}\n$year";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A1A2E), // Midnight Void
            const Color(0xFF16213E).withValues(alpha: 0.95),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            "Category Trends",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Obx(() {
          if (_controller.isLoading.value) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
            );
          }
          final (spots, maxY) = _calculateChartData();
          return _buildContent(spots, maxY);
        }),
      ),
    );
  }

  Widget _buildContent(List<FlSpot> spots, double maxY) {
    // Ensure selected category matches available categories
    final cats = _categories;
    if (_selectedCategory == null || !cats.contains(_selectedCategory)) {
      _selectedCategory = "All Categories";
    }
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Card
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                // Category Filter
                Row(
                  children: [
                    Icon(
                      Icons.category_outlined,
                      color: Colors.white70,
                      size: 20.sp,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          dropdownColor: const Color(0xFF16213E),
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white,
                          ),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                          ),
                          items: _categories.map((c) {
                            return DropdownMenuItem(value: c, child: Text(c));
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _selectedCategory = v;
                                // _prepareChartData(); // Removed, handled by reactivity
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Divider(color: Colors.white.withValues(alpha: 0.1)),
                SizedBox(height: 12.h),
                // Range Filter
                Row(
                  children: [
                    Icon(Icons.date_range, color: Colors.white70, size: 20.sp),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedRange,
                          dropdownColor: const Color(0xFF16213E),
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white,
                          ),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                          ),
                          items: _rangeOptions.map((r) {
                            return DropdownMenuItem(value: r, child: Text(r));
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _selectedRange = v;
                                // _prepareChartData(); // Removed
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 32.h),

          // Chart Card
          Expanded(
            child: Container(
              padding: EdgeInsets.fromLTRB(16.w, 32.h, 24.w, 16.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05), // Dark Glass
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.show_chart,
                        color: const Color(0xFF00E5FF),
                        size: 20.sp,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        "Spending Over Time",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 32.h),
                  Expanded(
                    child: spots.isEmpty
                        ? Center(
                            child: Text(
                              "Not enough data",
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 14.sp,
                              ),
                            ),
                          )
                        : LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: maxY / 5,
                                getDrawingHorizontalLine: (value) => FlLine(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  strokeWidth: 1,
                                ),
                              ),
                              titlesData: FlTitlesData(
                                show: true,
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    interval: 1,
                                    getTitlesWidget: (val, meta) {
                                      final idx = val.toInt();
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          top: 8.0,
                                        ),
                                        child: Text(
                                          _getMonthLabel(idx),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.5,
                                            ),
                                            fontSize: 10.sp,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    interval: maxY / 5,
                                    getTitlesWidget: (val, meta) {
                                      return Text(
                                        "${(val / 1000).toStringAsFixed(1)}k",
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.5,
                                          ),
                                          fontSize: 10.sp,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              minX: 0,
                              maxX: spots.length > 1
                                  ? (spots.length - 1).toDouble()
                                  : 1,
                              minY: 0,
                              maxY: maxY,
                              lineBarsData: [
                                LineChartBarData(
                                  spots: spots,
                                  isCurved: true,
                                  color: const Color(0xFF00E5FF),
                                  barWidth: 3,
                                  isStrokeCapRound: true,
                                  dotData: const FlDotData(show: true),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(
                                          0xFF00E5FF,
                                        ).withValues(alpha: 0.2),
                                        const Color(
                                          0xFF00E5FF,
                                        ).withValues(alpha: 0.0),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 30.h),
        ],
      ),
    );
  }
}
