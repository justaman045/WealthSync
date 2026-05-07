import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Services/wealth_service.dart';

class RealEstateDetailScreen extends StatefulWidget {
  const RealEstateDetailScreen({super.key});

  @override
  State<RealEstateDetailScreen> createState() => _RealEstateDetailScreenState();
}

class _RealEstateDetailScreenState extends State<RealEstateDetailScreen> {
  CollectionReference get _col {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .collection('properties');
  }

  bool _saving = false;

  Future<void> _add() async {
    final nameCtrl = TextEditingController();
    final typeCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final emiCtrl = TextEditingController();

    try { await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _Sheet(
        title: "Add Property",
        fields: [
          _F("Property name / description", nameCtrl, TextInputType.text),
          _F("Type (Flat / Plot / Villa / Shop)", typeCtrl, TextInputType.text),
          _F("Location / city", locationCtrl, TextInputType.text),
          _F("Current market value", valueCtrl, TextInputType.number),
          _F("Monthly home loan EMI (0 if none)", emiCtrl, TextInputType.number),
        ],
        onSave: () async {
          final name = nameCtrl.text.trim();
          final currentValue = double.tryParse(valueCtrl.text.trim()) ?? 0;
          if (name.isEmpty || currentValue <= 0) return;
          setState(() => _saving = true);
          try {
            await _col.add({
              'name': name,
              'type': typeCtrl.text.trim(),
              'location': locationCtrl.text.trim(),
              'currentValue': currentValue,
              'monthlyEmi': double.tryParse(emiCtrl.text.trim()) ?? 0,
              'createdAt': Timestamp.now(),
            });
            await _syncTotal();
          } finally {
            if (mounted) setState(() => _saving = false);
          }
        },
      ),
    ); } finally {
      nameCtrl.dispose();
      typeCtrl.dispose();
      locationCtrl.dispose();
      valueCtrl.dispose();
      emiCtrl.dispose();
    }
  }

  Future<void> _delete(String id) async {
    final ok = await _confirm(context);
    if (!ok) return;
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
    for (final d in snap.docs) {
      total += (d.data() as Map<String, dynamic>)['currentValue'] as num? ?? 0;
    }
    await WealthService.updateAsset('realEstate', total);
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
          title: const Text("Real Estate"),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        floatingActionButton: _saving
            ? const SizedBox.shrink()
            : FloatingActionButton.extended(
                onPressed: _add,
                backgroundColor: Colors.brown,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  "Add Property",
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
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.domain_outlined, size: 72.sp, color: Colors.white24),
                    SizedBox(height: 16.h),
                    Text("No properties added",
                        style: TextStyle(color: Colors.white54, fontSize: 16.sp)),
                    SizedBox(height: 8.h),
                    Text("Tap + to track your real estate",
                        style: TextStyle(color: Colors.white38, fontSize: 13.sp)),
                  ],
                ),
              );
            }
            double totalValue = 0;
            double totalEmi = 0;
            for (final d in docs) {
              final data = d.data() as Map<String, dynamic>;
              totalValue += (data['currentValue'] as num?)?.toDouble() ?? 0;
              totalEmi += (data['monthlyEmi'] as num?)?.toDouble() ?? 0;
            }
            return ListView(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 100.h),
              children: [
                _buildSummary(totalValue, totalEmi, symbol, docs.length),
                SizedBox(height: 20.h),
                Text(
                  "Properties",
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
                SizedBox(height: 12.h),
                ...docs.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return _buildCard(
                    id: d.id,
                    name: data['name'] ?? '',
                    type: data['type'] ?? '',
                    location: data['location'] ?? '',
                    value: (data['currentValue'] as num?)?.toDouble() ?? 0,
                    emi: (data['monthlyEmi'] as num?)?.toDouble() ?? 0,
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

  Widget _buildSummary(double value, double emi, String symbol, int count) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.brown.shade700, Colors.brown.shade500],
        ),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _col2("$count Propert${count == 1 ? 'y' : 'ies'}", "$symbol${_compact(value)}"),
          if (emi > 0) _col2("Monthly EMI", "$symbol${emi.toStringAsFixed(0)}"),
        ],
      ),
    );
  }

  Widget _col2(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
        SizedBox(height: 4.h),
        Text(value,
            style: TextStyle(
                color: Colors.white,
                fontSize: 22.sp,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildCard({
    required String id,
    required String name,
    required String type,
    required String location,
    required double value,
    required double emi,
    required String symbol,
    required bool isDark,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.brown.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.brown.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.domain, color: Colors.brown.shade400, size: 24.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15.sp,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary),
                ),
                if (type.isNotEmpty || location.isNotEmpty)
                  Text(
                    [type, location].where((s) => s.isNotEmpty).join(' · '),
                    style: TextStyle(color: Colors.grey, fontSize: 12.sp),
                  ),
                SizedBox(height: 6.h),
                Text(
                  "$symbol${_compact(value)}",
                  style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.brown.shade300),
                ),
                if (emi > 0)
                  Text("Home loan EMI: $symbol${emi.toStringAsFixed(0)}/mo",
                      style: TextStyle(fontSize: 11.sp, color: Colors.orange)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _delete(id),
            iconSize: 20.sp,
          ),
        ],
      ),
    );
  }
}

String _compact(double v) {
  if (v >= 10000000) return "${(v / 10000000).toStringAsFixed(1)}Cr";
  if (v >= 100000) return "${(v / 100000).toStringAsFixed(1)}L";
  if (v >= 1000) return "${(v / 1000).toStringAsFixed(0)}K";
  return v.toStringAsFixed(0);
}

Future<bool> _confirm(BuildContext context) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Delete?"),
      content: const Text("Remove this property?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red))),
      ],
    ),
  );
  return r ?? false;
}

class _F {
  final String label;
  final TextEditingController ctrl;
  final TextInputType type;
  const _F(this.label, this.ctrl, this.type);
}

class _Sheet extends StatefulWidget {
  final String title;
  final List<_F> fields;
  final Future<void> Function() onSave;
  const _Sheet({required this.title, required this.fields, required this.onSave});
  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
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
                    keyboardType: f.type,
                    inputFormatters: f.type == TextInputType.number
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
                      borderRadius: BorderRadius.circular(14.r)),
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
