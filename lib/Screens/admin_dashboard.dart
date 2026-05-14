import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:money_control/Controllers/subscription_controller.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Services/error_handler.dart';
import 'package:money_control/Components/colors.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!SubscriptionController.to.isAdmin.value) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.lock_outline, size: 64, color: Colors.redAccent),
              SizedBox(height: 16),
              Text("Access Denied", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F2027), const Color(0xFF203A43), const Color(0xFF2C5364)]
              : AppColors.lightGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            "Admin Dashboard",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('users')
              .where('subscriptionStatus', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.cyanAccent),
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
                      Icons.check_circle_outline,
                      size: 80.sp,
                      color: Colors.white24,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      "No Pending Requests",
                      style: TextStyle(fontSize: 18.sp, color: Colors.white54),
                    ),
                  ],
                ),
              );
            }

            final docs = snapshot.data!.docs;

            return ListView.builder(
              padding: EdgeInsets.all(16.w),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final email = docs[index].id;
                final date = data['lastUpgradeRequest'] as Timestamp?;

                return Container(
                  margin: EdgeInsets.only(bottom: 16.h),
                  child: GlassContainer(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    borderRadius: BorderRadius.circular(16.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(10.w),
                              decoration: BoxDecoration(
                                color: Colors.cyan.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person,
                                color: Colors.cyanAccent,
                                size: 24.sp,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    email,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16.sp,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    date != null
                                        ? DateFormat(
                                            'MMM dd, hh:mm a',
                                          ).format(date.toDate())
                                        : "Unknown Date",
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12.sp,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  if (data.containsKey('transactionId'))
                                    Padding(
                                      padding: EdgeInsets.only(top: 4.h),
                                      child: SelectableText(
                                        "Txn ID: ${data['transactionId']}",
                                        style: TextStyle(
                                          color: Colors.cyanAccent,
                                          fontSize: 13.sp,
                                          fontFamily: 'Courier',
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  SubscriptionController.to.rejectUpgrade(
                                    email,
                                  );
                                  ErrorHandler.showError("User $email request rejected.", title: "Rejected");
                                },
                                icon: Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Colors.redAccent,
                                ),
                                label: Text(
                                  "Reject",
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.redAccent),
                                  padding: EdgeInsets.symmetric(vertical: 12.h),
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  SubscriptionController.to.approveUpgrade(
                                    email,
                                  );
                                  ErrorHandler.showSuccess("User $email is now Pro!");
                                },
                                icon: Icon(
                                  Icons.check,
                                  size: 18,
                                  color: Colors.black,
                                ),
                                label: Text(
                                  "Approve",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.cyanAccent,
                                  padding: EdgeInsets.symmetric(vertical: 12.h),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.redAccent,
          child: const Icon(Icons.bug_report, color: Colors.white),
          onPressed: () => _showDebugDialog(context),
        ),
      ),
    );
  }

  void _showDebugDialog(BuildContext context) {
    final TextEditingController emailController = TextEditingController();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        title: Text(
          "Debug: Force Expiry",
          style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Enter email to force expiry date to yesterday.",
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: emailController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "User Email",
                hintStyle: TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              emailController.dispose();
              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.isNotEmpty) {
                await _firestore
                    .collection('users')
                    .doc(emailController.text.trim())
                    .set({
                      'expiryDate': DateTime.now().subtract(
                        const Duration(days: 1),
                      ),
                      'subscriptionStatus': 'pro', // Ensure they are pro first
                    }, SetOptions(merge: true));

                ErrorHandler.showSuccess("Expiry set to yesterday! Restart app to test.", title: "Test Mode");
                if (context.mounted) Navigator.pop(context);
              }
              emailController.dispose();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Expire Now"),
          ),
        ],
      ),
    );
  }
}
