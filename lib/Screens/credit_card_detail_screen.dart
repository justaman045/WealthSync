import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Services/wealth_service.dart';

class CreditCardDetailScreen extends StatefulWidget {
  const CreditCardDetailScreen({super.key});

  @override
  State<CreditCardDetailScreen> createState() => _CreditCardDetailScreenState();
}

class _CreditCardDetailScreenState extends State<CreditCardDetailScreen> {
  CollectionReference get _col {
    final email = FirebaseAuth.instance.currentUser!.email!;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .collection('credit_cards');
  }

  bool _saving = false;

  Future<void> _add() async {
    final nameCtrl = TextEditingController();
    final limitCtrl = TextEditingController();
    final outstandingCtrl = TextEditingController();
    final dueDateCtrl = TextEditingController();
    DateTime? dueDate;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddSheet(
        title: "Add Credit Card",
        fields: [
          _FieldDef("Card / Bank name", nameCtrl, TextInputType.text),
          _FieldDef("Credit limit", limitCtrl, TextInputType.number),
          _FieldDef("Outstanding balance", outstandingCtrl, TextInputType.number),
          _FieldDef("Payment due date (optional)", dueDateCtrl, TextInputType.datetime,
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 60)),
                );
                if (picked != null) {
                  dueDate = picked;
                  dueDateCtrl.text = DateFormat('dd MMM yyyy').format(picked);
                }
              }),
        ],
        onSave: () async {
          final name = nameCtrl.text.trim();
          final limit = double.tryParse(limitCtrl.text.trim()) ?? 0;
          final outstanding = double.tryParse(outstandingCtrl.text.trim()) ?? 0;
          if (name.isEmpty || outstanding <= 0) return;
          setState(() => _saving = true);
          try {
            await _col.add({
              'name': name,
              'limit': limit,
              'outstanding': outstanding,
              'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
              'createdAt': Timestamp.now(),
            });
            await _syncTotal();
          } finally {
            if (mounted) setState(() => _saving = false);
          }
        },
      ),
    );
  }

  Future<void> _delete(String id, double outstanding) async {
    final confirmed = await _confirmDelete(context);
    if (!confirmed) return;
    setState(() => _saving = true);
    try {
      await _col.doc(id).delete();
      await _syncTotal();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _syncTotal() async {
    final snap = await _col.get();
    double total = 0;
    for (final doc in snap.docs) {
      total += (doc.data() as Map<String, dynamic>)['outstanding'] as num? ?? 0;
    }
    await WealthService.updateAsset('creditCard', total);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final symbol = CurrencyController.to.currencySymbol.value;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark ? AppColors.darkGradient : AppColors.lightGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Credit Cards"),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        floatingActionButton: _saving
            ? const SizedBox.shrink()
            : FloatingActionButton.extended(
                onPressed: _add,
                backgroundColor: Colors.red.shade700,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  "Add Card",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _col.orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              return _buildEmpty(isDark);
            }
            double totalOutstanding = 0;
            for (final d in docs) {
              totalOutstanding += (d.data() as Map<String, dynamic>)['outstanding'] as num? ?? 0;
            }
            return ListView(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 100.h),
              children: [
                _buildSummary(totalOutstanding, symbol, isDark),
                SizedBox(height: 20.h),
                Text(
                  "Your Cards",
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
                SizedBox(height: 12.h),
                ...docs.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final dueTs = data['dueDate'] as Timestamp?;
                  return _buildCard(
                    id: d.id,
                    name: data['name'] ?? '',
                    limit: (data['limit'] as num?)?.toDouble() ?? 0,
                    outstanding: (data['outstanding'] as num?)?.toDouble() ?? 0,
                    dueDate: dueTs?.toDate(),
                    symbol: symbol,
                    isDark: isDark,
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummary(double total, String symbol, bool isDark) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)],
        ),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Total Outstanding",
              style: TextStyle(color: Colors.white70, fontSize: 13.sp)),
          SizedBox(height: 8.h),
          Text(
            "$symbol${total.toStringAsFixed(0)}",
            style: TextStyle(
                color: Colors.white,
                fontSize: 28.sp,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String id,
    required String name,
    required double limit,
    required double outstanding,
    required DateTime? dueDate,
    required String symbol,
    required bool isDark,
  }) {
    final usage = limit > 0 ? (outstanding / limit).clamp(0.0, 1.0) : 0.0;
    final formatter = DateFormat('dd MMM');
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: Colors.red.shade700.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.credit_card, color: Colors.red.shade700, size: 20.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15.sp,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _delete(id, outstanding),
                iconSize: 20.sp,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Outstanding",
                      style: TextStyle(fontSize: 11.sp, color: Colors.grey)),
                  Text(
                    "$symbol${outstanding.toStringAsFixed(0)}",
                    style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700),
                  ),
                ],
              ),
              if (limit > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("Limit",
                        style: TextStyle(fontSize: 11.sp, color: Colors.grey)),
                    Text(
                      "$symbol${limit.toStringAsFixed(0)}",
                      style: TextStyle(fontSize: 14.sp, color: Colors.grey),
                    ),
                  ],
                ),
              if (dueDate != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("Due", style: TextStyle(fontSize: 11.sp, color: Colors.grey)),
                    Text(
                      formatter.format(dueDate),
                      style: TextStyle(
                          fontSize: 14.sp,
                          color: dueDate.isBefore(DateTime.now().add(const Duration(days: 3)))
                              ? Colors.red
                              : Colors.grey),
                    ),
                  ],
                ),
            ],
          ),
          if (limit > 0) ...[
            SizedBox(height: 10.h),
            LinearProgressIndicator(
              value: usage,
              backgroundColor: Colors.red.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(
                usage > 0.8 ? Colors.red : Colors.orange,
              ),
              borderRadius: BorderRadius.circular(2.r),
              minHeight: 4.h,
            ),
            SizedBox(height: 4.h),
            Text(
              "${(usage * 100).toStringAsFixed(0)}% used",
              style: TextStyle(fontSize: 10.sp, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.credit_card_off_outlined,
              size: 72.sp, color: Colors.white24),
          SizedBox(height: 16.h),
          Text(
            "No credit cards added",
            style: TextStyle(color: Colors.white54, fontSize: 16.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            "Tap + to track your card outstanding",
            style: TextStyle(color: Colors.white38, fontSize: 13.sp),
          ),
        ],
      ),
    );
  }
}

Future<bool> _confirmDelete(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Delete?"),
      content: const Text("Remove this entry?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text("Delete", style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _FieldDef {
  final String label;
  final TextEditingController ctrl;
  final TextInputType keyboardType;
  final VoidCallback? onTap;
  const _FieldDef(this.label, this.ctrl, this.keyboardType, {this.onTap});
}

class _AddSheet extends StatefulWidget {
  final String title;
  final List<_FieldDef> fields;
  final Future<void> Function() onSave;

  const _AddSheet({
    required this.title,
    required this.fields,
    required this.onSave,
  });

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E2C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18.sp)),
            SizedBox(height: 16.h),
            ...widget.fields.map((f) => Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: TextField(
                    controller: f.ctrl,
                    keyboardType: f.keyboardType,
                    readOnly: f.onTap != null,
                    onTap: f.onTap,
                    inputFormatters: f.keyboardType == TextInputType.number
                        ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
                        : null,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: f.label,
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                )),
            SizedBox(height: 8.h),
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton(
                onPressed: _saving
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        try {
                          await widget.onSave();
                          if (context.mounted) Navigator.pop(context);
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Save",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
