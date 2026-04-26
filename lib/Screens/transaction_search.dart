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

class TransactionSearchPage extends StatefulWidget {
  const TransactionSearchPage({super.key});

  @override
  State<TransactionSearchPage> createState() => _TransactionSearchPageState();
}

class _TransactionSearchPageState extends State<TransactionSearchPage> {
  final TextEditingController _search = TextEditingController();
  List<TransactionModel> results = [];
  bool searching = false;
  bool hasSearched = false; // Track if a search has been performed

  /// Search Firestore for matching transactions
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        results = [];
        hasSearched = false;
      });
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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

      setState(() => results = matched);
    } catch (e) {
      debugPrint("Search error: $e");
    }

    setState(() => searching = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Search Transactions",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20.sp,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1A1A2E), // Midnight Void Top
              const Color(
                0xFF16213E,
              ).withValues(alpha: 0.95), // Deep Blue Bottom
            ],
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
                      onChanged: _performSearch,
                      style: TextStyle(color: Colors.white, fontSize: 15.sp),
                      cursorColor: const Color(0xFF00E5FF),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white70,
                        ),
                        hintText: "Search by name, amount, category...",
                        hintStyle: TextStyle(
                          color: Colors.white38,
                          fontSize: 14.sp,
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(
                          alpha: 0.08,
                        ), // Glass
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
                            color: Colors.white.withValues(alpha: 0.1),
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
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  "Search your transactions",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.3),
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
                                color: Colors.white.withValues(
                                  alpha: 0.05,
                                ), // Dark Glass
                                borderRadius: BorderRadius.circular(20.r),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
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
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15.sp,
                                          ),
                                        ),
                                        SizedBox(height: 4.h),
                                        Text(
                                          tx.category ?? "Uncategorized",
                                          style: TextStyle(
                                            color: Colors.white54,
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
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15.sp,
                                        ),
                                      ),
                                      SizedBox(height: 4.h),
                                      Text(
                                        _formatDate(tx.date),
                                        style: TextStyle(
                                          color: Colors.white38,
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
