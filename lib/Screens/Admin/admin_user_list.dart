import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Services/error_handler.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Utils/responsive.dart';

class AdminUserListScreen extends StatefulWidget {
  const AdminUserListScreen({super.key});

  @override
  State<AdminUserListScreen> createState() => _AdminUserListScreenState();
}

class _AdminUserListScreenState extends State<AdminUserListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            "Manage Users",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16.w),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Search by email...",
                  hintStyle: TextStyle(color: Colors.white30),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('users')
                    .orderBy('email') // Ensure indexed
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.cyanAccent,
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        "No users found.",
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  }

                  var docs = snapshot.data!.docs;

                  // Client-side filtering because Firestore search is limited
                  if (_searchQuery.isNotEmpty) {
                    docs = docs.where((doc) {
                      return doc.id.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      );
                    }).toList();
                  }

                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
                      child: ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final email = docs[index].id;
                      final isPro =
                          data['subscriptionStatus'] == 'pro' ||
                          data['isPro'] == true;
                      final expiryTimestamp = data['expiryDate'] as Timestamp?;

                      return _buildUserCard(email, isPro, expiryTimestamp);
                    },
                        ),
                      ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(String email, bool isPro, Timestamp? expiry) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: GlassContainer(
        padding: EdgeInsets.all(16.w),
        borderRadius: BorderRadius.circular(16.r),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: isPro
                    ? Colors.greenAccent.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPro ? Icons.verified_user : Icons.person_outline,
                color: isPro ? Colors.greenAccent : Colors.white54,
                size: 24.sp,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    isPro
                        ? "Exp: ${expiry != null ? DateFormat('MMM dd, yyyy').format(expiry.toDate()) : 'Lifetime/Unknown'}"
                        : "Free Plan",
                    style: TextStyle(
                      color: isPro ? Colors.greenAccent : Colors.white54,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_calendar, color: Colors.cyanAccent),
              onPressed: () => _openEditDialog(email, isPro, expiry),
            ),
          ],
        ),
      ),
    );
  }

  void _openEditDialog(String email, bool isPro, Timestamp? currentExpiry) {
    DateTime selectedDate = currentExpiry != null
        ? currentExpiry.toDate()
        : DateTime.now();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
            title: Text(
              "Manage Subscription",
              style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary, fontSize: 18.sp),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  email,
                  style: TextStyle(color: Colors.white70, fontSize: 14.sp),
                ),
                SizedBox(height: 20.h),
                Row(
                  children: [
                    Text("Pro Status:", style: TextStyle(color: Colors.white)),
                    const Spacer(),
                    Switch(
                      value: isPro,
                      activeThumbColor: Colors.greenAccent,
                      onChanged: (val) {
                        setState(() => isPro = val);
                      },
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                if (isPro) ...[
                  Text(
                    "Expiry Date:",
                    style: TextStyle(color: Colors.white70, fontSize: 14.sp),
                  ),
                  SizedBox(height: 8.h),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        builder: (context, child) {
                          final isDark = Theme.of(context).brightness == Brightness.dark;
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: ColorScheme.dark(
                                primary: Colors.cyanAccent,
                                onPrimary: Colors.black,
                                surface: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                                onSurface: isDark ? Colors.white : AppColors.lightTextPrimary,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 12.h,
                        horizontal: 16.w,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('MMM dd, yyyy').format(selectedDate),
                            style: TextStyle(color: Colors.white),
                          ),
                          Icon(
                            Icons.calendar_today,
                            color: Colors.cyanAccent,
                            size: 16.sp,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _firestore.collection('users').doc(email).set({
                    'subscriptionStatus': isPro ? 'pro' : 'free',
                    'isPro': isPro,
                    if (isPro) 'expiryDate': Timestamp.fromDate(selectedDate),
                    if (!isPro) 'expiryDate': FieldValue.delete(),
                  }, SetOptions(merge: true));

                  ErrorHandler.showSuccess("Subscription updated successfully!");
                  if (context.mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                ),
                child: const Text(
                  "Save Changes",
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
