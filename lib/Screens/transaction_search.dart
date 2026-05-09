import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Animation

import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Components/methods.dart';
import 'package:money_control/Screens/transaction_details.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Components/empty_state.dart'; // Empty State
import 'package:money_control/Components/colors.dart';

class TransactionSearchPage extends StatefulWidget {
  const TransactionSearchPage({super.key});

  @override
  State<TransactionSearchPage> createState() => _TransactionSearchPageState();
}

class _TransactionSearchPageState extends State<TransactionSearchPage> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  List<TransactionModel> results = [];
  bool searching = false;
  bool hasSearched = false;

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _performSearch(query));
  }

  /// Search Firestore for matching transactions
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        results = [];
        hasSearched = false;
      });
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!mounted) return;
    setState(() {
      searching = true;
      hasSearched = true;
    });

    try {
      final snap = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.email)
          .collection("transactions")
          .orderBy("date", descending: true)
          .get();

      final List<TransactionModel> all = snap.docs
          .map((d) => TransactionModel.fromMap(d.id, d.data()))
          .toList();

      final q = query.toLowerCase();

      final matched = all.where((tx) {
        return (tx.recipientName.toLowerCase().contains(q)) ||
            (tx.category?.toLowerCase().contains(q) ?? false) ||
            tx.amount.toString().contains(q) ||
            (tx.note?.toLowerCase().contains(q) ?? false);
      }).toList();

      if (!mounted) return;
      setState(() => results = matched);
    } catch (e) {
      debugPrint("Search error: $e");
    }

    if (!mounted) return;
    setState(() => searching = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : AppColors.lightTextPrimary),
        title: Text(
          "Search Transactions",
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20.sp,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark ? AppColors.darkGradient : AppColors.lightGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: 100.h), // Spacer for AppBar
            // 🔍 SEARCH FIELD
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Hero(
                tag: 'search_bar',
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF00E5FF,
                          ).withValues(alpha: 0.1), // Neon Cyan Glow
                          blurRadius: 20,
                          spreadRadius: -5,
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _search,
                      onChanged: _onSearchChanged,
                      style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary, fontSize: 15.sp),
                      cursorColor: const Color(0xFF00E5FF),
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.search,
                          color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                        ),
                        hintText: "Search by name, amount, category...",
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : AppColors.lightTextTertiary,
                          fontSize: 14.sp,
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(
                          alpha: 0.08,
                        ) : Colors.black.withValues(alpha: 0.056), // Glass
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 16.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20.r),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20.r),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lightBorder.withValues(alpha: 0.1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20.r),
                          borderSide: BorderSide(
                            color: const Color(
                              0xFF00E5FF,
                            ).withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0),

            if (searching)
              Padding(
                padding: const EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  color: const Color(0xFF00E5FF),
                ),
              ),

            // 📝 RESULTS LIST
            Expanded(
              child: results.isEmpty
                  ? (hasSearched && !searching
                        ? Center(
                            child: EmptyStateWidget(
                              title: "No Results Found",
                              subtitle: "Try adjusting your search terms",
                              icon: Icons.search_off_rounded,
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.manage_search_rounded,
                                  size: 80.sp,
                                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.07),
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  "Search your transactions",
                                  style: TextStyle(
                                    color: isDark ? Colors.white.withValues(alpha: 0.3) : AppColors.lightTextTertiary,
                                    fontSize: 16.sp,
                                  ),
                                ),
                              ],
                            ).animate().fadeIn(delay: 200.ms),
                          ))
                  : ListView.builder(
                      padding: EdgeInsets.only(top: 16.h, bottom: 30.h),
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final tx = results[i];
                        final isIncome =
                            tx.recipientId ==
                            FirebaseAuth.instance.currentUser?.uid;

                        return Container(
                              margin: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 6.h,
                              ),
                              padding: EdgeInsets.all(16.w),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(
                                  alpha: 0.05,
                                ) : Colors.black.withValues(alpha: 0.035),
                                borderRadius: BorderRadius.circular(20.r),
                                border: Border.all(
                                  color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.lightBorder.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Avatar
                                  Container(
                                    padding: EdgeInsets.all(10.w),
                                    decoration: BoxDecoration(
                                      color: isIncome
                                          ? const Color(
                                              0xFF00E676,
                                            ).withValues(alpha: 0.2)
                                          : const Color(
                                              0xFFFF1744,
                                            ).withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isIncome
                                          ? Icons.arrow_downward
                                          : Icons.arrow_upward,
                                      color: isIncome
                                          ? const Color(0xFF00E676)
                                          : const Color(0xFFFF1744),
                                      size: 20.sp,
                                    ),
                                  ),
                                  SizedBox(width: 16.w),
                                  // Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tx.recipientName,
                                          style: TextStyle(
                                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15.sp,
                                          ),
                                        ),
                                        SizedBox(height: 4.h),
                                        Text(
                                          tx.category ?? "Uncategorized",
                                          style: TextStyle(
                                            color: isDark ? Colors.white54 : AppColors.lightTextSecondary,
                                            fontSize: 12.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Amount
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        "${CurrencyController.to.currencySymbol.value}${tx.amount.toStringAsFixed(0)}",
                                        style: TextStyle(
                                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15.sp,
                                        ),
                                      ),
                                      SizedBox(height: 4.h),
                                      Text(
                                        _formatDate(tx.date),
                                        style: TextStyle(
                                          color: isDark ? Colors.white38 : AppColors.lightTextTertiary,
                                          fontSize: 11.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                            .animate(delay: (i * 50).ms)
                            .fadeIn(duration: 300.ms)
                            .slideY(begin: 0.1, end: 0, curve: Curves.easeOut)
                            .onTap(() {
                              // View Details
                              Get.to(
                                () => TransactionResultScreen(
                                  type: getTransactionTypeFromStatus(tx.status),
                                  transaction: tx,
                                ),
                                preventDuplicates: false,
                              );
                            });
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}";
  }
}

extension WidgetExt on Widget {
  Widget onTap(VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: this);
  }
}
