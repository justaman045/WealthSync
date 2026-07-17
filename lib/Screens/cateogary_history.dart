import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Components/tx_tile.dart';
import 'package:money_control/Screens/transaction_details.dart';

class CategoryTransactionsScreen extends StatefulWidget {
  final String categoryName;
  final DateTime? startDate;
  final DateTime? endDate;
  const CategoryTransactionsScreen({
    super.key,
    required this.categoryName,
    this.startDate,
    this.endDate,
  });

  @override
  State<CategoryTransactionsScreen> createState() =>
      _CategoryTransactionsScreenState();
}

class _CategoryTransactionsScreenState
    extends State<CategoryTransactionsScreen> {

  Stream<QuerySnapshot> _buildQuery(User user) {
    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(user.email)
        .collection('transactions')
        .where('category', isEqualTo: widget.categoryName)
        .orderBy('date', descending: true);

    return query.snapshots();
  }

  static String _formatDateRange(DateTime start, DateTime end) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (start.month == end.month && start.year == end.year) {
      return '${months[start.month - 1]} ${start.year}';
    }
    return '${months[start.month - 1]} ${start.year} – ${months[end.month - 1]} ${end.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text(
            "User not logged in",
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: RepaintBoundary(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(
                color: (isDark ? AppColors.darkBackground : AppColors.lightBackground).withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          widget.startDate != null && widget.endDate != null
              ? "${widget.categoryName}: ${_formatDateRange(widget.startDate!, widget.endDate!)}"
              : "Transactions: ${widget.categoryName}",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
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
        child: StreamBuilder<QuerySnapshot>(
          stream: _buildQuery(user),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text("Error: ${snapshot.error}"),
              );
            }

            final docs = snapshot.data!.docs;

            final now = DateTime.now();
            final startDate = widget.startDate ?? DateTime(now.year, now.month, 1);
            final endDate = widget.endDate ?? DateTime(now.year, now.month + 1, 0, 23, 59, 59);

            final filteredDocs = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final ts = data['date'] as Timestamp?;
              if (ts == null) return false;
              final d = ts.toDate();
              return (d.isAtSameMomentAs(startDate) || d.isAfter(startDate)) &&
                  (d.isAtSameMomentAs(endDate) || d.isBefore(endDate));
            }).toList();

            if (filteredDocs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 60.sp,
                      color: Colors.white24,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      "No transactions found.",
                      style: TextStyle(color: Colors.white38, fontSize: 16.sp),
                    ),
                  ],
                ),
              );
            }

            final txs = filteredDocs
                .map(
                  (doc) => TransactionModel.fromMap(
                    doc.id,
                    doc.data() as Map<String, dynamic>,
                  ),
                )
                .toList();

            return ListView.builder(
              padding: EdgeInsets.fromLTRB(16.w, 100.h, 16.w, 30.h),
              itemCount: txs.length,
              itemBuilder: (context, index) {
                final tx = txs[index];
                final received = tx.recipientId == user.uid;

                return GestureDetector(
                  onTap: () {
                    // Navigate to details
                    TransactionResultType type;
                    if (tx.status == 'failed') {
                      type = TransactionResultType.failed;
                    } else if (tx.status == 'pending' ||
                        tx.status == 'processing') {
                      type = TransactionResultType.inProgress;
                    } else {
                      type = TransactionResultType.success;
                    }

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TransactionResultScreen(
                          type: type,
                          transaction: tx,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    margin: EdgeInsets.only(bottom: 12.h),
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05), // Dark Glass
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: IgnorePointer(
                      // Ignore inner click to let this outer detector handle it for the whole card
                      child: TxTile(
                        tx: tx,
                        received: received,
                        textColor: Colors.white,
                        receivedColor: const Color(0xFF00E676), // Neon Green
                        sentColor: const Color(0xFFFF1744), // Neon Red
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
