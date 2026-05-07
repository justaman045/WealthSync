import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Services/sms_service.dart';
import 'package:get/get.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/subscription_controller.dart';
import 'package:money_control/Components/pro_lock_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:money_control/Services/error_handler.dart';
import 'package:money_control/Screens/auto_tag_rules_screen.dart';
import 'package:permission_handler/permission_handler.dart';

class SmsImportScreen extends StatefulWidget {
  const SmsImportScreen({super.key});

  @override
  State<SmsImportScreen> createState() => _SmsImportScreenState();
}

class _SmsImportScreenState extends State<SmsImportScreen> {
  final SmsService _smsService = SmsService();
  List<SmsTransaction> _transactions = [];
  final Set<int> _selectedIndices = {};
  bool _loading = false;
  bool _scanned = false;

  @override
  void initState() {
    super.initState();
    _scanSms();
  }

  Future<void> _scanSms() async {
    setState(() {
      _loading = true;
    });

    try {
      final results = await _smsService.scanMessages(limit: 100);
      if (results == null) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('SMS Permission Required'),
            content: const Text(
              'SMS permission was previously denied. '
              'Please enable "SMS" permission in app settings to import transactions.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _transactions = results;
          _scanned = true;
          _selectedIndices.addAll(List.generate(results.length, (i) => i));
        });
      }
      if (results.isNotEmpty || _scanned) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('sms_auto_import_enabled', true);
        prefs.getInt('last_sms_scan_ms') == null
            ? await prefs.setInt(
                'last_sms_scan_ms',
                DateTime.now().millisecondsSinceEpoch,
              )
            : null;
      }
    } finally {
      if (mounted && _transactions.isEmpty) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _importSelected() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    setState(() => _loading = true);

    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(user.email)
        .collection('transactions');

    final selectedList = _selectedIndices.toList();
    const chunkSize = 499;
    int count = 0;

    for (int start = 0; start < selectedList.length; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, selectedList.length);
      final chunk = selectedList.sublist(start, end);
      final batch = FirebaseFirestore.instance.batch();

      for (int i in chunk) {
        final smsTx = _transactions[i];
        final docRef = collection.doc();
        final isDebit = smsTx.isDebit;

        final tx = TransactionModel(
          id: docRef.id,
          senderId: isDebit ? user.uid : 'External',
          recipientId: isDebit ? 'External' : user.uid,
          recipientName: isDebit ? smsTx.merchant : 'Self',
          amount: smsTx.amount,
          currency: 'INR',
          tax: 0,
          date: smsTx.date,
          note: "Imported from SMS: ${smsTx.body}",
          category: smsTx.category,
          status: 'success',
          createdAt: Timestamp.now(),
        );

        batch.set(docRef, tx.toMap());
        count++;
      }

      await batch.commit();
    }

    ErrorHandler.showSuccess("Imported $count transactions!");
    if (mounted) {
      setState(() => _loading = false);
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SubscriptionController subscriptionController = Get.find();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E), // Premium Dark
      appBar: AppBar(
        title: const Text(
          "Import from SMS",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.rule, color: Colors.white),
            tooltip: "Auto-tag rules",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AutoTagRulesScreen())),
          ),
          Obx(() {
            if (subscriptionController.isPro && _transactions.isNotEmpty) {
              return TextButton(
                onPressed: () {
                  setState(() {
                    if (_selectedIndices.length == _transactions.length) {
                      _selectedIndices.clear();
                    } else {
                      _selectedIndices.addAll(
                        List.generate(_transactions.length, (i) => i),
                      );
                    }
                  });
                },
                child: Text(
                  _selectedIndices.length == _transactions.length
                      ? "Deselect All"
                      : "Select All",
                  style: TextStyle(color: Colors.cyan),
                ),
              );
            }
            return SizedBox.shrink();
          }),
        ],
      ),
      body: Obx(() {
        if (!subscriptionController.isPro) {
          return const ProLockWidget(
            title: "SMS Tracking",
            description: "Automatically track expenses from bank SMS with Pro.",
          );
        }

        return _loading && !_scanned
            ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
            : _transactions.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sms_failed, size: 60, color: Colors.white24),
                    SizedBox(height: 16.h),
                    Text(
                      "No bank transactions found.",
                      style: TextStyle(color: Colors.white54),
                    ),
                    SizedBox(height: 16.h),
                    TextButton(onPressed: _scanSms, child: Text("Retry")),
                  ],
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Text(
                      "Found ${_transactions.length} transactions",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final tx = _transactions[index];
                        final isSelected = _selectedIndices.contains(index);
                        return Container(
                          margin: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.cyan
                                  : Colors.transparent,
                            ),
                          ),
                          child: CheckboxListTile(
                            value: isSelected,
                            activeColor: Colors.cyan,
                            checkColor: Colors.black,
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    tx.merchant,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  "${tx.isDebit ? '-' : '+'} ${CurrencyController.to.currencySymbol.value}${tx.amount.toStringAsFixed(0)}",
                                  style: TextStyle(
                                    color: tx.isDebit
                                        ? Colors.redAccent
                                        : Colors.greenAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat(
                                    'dd MMM yyyy, hh:mm a',
                                  ).format(tx.date),
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12.sp,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  tx.body,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white30,
                                    fontSize: 10.sp,
                                  ),
                                ),
                              ],
                            ),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedIndices.add(index);
                                } else {
                                  _selectedIndices.remove(index);
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Color(0xFF1A1A2E),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, -5),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: ElevatedButton(
                        onPressed:
                            _selectedIndices.isEmpty || (_loading && _scanned)
                            ? null
                            : _importSelected,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyan,
                          foregroundColor: Colors.black,
                          minimumSize: Size(double.infinity, 50.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: _loading && _scanned
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : Text(
                                "Import ${_selectedIndices.length} Transactions",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.sp,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              );
      }),
    );
  }
}
