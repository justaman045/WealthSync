import 'dart:async';
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
import 'package:money_control/Utils/responsive.dart';

// ─── Field types ──────────────────────────────────────────────────────────────

enum AssetFieldType { text, number, date, dropdown }

class AssetFieldDef {
  final String label;
  final String key;
  final AssetFieldType type;
  final List<String>? options; // for dropdown
  final bool required;
  final bool isAmountField; // this field is summed to compute the card total

  const AssetFieldDef({
    required this.label,
    required this.key,
    this.type = AssetFieldType.text,
    this.options,
    this.required = false,
    this.isAmountField = false,
  });
}

// ─── Screen config ────────────────────────────────────────────────────────────

class AssetScreenConfig {
  final String title;
  final String collection;
  final String assetKey;
  final Color accentColor;
  final IconData icon;
  final List<AssetFieldDef> fields;
  final String fabLabel;
  final String emptyMessage;
  final String summaryLabel;
  // Optional: extra row displayed per card (e.g. "Rate: X%")
  final String? secondaryFieldKey;
  final String? secondaryFieldLabel;

  const AssetScreenConfig({
    required this.title,
    required this.collection,
    required this.assetKey,
    required this.accentColor,
    required this.icon,
    required this.fields,
    required this.fabLabel,
    required this.emptyMessage,
    required this.summaryLabel,
    this.secondaryFieldKey,
    this.secondaryFieldLabel,
  });

  AssetFieldDef get amountField =>
      fields.firstWhere((f) => f.isAmountField, orElse: () => fields.last);
}

// ─── Main screen ─────────────────────────────────────────────────────────────

class AssetDetailScreen extends StatefulWidget {
  final AssetScreenConfig config;
  const AssetDetailScreen({super.key, required this.config});

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  bool _saving = false;
  bool _syncedEmpty = false;

  AssetScreenConfig get cfg => widget.config;

  CollectionReference get _col {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .collection(cfg.collection);
  }

  Future<void> _syncTotal(QuerySnapshot snap) async {
    final amountKey = cfg.amountField.key;
    double total = 0;
    for (final d in snap.docs) {
      final data = d.data() as Map<String, dynamic>;
      total += (data[amountKey] as num?)?.toDouble() ?? 0;
    }
    await WealthService.updateAsset(cfg.assetKey, total);
  }

