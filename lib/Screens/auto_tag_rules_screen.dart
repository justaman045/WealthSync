import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Services/sms_service.dart';
import 'package:money_control/Services/category_service.dart';

class AutoTagRulesScreen extends StatefulWidget {
  const AutoTagRulesScreen({super.key});

  @override
  State<AutoTagRulesScreen> createState() => _AutoTagRulesScreenState();
}

class _AutoTagRulesScreenState extends State<AutoTagRulesScreen> {
  Map<String, List<String>> _rules = {};
  Map<String, List<String>> _userRules = {};
  List<Map<String, dynamic>> _suggestions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userRules = await SmsService.loadUserCustomRules();
    final merged = <String, List<String>>{};

    SmsService.defaultRules.forEach((cat, keywords) {
      merged[cat] = List<String>.from(keywords);
    });
    userRules.forEach((cat, keywords) {
      merged[cat] = [...(merged[cat] ?? []), ...keywords];
    });

    final suggestions = await CategoryService.getPendingSuggestions();

    setState(() {
      _rules = merged;
      _userRules = userRules;
      _suggestions = suggestions;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await SmsService.saveUserCustomRules(_userRules);
  }

  Future<void> _acceptSuggestion(Map<String, dynamic> suggestion) async {
    final merchant = suggestion['merchant'] as String;
    final category = suggestion['category'] as String;
    setState(() {
      _userRules[category] = [...(_userRules[category] ?? []), merchant];
      _rules[category] = [...(_rules[category] ?? []), merchant];
      _suggestions.removeWhere((s) => s['merchant'] == merchant);
    });
    await _save();
    await CategoryService.removeSuggestion(merchant);
  }

  Future<void> _dismissSuggestion(String merchant) async {
    setState(() => _suggestions.removeWhere((s) => s['merchant'] == merchant));
    await CategoryService.removeSuggestion(merchant);
  }

  bool _isDefault(String category, String keyword) {
    final defaults = SmsService.defaultRules[category] ?? [];
    return defaults.contains(keyword.toLowerCase());
  }

  void _addKeyword(String category) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text(
          "Add keyword to $category",
          style: TextStyle(color: Colors.white, fontSize: 16.sp),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "e.g. amazon, swiggy",
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.07),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              final kw = ctrl.text.trim().toLowerCase();
              if (kw.isEmpty) return;
              Navigator.pop(context);
              setState(() {
                _userRules[category] = [...(_userRules[category] ?? []), kw];
                _rules[category] = [...(_rules[category] ?? []), kw];
              });
              _save();
            },
            child: Text("Add", style: TextStyle(color: AppColors.secondary)),
          ),
        ],
      ),
    );
  }

  void _removeKeyword(String category, String keyword) {
    if (_isDefault(category, keyword)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Default rules can't be deleted")),
      );
      return;
    }
    setState(() {
      _userRules[category]?.remove(keyword);
      if (_userRules[category]?.isEmpty == true) _userRules.remove(category);
      _rules[category]?.remove(keyword);
      if (_rules[category]?.isEmpty == true) _rules.remove(category);
    });
    _save();
  }

  void _addCategory() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text("New category", style: TextStyle(color: Colors.white, fontSize: 16.sp)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "e.g. Healthcare",
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.07),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty || _rules.containsKey(name)) return;
              Navigator.pop(context);
              setState(() {
                _rules[name] = [];
                _userRules[name] = [];
              });
              _save();
            },
            child: Text("Create", style: TextStyle(color: AppColors.secondary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
          title: const Text("Auto-Tag Rules"),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: "Add category",
              onPressed: _addCategory,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_suggestions.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Suggested Rules",
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondary,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          ..._suggestions.map((s) {
                            final merchant = s['merchant'] as String;
                            final category = s['category'] as String;
                            final count = s['count'] as int;
                            return Container(
                              margin: EdgeInsets.only(bottom: 8.h),
                              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(color: AppColors.secondary.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          merchant.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          "Categorized as $category ($count times)",
                                          style: TextStyle(fontSize: 11.sp, color: Colors.white60),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => _acceptSuggestion(s),
                                    child: Text("Add Rule", style: TextStyle(fontSize: 12.sp, color: AppColors.secondary)),
                                  ),
                                  GestureDetector(
                                    onTap: () => _dismissSuggestion(merchant),
                                    child: Icon(Icons.close, size: 16.sp, color: Colors.white38),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16.sp, color: AppColors.primary),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              "SMS transactions matching any keyword are auto-tagged to that category. Grey chips are defaults (read-only).",
                              style: TextStyle(fontSize: 12.sp, color: theme.textTheme.bodyMedium?.color),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                      itemCount: _rules.length,
                      separatorBuilder: (_, __) => SizedBox(height: 12.h),
                      itemBuilder: (_, i) {
                        final cat = _rules.keys.elementAt(i);
                        final keywords = _rules[cat] ?? [];
                        return _buildCategoryCard(cat, keywords, theme, isDark);
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCategoryCard(String category, List<String> keywords, ThemeData theme, bool isDark) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                category,
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _addKeyword(category),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 14.sp, color: AppColors.secondary),
                      SizedBox(width: 4.w),
                      Text("Add", style: TextStyle(fontSize: 12.sp, color: AppColors.secondary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (keywords.isNotEmpty) ...[
            SizedBox(height: 10.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 6.h,
              children: keywords.map((kw) {
                final isDefault = _isDefault(category, kw);
                return GestureDetector(
                  onLongPress: () => _removeKeyword(category, kw),
                  child: Chip(
                    label: Text(kw, style: TextStyle(fontSize: 12.sp, color: isDefault ? Colors.white70 : Colors.white)),
                    backgroundColor: isDefault
                        ? Colors.white.withValues(alpha: 0.1)
                        : AppColors.primary.withValues(alpha: 0.3),
                    side: BorderSide(
                      color: isDefault ? Colors.white.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.5),
                    ),
                    deleteIcon: isDefault
                        ? null
                        : Icon(Icons.close, size: 14.sp, color: Colors.white70),
                    onDeleted: isDefault ? null : () => _removeKeyword(category, kw),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            SizedBox(height: 8.h),
            Text(
              "No keywords yet — tap Add",
              style: TextStyle(fontSize: 12.sp, color: theme.textTheme.bodyMedium?.color),
            ),
          ],
        ],
      ),
    );
  }
}
