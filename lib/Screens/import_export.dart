import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:money_control/Components/bottom_nav_bar.dart';
import 'package:money_control/Components/pro_lock_widget.dart';
import 'package:money_control/Controllers/subscription_controller.dart';

class ExportImportPage extends StatefulWidget {
  const ExportImportPage({super.key});

  @override
  State<ExportImportPage> createState() => _ExportImportPageState();
}

class _ExportImportPageState extends State<ExportImportPage> {
  bool loadingExport = false;
  bool loadingImport = false;
  String? message;
  bool isError = false;

  Future<void> _exportCSV() async {
    setState(() {
      loadingExport = true;
      message = null;
      isError = false;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack("Error", "User not logged in", true);
      setState(() => loadingExport = false);
      return;
    }

    try {
      // Fetch transactions
      final txSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email)
          .collection('transactions')
          .get();

      // Fetch budgets
      final budgetSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email)
          .collection('budgets')
          .get();

      // Prepare transaction CSV data
      List<List<dynamic>> txCsvData = [
        [
          'id',
          'senderId',
          'recipientId',
          'recipientName',
          'amount',
          'currency',
          'tax',
          'note',
          'category',
          'date',
          'attachmentUrl',
          'status',
        ],
      ];

      for (var doc in txSnap.docs) {
        final tx = doc.data();
        txCsvData.add([
          doc.id,
          tx['senderId'] ?? '',
          tx['recipientId'] ?? '',
          tx['recipientName'] ?? '',
          tx['amount'] ?? 0,
          tx['currency'] ?? 'USD',
          tx['tax'] ?? 0,
          tx['note'] ?? '',
          tx['category'] ?? 'Uncategorized',
          tx['date'] is Timestamp
              ? (tx['date'] as Timestamp).toDate().toIso8601String()
              : tx['date'].toString(),
          tx['attachmentUrl'] ?? '',
          tx['status'] ?? 'success',
        ]);
      }

      String txCsv = const ListToCsvConverter().convert(txCsvData);

      // Prepare budget CSV data
      List<List<dynamic>> budgetCsvData = [
        ['categoryId', 'amount'],
      ];
      for (var doc in budgetSnap.docs) {
        final data = doc.data();
        budgetCsvData.add([doc.id, data['amount']]);
      }
      String budgetCsv = const ListToCsvConverter().convert(budgetCsvData);

      // Save files to device (Android/iOS Documents)
      final directory = await getApplicationDocumentsDirectory();
      // On Android this is internal app storage. For public export, might need external storage or share.
      // For now keeping logic same but improving UI.

      final txFile = File('${directory.path}/transactions_export.csv');
      await txFile.writeAsString(txCsv);

      final budgetFile = File('${directory.path}/budgets_export.csv');
      await budgetFile.writeAsString(budgetCsv);

      setState(() => loadingExport = false);
      _showSnack("Success", "Files exported to: ${directory.path}", false);
    } catch (e) {
      setState(() => loadingExport = false);
      _showSnack("Export Failed", e.toString(), true);
    }
  }

  Future<void> _importCSV() async {
    setState(() {
      loadingImport = true;
      message = null;
      isError = false;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack("Error", "User not logged in", true);
      setState(() => loadingImport = false);
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result == null || result.files.isEmpty) {
        setState(() => loadingImport = false);
        return;
      }

      final file = File(result.files.single.path!);
      final content = await file.readAsString();

      List<List<dynamic>> rows = const CsvToListConverter().convert(content);

      int count = 0;
      // Check header
      if (rows.isNotEmpty && rows[0].contains('senderId')) {
        // Transactions
        for (int i = 1; i < rows.length; i++) {
          var row = rows[i];
          if (row.isEmpty) continue;

          String id = row[0].toString();
          if (id.isEmpty) {
            id = FirebaseFirestore.instance.collection('users').doc().id;
          }

          String senderId = row[1].toString();
          String recipientId = row[2].toString();
          String recipientName = row[3].toString();
          double amount = double.tryParse(row[4].toString()) ?? 0;
          String currency = row[5].toString();
          double tax = double.tryParse(row[6].toString()) ?? 0;
          String? note = row[7].toString();
          String? category = row[8].toString();
          DateTime date =
              DateTime.tryParse(row[9].toString()) ?? DateTime.now();
          String? attachmentUrl = row[10].toString();
          String status = row.length > 11 ? row[11].toString() : 'success';

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.email)
              .collection('transactions')
              .doc(id)
              .set({
                'senderId': senderId,
                'recipientId': recipientId,
                'recipientName': recipientName,
                'amount': amount,
                'currency': currency,
                'tax': tax,
                'note': note,
                'category': category,
                'date': Timestamp.fromDate(date),
                'attachmentUrl': attachmentUrl,
                'status': status,
                'importedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
          count++;
        }
        _showSnack("Success", "Imported $count transactions.", false);
      } else if (rows.isNotEmpty && rows[0].contains('categoryId')) {
        // Budgets
        for (int i = 1; i < rows.length; i++) {
          var row = rows[i];
          if (row.isEmpty) continue;
          String categoryId = row[0].toString();
          double amount = double.tryParse(row[1].toString()) ?? 0;
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.email)
              .collection('budgets')
              .doc(categoryId)
              .set({'amount': amount}, SetOptions(merge: true));
          count++;
        }
        _showSnack("Success", "Imported $count budgets.", false);
      } else {
        _showSnack("Error", "Unknown CSV format", true);
      }

      setState(() => loadingImport = false);
    } catch (e) {
      setState(() => loadingImport = false);
      _showSnack("Import Failed", e.toString(), true);
    }
  }

  void _showSnack(String title, String msg, bool isError) {
    Get.snackbar(
      title,
      msg,
      backgroundColor: isError
          ? Colors.redAccent.withValues(alpha: 0.1)
          : Colors.greenAccent.withValues(alpha: 0.1),
      colorText: isError ? Colors.redAccent : Colors.green,
      snackPosition: SnackPosition.BOTTOM,
      barBlur: 20,
      margin: EdgeInsets.all(16.w),
      borderRadius: 16.r,
      borderWidth: 1,
      borderColor: isError
          ? Colors.redAccent.withValues(alpha: 0.3)
          : Colors.green.withValues(alpha: 0.3),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gradientColors = isDark
        ? [
            const Color(0xFF1A1A2E),
            const Color(0xFF16213E).withValues(alpha: 0.95),
          ]
        : [const Color(0xFFF5F7FA), const Color(0xFFC3CFE2)];

    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

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
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text(
            "Data Management",
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 18.sp,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: textColor, size: 20.sp),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        bottomNavigationBar: const BottomNavBar(currentIndex: 3),
        body: Obx(() {
          final SubscriptionController subscriptionController = Get.find();
          if (!subscriptionController.isPro) {
            return const ProLockWidget(
              title: "Data Export",
              description:
                  "Export your transaction history and budgets with Pro.",
            );
          }

          return Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Export or Import your financial data securely.",
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.7),
                    fontSize: 14.sp,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 30.h),

                // Export Card
                _buildActionCard(
                  isDark,
                  "Export Data",
                  "Save transactions & budgets as CSV files.",
                  Icons.cloud_download_outlined,
                  Colors.blueAccent,
                  loadingExport,
                  _exportCSV,
                ),

                SizedBox(height: 20.h),

                // Import Card
                _buildActionCard(
                  isDark,
                  "Import Data",
                  "Restore from CSV backup files.",
                  Icons.cloud_upload_outlined,
                  Colors.purpleAccent,
                  loadingImport,
                  _importCSV,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActionCard(
    bool isDark,
    String title,
    String subtitle,
    IconData icon,
    Color accentColor,
    bool isLoading,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.6),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(20.r),
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: isLoading
                      ? SizedBox(
                          width: 28.sp,
                          height: 28.sp,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: accentColor,
                          ),
                        )
                      : Icon(icon, color: accentColor, size: 28.sp),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14.sp,
                  color: isDark ? Colors.white30 : Colors.black26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