  Future<void> _addOrEditEntry({String? id, Map<String, dynamic>? existingData}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Responsive.wrapSheetContent(ctx, _AddSheet(
        config: cfg,
        existingId: id,
        existingData: existingData,
        onSave: (data) async {
          setState(() => _saving = true);
          try {
            if (id != null) {
              await _col.doc(id).update(data);
            } else {
              await _col.add(data);
            }
            final snap = await _col.get();
            await _syncTotal(snap);
          } finally {
            if (mounted) setState(() => _saving = false);
          }
        },
      )),
    );
  }

  Future<void> _delete(String id) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        title: Text("Remove entry?",
          style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary)),
        content: Text("This will delete this item permanently.",
          style: TextStyle(color: isDark ? Colors.white70 : AppColors.lightTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel",
              style: TextStyle(color: isDark ? Colors.white70 : AppColors.lightTextSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      await _col.doc(id).delete();
      final snap = await _col.get();
      await _syncTotal(snap);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
          title: Text(cfg.title),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        floatingActionButton: _saving
            ? const SizedBox.shrink()
            : FloatingActionButton.extended(
                onPressed: () => _addOrEditEntry(),
                backgroundColor: cfg.accentColor,
                icon: const Icon(Icons.add, color: Colors.white),
                label: Text(
                  cfg.fabLabel,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _col.orderBy('createdAt', descending: true).limit(25).snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text("Error: ${snap.error}"));
            }
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              if (!_syncedEmpty) {
                _syncedEmpty = true;
                WealthService.updateAsset(cfg.assetKey, 0);
              }
              return _buildEmpty(isDark);
            }

            double total = 0;
            for (final d in docs) {
              final data = d.data() as Map<String, dynamic>;
              total += (data[cfg.amountField.key] as num?)?.toDouble() ?? 0;
            }

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 100.h),
              children: [
                _buildSummary(total, symbol, docs.length),
                SizedBox(height: 20.h),
                Text(
                  "Entries",
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
                SizedBox(height: 12.h),
                ...docs.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return _buildCard(d.id, data, symbol, isDark);
                }),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummary(double total, String symbol, int count) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cfg.accentColor.withValues(alpha: 0.9), cfg.accentColor],
        ),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(cfg.icon, color: Colors.white, size: 24.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cfg.summaryLabel,
                  style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                ),
                Text(
                  "$symbol${_compact(total)}",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 26.sp,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Text(
            "$count item${count == 1 ? '' : 's'}",
            style: TextStyle(color: Colors.white70, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String id, Map<String, dynamic> data, String symbol, bool isDark) {
    // Primary display: first text field or dropdown as title
    String title = '';
    for (final f in cfg.fields) {
      if (f.type == AssetFieldType.text || f.type == AssetFieldType.dropdown) {
        final v = data[f.key]?.toString() ?? '';
        if (v.isNotEmpty) {
          title = v;
          break;
        }
      }
    }
    if (title.isEmpty) title = cfg.title;

    final amountVal = (data[cfg.amountField.key] as num?)?.toDouble() ?? 0;

    // Collect supplementary info rows
    final extraRows = <String>[];
    for (final f in cfg.fields) {
      if (f.key == cfg.amountField.key) continue;
      if (f.type == AssetFieldType.text && data[f.key]?.toString() == title) continue;
      if (f.type == AssetFieldType.dropdown && data[f.key]?.toString() == title) continue;
      final raw = data[f.key];
      if (raw == null) continue;
      if (f.type == AssetFieldType.number) {
        final v = (raw as num?)?.toDouble() ?? 0;
        if (v > 0) {
          extraRows.add("${f.label}: $symbol${_compact(v)}");
        }
      } else if (f.type == AssetFieldType.date) {
        if (raw is Timestamp) {
          extraRows.add("${f.label}: ${DateFormat('dd MMM yyyy').format(raw.toDate())}");
        }
      } else {
        final s = raw.toString();
        if (s.isNotEmpty && s != title) {
          extraRows.add("${f.label}: $s");
        }
      }
    }

    return GestureDetector(
      onTap: () => _addOrEditEntry(id: id, existingData: data),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: cfg.accentColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: cfg.accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(cfg.icon, color: cfg.accentColor, size: 20.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15.sp,
                        color: isDark ? Colors.white : AppColors.lightTextPrimary),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    "$symbol${_compact(amountVal)}",
                    style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: cfg.accentColor),
                  ),
                  if (extraRows.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    ...extraRows.take(2).map((row) => Text(
                          row,
                          style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                        )),
                  ],
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
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(cfg.icon, size: 72.sp, color: Colors.white24),
          SizedBox(height: 16.h),
          Text(cfg.emptyMessage,
              style: TextStyle(color: Colors.white54, fontSize: 16.sp),
              textAlign: TextAlign.center),
          SizedBox(height: 8.h),
          Text("Tap + to add your first entry",
              style: TextStyle(color: Colors.white38, fontSize: 13.sp)),
        ],
      ),
    );
  }
}

// ─── Add entry bottom sheet ───────────────────────────────────────────────────

class _AddSheet extends StatefulWidget {
  final AssetScreenConfig config;
  final String? existingId;
  final Map<String, dynamic>? existingData;
  final Future<void> Function(Map<String, dynamic> data) onSave;

  const _AddSheet({
    required this.config,
    this.existingId,
    this.existingData,
    required this.onSave,
  });

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  bool _saving = false;
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, String> _dropdownValues;
  late final Map<String, DateTime> _dateValues;

