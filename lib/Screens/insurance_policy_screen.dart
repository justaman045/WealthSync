import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Services/wealth_service.dart';
import 'package:money_control/Utils/wealth_math.dart';

class InsurancePolicyScreen extends StatefulWidget {
  const InsurancePolicyScreen({super.key});

  @override
  State<InsurancePolicyScreen> createState() => _InsurancePolicyScreenState();
}

class _InsurancePolicyScreenState extends State<InsurancePolicyScreen> {
  CollectionReference get _col {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .collection('insurance_policies');
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
        title: id != null ? "Edit Policy" : "Add Policy",
        fields: const [
          _FieldDef("Policy name / insurer", TextInputType.text),
          _FieldDef("Type (Life / ULIP / Term / Endowment)", TextInputType.text),
          _FieldDef("Annual premium", TextInputType.number),
          _FieldDef("Sum assured / corpus", TextInputType.number),
          _FieldDef("Maturity date (optional)", TextInputType.datetime),
        ],
        existingData: existingData,
        onSave: (values, dateValues) async {
          final name = values["Policy name / insurer"] ?? '';
          final sumAssured = double.tryParse(values["Sum assured / corpus"] ?? '') ?? 0;
          if (name.isEmpty || sumAssured <= 0) return;
          final maturityDate = dateValues["Maturity date (optional)"];
          setState(() => _saving = true);
          try {
            final docData = {
              'name': name,
              'type': values["Type (Life / ULIP / Term / Endowment)"] ?? '',
              'annualPremium': double.tryParse(values["Annual premium"] ?? '') ?? 0,
              'sumAssured': sumAssured,
              'maturityDate': maturityDate != null ? Timestamp.fromDate(maturityDate) : null,
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
      total += (d.data() as Map<String, dynamic>)['sumAssured'] as num? ?? 0;
    }
    await WealthService.updateAsset('insurance', total);
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
          title: const Text("Insurance Policies"),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        floatingActionButton: _saving
            ? const SizedBox.shrink()
            : FloatingActionButton.extended(
                onPressed: _add,
                backgroundColor: Colors.pink,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  "Add Policy",
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
                WealthService.updateAsset('insurance', 0);
              }
              return _buildEmpty();
            }
            double totalCorpus = 0;
            double totalPremium = 0;
            for (final d in docs) {
              final data = d.data() as Map<String, dynamic>;
              totalCorpus += (data['sumAssured'] as num?)?.toDouble() ?? 0;
              totalPremium += (data['annualPremium'] as num?)?.toDouble() ?? 0;
            }
            return ListView(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 100.h),
              children: [
                _buildSummary(totalCorpus, totalPremium, symbol),
                SizedBox(height: 20.h),
                Text(
                  "Policies",
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
                SizedBox(height: 12.h),
                ...docs.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final matTs = data['maturityDate'] as Timestamp?;
                  return _buildCard(
                    id: d.id,
                    name: data['name'] ?? '',
                    type: data['type'] ?? '',
                    premium: (data['annualPremium'] as num?)?.toDouble() ?? 0,
                    sumAssured: (data['sumAssured'] as num?)?.toDouble() ?? 0,
                    maturity: matTs?.toDate(),
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

  Widget _buildSummary(double corpus, double premium, String symbol) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFAD1457), Color(0xFFE91E63)],
        ),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryCol("Total Corpus", "$symbol${_compact(corpus)}"),
          _summaryCol("Annual Premium", "$symbol${_compact(premium)}"),
        ],
      ),
    );
  }

  Widget _summaryCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
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
    required double premium,
    required double sumAssured,
    required DateTime? maturity,
    required String symbol,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () => _edit(id, {
        'name': name, 'type': type, 'annualPremium': premium,
        'sumAssured': sumAssured,
        'maturityDate': maturity != null ? Timestamp.fromDate(maturity) : null,
      }),
      child: Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.pink.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety, color: Colors.pink, size: 20.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.sp,
                            color: isDark ? Colors.white : AppColors.lightTextPrimary)),
                    if (type.isNotEmpty)
                      Text(type,
                          style: TextStyle(color: Colors.grey, fontSize: 12.sp)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _delete(id),
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
              _infoCol("Sum Assured", "$symbol${_compact(sumAssured)}",
                  Colors.pink, isDark),
              _infoCol(
                  "Annual Premium",
                  "$symbol${premium.toStringAsFixed(0)}",
                  Colors.orange,
                  isDark),
              if (maturity != null)
                _infoCol("Matures",
                    DateFormat('MMM yyyy').format(maturity), Colors.teal, isDark),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _infoCol(String label, String value, Color color, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11.sp, color: Colors.grey)),
        Text(value,
            style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: color)),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.health_and_safety_outlined, size: 72.sp, color: Colors.white24),
          SizedBox(height: 16.h),
          Text("No policies added",
              style: TextStyle(color: Colors.white54, fontSize: 16.sp)),
          SizedBox(height: 8.h),
          Text("Tap + to track life insurance and ULIPs",
              style: TextStyle(color: Colors.white38, fontSize: 13.sp)),
        ],
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
      content: const Text("Remove this policy?"),
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
  final Future<void> Function(Map<String, String> values, Map<String, DateTime?> dateValues) onSave;
  const _Sheet({required this.title, required this.fields, this.existingData, required this.onSave});
  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  bool _saving = false;
  late final List<TextEditingController> _ctrls;
  final _dateValues = <String, DateTime?>{};

  @override
  void initState() {
    super.initState();
    _ctrls = widget.fields.map((f) {
      final existing = widget.existingData;
      if (existing != null) {
        final key = _fieldKey(f.label);
        if (key == 'maturityDate' && existing['maturityDate'] is Timestamp) {
          final d = (existing['maturityDate'] as Timestamp).toDate();
          _dateValues[f.label] = d;
          return TextEditingController(text: DateFormat('dd MMM yyyy').format(d));
        }
        final raw = existing[key];
        if (raw != null) return TextEditingController(text: raw.toString());
      }
      return TextEditingController();
    }).toList();
  }

  String _fieldKey(String label) {
    if (label == "Policy name / insurer") return 'name';
    if (label == "Type (Life / ULIP / Term / Endowment)") return 'type';
    if (label == "Annual premium") return 'annualPremium';
    if (label == "Sum assured / corpus") return 'sumAssured';
    if (label == "Maturity date (optional)") return 'maturityDate';
    return label;
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(int i) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2060),
    );
    if (picked != null) {
      setState(() {
        _ctrls[i].text = DateFormat('dd MMM yyyy').format(picked);
        _dateValues[widget.fields[i].label] = picked;
      });
    }
  }

  Future<void> _save() async {
    final values = <String, String>{};
    for (int i = 0; i < widget.fields.length; i++) {
      values[widget.fields[i].label] = _ctrls[i].text.trim();
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(values, _dateValues);
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
              final isDate = f.type == TextInputType.datetime;
              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: TextField(
                  controller: _ctrls[i],
                  keyboardType: isDate ? TextInputType.text : f.type,
                  readOnly: isDate,
                  onTap: isDate ? () => _pickDate(i) : null,
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
