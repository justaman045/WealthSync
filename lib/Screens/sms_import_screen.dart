import 'dart:convert';

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
import 'package:money_control/Components/colors.dart';

class SmsImportScreen extends StatefulWidget {
  const SmsImportScreen({super.key});

  @override
  State<SmsImportScreen> createState() => _SmsImportScreenState();
}

class _SmsImportScreenState extends State<SmsImportScreen> {
  final SmsService _smsService = SmsService();
  List<SmsTransaction> _transactions = [];
  final Set<int> _selectedIndices = {};
  Set<int> _importedIndices = {};
  bool _loading = false;
  bool _scanned = false;
  Set<String> _importedKeys = {};

  @override
  void initState() {
    super.initState();
    _loadImported();
    _scanSms();
  }

  Future<void> _loadImported() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('imported_sms_keys');
    if (raw != null) {
      final decoded = jsonDecode(raw);
      _importedKeys = decoded is List
          ? decoded.cast<String>().toSet()
          : <String>{};
    }
  }

  Future<void> _saveImported() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('imported_sms_keys', jsonEncode(_importedKeys.toList()));
  }

  /// Matches background_worker.dart dedup format: sender + epoch-minute + amount.
  String _smsDedupeKey(SmsTransaction tx) =>
      '${tx.sender}_${(tx.date.millisecondsSinceEpoch ~/ 60000)}_${tx.amount}';

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
          builder: (ctx) {
            final dlgIsDark = Theme.of(ctx).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: dlgIsDark ? AppColors.darkSurface : AppColors.lightSurface,
              title: Text('SMS Permission Required',
                style: TextStyle(color: dlgIsDark ? Colors.white : AppColors.lightTextPrimary)),
              content: Text(
                'SMS permission was previously denied. '
                'Please enable "SMS" permission in app settings to import transactions.',
                style: TextStyle(color: dlgIsDark ? Colors.white70 : AppColors.lightTextSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel',
                    style: TextStyle(color: dlgIsDark ? Colors.white70 : AppColors.lightTextSecondary)),
                ),
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await openAppSettings();
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            );
          },
        );
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
        return;
      }
      final db = FirebaseFirestore.instance;
      final user = FirebaseAuth.instance.currentUser;
      final firestoreKeys = <String>{};
      if (user?.email != null) {
        final dedupKeys = results.map(_smsDedupeKey).toList();
        for (int i = 0; i < dedupKeys.length; i += 30) {
          final chunk = dedupKeys.sublist(i, (i + 30).clamp(0, dedupKeys.length));
          final snap = await db
              .collection('users')
              .doc(user!.email)
              .collection('transactions')
              .where('smsDedupeKey', whereIn: chunk)
              .get();
          for (final doc in snap.docs) {
            firestoreKeys.add(doc['smsDedupeKey'] as String);
          }
        }
      }
      final allImported = {..._importedKeys, ...firestoreKeys};
      final importedIdx = <int>{};
      for (int i = 0; i < results.length; i++) {
        if (allImported.contains(_smsDedupeKey(results[i]))) {
          importedIdx.add(i);
        }
      }
      if (mounted) {
        setState(() {
          _transactions = results;
          _importedIndices = importedIdx;
          _scanned = true;
          _loading = false;
          _selectedIndices.addAll(
            List.generate(results.length, (i) => i)
                .where((i) => !importedIdx.contains(i)),
          );
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
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _importSelected() async {
    final selectedList = _selectedIndices.toList();
    final reimporting = selectedList.where((i) => _importedIndices.contains(i)).toList();

    if (reimporting.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final dlgIsDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: dlgIsDark ? AppColors.darkSurface : AppColors.lightSurface,
            title: Text('Re-import Transactions',
              style: TextStyle(color: dlgIsDark ? Colors.white : AppColors.lightTextPrimary)),
            content: Text(
              '${reimporting.length} transaction${reimporting.length == 1 ? '' : 's'} '
              'already imported. Create duplicates?',
              style: TextStyle(color: dlgIsDark ? Colors.white70 : AppColors.lightTextSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel',
                  style: TextStyle(color: dlgIsDark ? Colors.white70 : AppColors.lightTextSecondary)),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.cyan),
                child: const Text('Import Anyway'),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    setState(() => _loading = true);

    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(user.email)
        .collection('transactions');

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
          recipientName: isDebit
              ? smsTx.merchant
              : (smsTx.merchant != 'Unknown' && smsTx.merchant.isNotEmpty
                  ? smsTx.merchant
                  : (smsTx.sender.isNotEmpty ? smsTx.sender : 'Self')),
          amount: isDebit ? -smsTx.amount : smsTx.amount,
          currency: 'INR',
          tax: 0,
          date: smsTx.date,
          note: "Imported from SMS",
          category: smsTx.category,
          status: 'success',
          createdAt: Timestamp.now(),
        );

        batch.set(docRef, tx.toMap());
        batch.update(docRef, {'smsDedupeKey': _smsDedupeKey(smsTx)});
        count++;
      }

      await batch.commit();
    }

    for (final i in selectedList) {
      _importedKeys.add(_smsDedupeKey(_transactions[i]));
    }
    await _saveImported();

    ErrorHandler.showSuccess("Imported $count transactions!");
    if (mounted) {
      setState(() => _loading = false);
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SubscriptionController subscriptionController = Get.find();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          "Import from SMS",
          style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: isDark ? Colors.white : AppColors.lightTextPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.rule, color: isDark ? Colors.white : AppColors.lightTextPrimary),
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

        final freshCount = _transactions.length - _importedIndices.length;

        return _loading && !_scanned
            ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
            : _transactions.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.sms_failed,
                      size: 60,
                      color: isDark ? Colors.white24 : AppColors.lightTextSecondary.withValues(alpha: 0.4),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      "No bank transactions found.",
                      style: TextStyle(color: isDark ? Colors.white54 : AppColors.lightTextSecondary),
                    ),
                    SizedBox(height: 16.h),
                    TextButton(onPressed: _scanSms, child: Text("Scan Again")),
                  ],
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Text(
                      _importedIndices.length == _transactions.length
                          ? "All ${_transactions.length} transactions already imported"
                          : "Found $freshCount new of ${_transactions.length} transactions",
                      style: TextStyle(color: isDark ? Colors.white70 : AppColors.lightTextSecondary),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final tx = _transactions[index];
                        final isSelected = _selectedIndices.contains(index);
                        final isImported = _importedIndices.contains(index);
                        return Container(
                          margin: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: isImported
                                ? Colors.white.withValues(alpha: 0.02)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.cyan
                                  : isImported
                                      ? Colors.white10
                                      : Colors.transparent,
                            ),
                          ),
                          child: Opacity(
                            opacity: isImported ? 0.55 : 1.0,
                            child: CheckboxListTile(
                              value: isSelected,
                              activeColor: Colors.cyan,
                              checkColor: Colors.black,
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            tx.merchant,
                                            style: TextStyle(
                                              color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isImported) ...[
                                          SizedBox(width: 8.w),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                            decoration: BoxDecoration(
                                              color: Colors.cyan.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4.r),
                                            ),
                                            child: Text(
                                              "Imported",
                                              style: TextStyle(
                                                color: Colors.cyan,
                                                fontSize: 9.sp,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
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
                                      color: isDark ? Colors.white54 : AppColors.lightTextSecondary,
                                      fontSize: 12.sp,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    tx.body,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isDark ? Colors.white30 : AppColors.lightTextSecondary.withValues(alpha: 0.6),
                                      fontSize: 10.sp,
                                    ),
                                  ),
                                ],
                              ),
                              onChanged: (val) {
                                if (isImported && val == true) {
                                  showDialog<void>(
                                    context: context,
                                    builder: (ctx) {
                                      final dlgIsDark = Theme.of(ctx).brightness == Brightness.dark;
                                      return AlertDialog(
                                        backgroundColor: dlgIsDark ? AppColors.darkSurface : AppColors.lightSurface,
                                        title: Text('Already Imported',
                                          style: TextStyle(color: dlgIsDark ? Colors.white : AppColors.lightTextPrimary)),
                                        content: Text(
                                          'This transaction was already imported. Create a duplicate?',
                                          style: TextStyle(color: dlgIsDark ? Colors.white70 : AppColors.lightTextSecondary),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: Text('Cancel',
                                              style: TextStyle(color: dlgIsDark ? Colors.white70 : AppColors.lightTextSecondary)),
                                          ),
                                          FilledButton(
                                            onPressed: () {
                                              Navigator.pop(ctx);
                                              setState(() {
                                                _selectedIndices.add(index);
                                              });
                                            },
                                            style: FilledButton.styleFrom(backgroundColor: Colors.cyan),
                                            child: const Text('Import Anyway'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                } else {
                                  setState(() {
                                    if (val == true) {
                                      _selectedIndices.add(index);
                                    } else {
                                      _selectedIndices.remove(index);
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
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