  @override
  void initState() {
    super.initState();
    _controllers = {};
    _dropdownValues = {};
    _dateValues = {};
    for (final f in widget.config.fields) {
      if (f.type == AssetFieldType.dropdown) {
        _dropdownValues[f.key] = widget.existingData?[f.key]?.toString() ?? f.options!.first;
      } else {
        final existing = widget.existingData?[f.key];
        String initialValue = '';
        if (existing != null) {
          if (f.type == AssetFieldType.date && existing is Timestamp) {
            initialValue = DateFormat('dd MMM yyyy').format(existing.toDate());
            _dateValues[f.key] = existing.toDate();
          } else {
            initialValue = existing.toString();
          }
        }
        _controllers[f.key] = TextEditingController(text: initialValue);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    // Validate required fields
    for (final f in widget.config.fields) {
      if (f.required) {
        if (f.type == AssetFieldType.number || f.type == AssetFieldType.text) {
          if (_controllers[f.key]?.text.trim().isEmpty ?? true) return;
        }
      }
    }
    final amountKey = widget.config.amountField.key;
    final amountVal = double.tryParse(_controllers[amountKey]?.text.trim() ?? '') ?? 0;
    if (amountVal <= 0) return;

    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{};
      if (widget.existingId == null) {
        data['createdAt'] = Timestamp.now();
      }
      for (final f in widget.config.fields) {
        if (f.type == AssetFieldType.number) {
          data[f.key] = double.tryParse(_controllers[f.key]?.text.trim() ?? '') ?? 0;
        } else if (f.type == AssetFieldType.date) {
          final d = _dateValues[f.key];
          data[f.key] = d != null ? Timestamp.fromDate(d) : null;
        } else if (f.type == AssetFieldType.dropdown) {
          data[f.key] = _dropdownValues[f.key];
        } else {
          data[f.key] = _controllers[f.key]?.text.trim() ?? '';
        }
      }
      await widget.onSave(data);
      if (!mounted) return;
      Navigator.pop(context);
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
        padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 32.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existingId != null ? "Edit ${widget.config.title}" : widget.config.fabLabel,
              style: TextStyle(
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18.sp),
            ),
            SizedBox(height: 16.h),
            ...widget.config.fields.map((f) => Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: _buildField(f, isDark),
                )),
            SizedBox(height: 8.h),
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.config.accentColor,
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

  Widget _buildField(AssetFieldDef f, bool isDark) {
    if (f.type == AssetFieldType.dropdown) {
      return StatefulBuilder(builder: (ctx, localSet) {
        return DropdownButtonFormField<String>(
          initialValue: _dropdownValues[f.key],
          dropdownColor: isDark ? const Color(0xFF1E1E2C) : AppColors.lightSurface,
          style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary),
          decoration: _inputDecoration(f.label, isDark),
          items: f.options!
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              localSet(() => _dropdownValues[f.key] = v);
            }
          },
        );
      });
    }

    if (f.type == AssetFieldType.date) {
      final ctrl = _controllers[f.key];
      return TextField(
        controller: ctrl,
        readOnly: true,
        style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary),
        decoration: _inputDecoration(f.label, isDark),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now().add(const Duration(days: 365)),
            firstDate: DateTime(2000),
            lastDate: DateTime(2060),
          );
          if (picked != null) {
            if (!mounted) return;
            setState(() {
              ctrl?.text = DateFormat('dd MMM yyyy').format(picked);
            });
          }
        },
      );
    }

    return TextField(
      controller: _controllers[f.key],
      keyboardType: f.type == AssetFieldType.number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: f.type == AssetFieldType.number
          ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
          : null,
      style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary),
      decoration: _inputDecoration(f.label, isDark),
    );
  }

  InputDecoration _inputDecoration(String label, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDark ? Colors.white54 : AppColors.lightTextSecondary),
      filled: true,
      fillColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide.none,
      ),
    );
  }
}

// ─── Helper re-exported from wealth_math for backwards compat ────────────────

String _compact(double v) => compact(v);
