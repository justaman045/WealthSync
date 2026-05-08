import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Services/wealth_service.dart';
import 'package:money_control/Utils/wealth_math.dart';

class VehicleDetailScreen extends StatefulWidget {
  const VehicleDetailScreen({super.key});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  CollectionReference get _col {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .collection('vehicles');
  }

  bool _saving = false;
  bool _syncedEmpty = false;

  Future<void> _add() async {
    await _showSheet();
  }

  Future<void> _edit(String id, Map<String, dynamic> data) async {
    await _showSheet(id: id, existingData: data);
  }

  Future<void> _showSheet({String? id, Map<String, dynamic>? existingData}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _Sheet(
        title: id != null ? "Edit Vehicle" : "Add Vehicle",
        fields: const [
          _FieldDef("Make (e.g. Maruti, Honda)", TextInputType.text),
          _FieldDef("Model (e.g. Swift, City)", TextInputType.text),
          _FieldDef("Year of purchase", TextInputType.number),
          _FieldDef("Current market value", TextInputType.number),
          _FieldDef("Monthly EMI (0 if no loan)", TextInputType.number),
        ],
        existingData: existingData,
        onSave: (values) async {
          final make = values["Make (e.g. Maruti, Honda)"] ?? '';
          final currentValue = double.tryParse(values["Current market value"] ?? '') ?? 0;
          if (make.isEmpty || currentValue <= 0) return;
          setState(() => _saving = true);
          try {
            final docData = {
              'make': make,
              'model': values["Model (e.g. Swift, City)"] ?? '',
              'year': int.tryParse(values["Year of purchase"] ?? '') ?? 0,
              'currentValue': currentValue,
              'monthlyEmi': double.tryParse(values["Monthly EMI (0 if no loan)"] ?? '') ?? 0,
            };
            if (id != null) {
              await _col.doc(id).update(docData);
            } else {
              docData['createdAt'] = Timestamp.now();
              await _col.add(docData);
            }
            await _syncTotal();
          } finally {
            if (mounted) setState(() => _saving = false);
          }
        },
      ),
    );
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
    await WealthService.updateAsset('vehicle', total);
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
          title: const Text("Vehicles"),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        floatingActionButton: _saving
            ? const SizedBox.shrink()
            : FloatingActionButton.extended(
                onPressed: _add,
                backgroundColor: Colors.blueGrey.shade400,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  "Add Vehicle",
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
              if (!_syncedEmpty) {
                _syncedEmpty = true;
                WealthService.updateAsset('vehicle', 0);
              }
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_car_outlined,
                        size: 72.sp, color: Colors.white24),
                    SizedBox(height: 16.h),
                    Text("No vehicles added",
                        style: TextStyle(color: Colors.white54, fontSize: 16.sp)),
                    SizedBox(height: 8.h),
                    Text("Tap + to track your vehicles",
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
                _buildSummary(totalValue, totalEmi, symbol),
                SizedBox(height: 20.h),
                Text(
                  "Your Vehicles",
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
                    make: data['make'] ?? '',
                    model: data['model'] ?? '',
                    year: (data['year'] as num?)?.toInt() ?? 0,
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

  Widget _buildSummary(double value, double emi, String symbol) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueGrey.shade700, Colors.blueGrey.shade500],
        ),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _col2("Total Value", "$symbol${_compact(value)}"),
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
    required String make,
    required String model,
    required int year,
    required double value,
    required double emi,
    required String symbol,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () => _edit(id, {
        'make': make, 'model': model, 'year': year,
        'currentValue': value, 'monthlyEmi': emi,
      }),
      child: Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.directions_car,
                color: Colors.blueGrey.shade400, size: 24.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$make${model.isNotEmpty ? ' $model' : ''}",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15.sp,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary),
                ),
                if (year > 0)
                  Text("$year",
                      style: TextStyle(color: Colors.grey, fontSize: 12.sp)),
                SizedBox(height: 4.h),
                Text(
                  "$symbol${_compact(value)}",
                  style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey.shade300),
                ),
                if (emi > 0)
                  Text("EMI: $symbol${emi.toStringAsFixed(0)}/mo",
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
      ),
    );
  }
}

String _compact(double v) => compact(v);

Future<bool> _confirm(BuildContext context) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Delete?"),
      content: const Text("Remove this vehicle?"),
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

class _FieldDef {
  final String label;
  final TextInputType type;
  const _FieldDef(this.label, this.type);
}

class _Sheet extends StatefulWidget {
  final String title;
  final List<_FieldDef> fields;
  final Map<String, dynamic>? existingData;
  final Future<void> Function(Map<String, String> values) onSave;
  const _Sheet({required this.title, required this.fields, this.existingData, required this.onSave});
  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  bool _saving = false;
  late final List<TextEditingController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = widget.fields.map((f) {
      final existing = widget.existingData;
      if (existing != null) {
        final key = _fieldKey(f.label);
        final raw = existing[key];
        if (raw != null) return TextEditingController(text: raw.toString());
      }
      return TextEditingController();
    }).toList();
  }

  String _fieldKey(String label) {
    if (label == "Make (e.g. Maruti, Honda)") return 'make';
    if (label == "Model (e.g. Swift, City)") return 'model';
    if (label == "Year of purchase") return 'year';
    if (label == "Current market value") return 'currentValue';
    if (label == "Monthly EMI (0 if no loan)") return 'monthlyEmi';
    return label;
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final values = <String, String>{};
    for (int i = 0; i < widget.fields.length; i++) {
      values[widget.fields[i].label] = _ctrls[i].text.trim();
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(values);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
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
            ...List.generate(widget.fields.length, (i) {
              final f = widget.fields[i];
              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: TextField(
                  controller: _ctrls[i],
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
              );
            }),
            SizedBox(height: 8.h),
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
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
