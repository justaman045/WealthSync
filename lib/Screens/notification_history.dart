import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:money_control/Services/error_handler.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Utils/responsive.dart';

class NotificationHistoryScreen extends StatelessWidget {
  const NotificationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Notifications"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 18.sp,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: isDark ? Colors.white : Colors.black),
            onPressed: () => _confirmClearAll(context, user?.email),
          ),
        ],
      ),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark ? AppColors.darkGradient : AppColors.lightGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: user == null
              ? const Center(child: Text("Not logged in"))
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.email)
                      .collection('notifications')
                      .orderBy('date', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00E5FF),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_off_outlined,
                              size: 64.sp,
                              color: isDark ? Colors.white24 : AppColors.lightTextSecondary.withValues(alpha: 0.4),
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              "No notifications yet",
                              style: TextStyle(
                                color: isDark ? Colors.white54 : AppColors.lightTextSecondary,
                                fontSize: 16.sp,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final docs = snapshot.data!.docs;

                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
                        child: ListView.builder(
                            padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 10.h,
                      ),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        return _NotificationTile(
                          title: data['title'] ?? 'Notification',
                          body: data['body'] ?? '',
                          date:
                              (data['date'] as Timestamp?)?.toDate() ??
                              DateTime.now(),
                          type: data['type'] ?? 'info',
                          isRead: data['read'] ?? false,
                        );
                      },
                          ),
                        ),
                      );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context, String? email) async {
    if (email == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        title: Text(
          "Clear History?",
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Text(
          "This will delete all your notification history.",
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Clear",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final batch = FirebaseFirestore.instance.batch();
      final snapshots = await FirebaseFirestore.instance
          .collection('users')
          .doc(email)
          .collection('notifications')
          .get();

      for (var doc in snapshots.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      ErrorHandler.showSuccess("History cleared");
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final String title;
  final String body;
  final DateTime date;
  final String type;
  final bool isRead;

  const _NotificationTile({
    required this.title,
    required this.body,
    required this.date,
    required this.type,
    required this.isRead,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    IconData icon;
    Color color;

    switch (type) {
      case 'budget_alert':
        icon = Icons.warning_amber_rounded;
        color = const Color(0xFFFF2975);
        break;
      case 'reminder':
        icon = Icons.alarm_on_rounded;
        color = const Color(0xFF00E5FF);
        break;
      default:
        icon = Icons.info_outline_rounded;
        color = const Color(0xFF6C63FF);
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15.sp,
                        ),
                      ),
                    ),
                    Text(
                      _formatDate(date),
                      style: TextStyle(color: isDark ? Colors.white38 : AppColors.lightTextSecondary, fontSize: 11.sp),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  body,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                    fontSize: 13.sp,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);

    if (diff.inDays == 0) {
      return DateFormat('h:mm a').format(d);
    } else if (diff.inDays < 7) {
      return DateFormat('E, h:mm a').format(d);
    } else {
      return DateFormat('MMM d').format(d);
    }
  }
}
