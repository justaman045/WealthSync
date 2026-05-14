import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Models/cateogary.dart';
import 'package:money_control/Services/category_service.dart';
import 'package:money_control/Utils/icon_helper.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Controllers/subscription_controller.dart';
import 'package:money_control/Components/pro_lock_widget.dart';
import 'package:money_control/Components/colors.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final CategoryService _categoryService = CategoryService();

  void _showCategoryDialog({CategoryModel? category}) {
    showDialog(
      context: context,
      builder: (_) => _CategoryDialog(
        category: category,
        onSave: (model) async {
          if (category == null) {
            if (!Get.isRegistered<SubscriptionController>()) Get.put(SubscriptionController());
            if (!Get.isRegistered<TransactionController>()) Get.put(TransactionController());
            final subCtrl = Get.find<SubscriptionController>();
            final txCtrl = Get.find<TransactionController>();

            if (!subCtrl.isPro && txCtrl.categories.length >= 10) {
              Navigator.pop(context); // Close dialog
              showModalBottomSheet(
                context: context,
                backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkBackground : AppColors.lightBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24.r),
                  ),
                ),
                builder: (_) => const ProLockWidget(
                  title: "Category Limit Reached",
                  description:
                      "Free users can create up to 10 categories. Upgrade to Pro for unlimited categories.",
                ),
              );
              return;
            }

            await _categoryService.addCategory(model);
          } else {
            await _categoryService.updateCategory(model);
          }
        },
      ),
    );
  }

  void _deleteCategory(CategoryModel category) {
    if (!Get.isRegistered<TransactionController>()) {
      Get.put(TransactionController());
    }
    final txCtrl = Get.find<TransactionController>();
    final usageCount = txCtrl.getCategoryUsageCount(category.name);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (usageCount == 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Delete Category"),
          content: Text("Are you sure you want to delete '${category.name}'?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                await _categoryService.deleteCategory(category.id);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text("Delete"),
            ),
          ],
        ),
      );
      return;
    }

    final otherCategories = txCtrl.categories
        .where((c) => c.id != category.id)
        .map((c) => c.name)
        .toList();
    final selected = otherCategories.firstOrNull ?? ''.obs;
    final selectedName = selected is RxString ? selected : RxString('');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final currentSelected = selectedName.value;
          return AlertDialog(
            backgroundColor: Theme.of(ctx).brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r),
            ),
            title: Text(
              "Category in Use",
              style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary, fontSize: 18.sp),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "'${category.name}' is used by $usageCount transaction${usageCount == 1 ? '' : 's'}.",
                  style: TextStyle(color: isDark ? Colors.white70 : AppColors.lightTextSecondary),
                ),
                SizedBox(height: 16.h),
                Text(
                  "Migrate to:",
                  style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary, fontSize: 14.sp),
                ),
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: isDark ? Colors.white24 : AppColors.lightBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: currentSelected.isEmpty ? null : currentSelected,
                      hint: Text("Select category",
                          style: TextStyle(color: isDark ? Colors.white54 : AppColors.lightTextSecondary)),
                      dropdownColor: Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF2A2A3E) : AppColors.lightSurface,
                      style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary),
                      isExpanded: true,
                      items: otherCategories
                          .map((name) => DropdownMenuItem(
                                value: name,
                                child: Text(name),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedName.value = val);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () async {
                  await _categoryService.deleteCategory(category.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text("Delete Anyway",
                    style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                onPressed: currentSelected.isEmpty
                    ? null
                    : () async {
                        await txCtrl.migrateTransactions(
                            category.name, currentSelected);
                        await _categoryService.deleteCategory(category.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                ),
                child: const Text("Migrate & Delete",
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "Manage Categories",
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : AppColors.lightTextPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark ? AppColors.darkGradient : AppColors.lightGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<List<CategoryModel>>(
            stream: _categoryService.getCategoriesStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    "Error loading categories",
                    style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              final categories = snapshot.data ?? [];

              if (categories.isEmpty) {
                return Center(
                  child: Text(
                    "No categories found",
                    style: TextStyle(color: isDark ? Colors.white54 : AppColors.lightTextSecondary),
                  ),
                );
              }

              return GridView.builder(
                padding: EdgeInsets.all(16.w),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12.w,
                  mainAxisSpacing: 12.h,
                  childAspectRatio: 0.85,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return _buildCategoryTile(cat);
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        backgroundColor: const Color(0xFF00E5FF),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildCategoryTile(CategoryModel cat) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = cat.color != null
        ? Color(cat.color!)
        : const Color(0xFF6C63FF);
    final icon = IconHelper.getIconFromCode(cat.iconCode);

    return GestureDetector(
      onTap: () => _showCategoryDialog(category: cat),
      onLongPress: () => _deleteCategory(cat),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              cat.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12.sp,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  final CategoryModel? category;
  final Function(CategoryModel) onSave;

  const _CategoryDialog({this.category, required this.onSave});

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _nameController = TextEditingController();
  int _selectedColor = 0xFF6C63FF;
  int _selectedIconCode = Icons.category.codePoint;

  final List<int> _presetColors = [
    0xFFF44336, // Red
    0xFFE91E63, // Pink
    0xFF9C27B0, // Purple
    0xFF673AB7, // Deep Purple
    0xFF3F51B5, // Indigo
    0xFF2196F3, // Blue
    0xFF03A9F4, // Light Blue
    0xFF00BCD4, // Cyan
    0xFF009688, // Teal
    0xFF4CAF50, // Green
    0xFF8BC34A, // Light Green
    0xFFCDDC39, // Lime
    0xFFFFEB3B, // Yellow
    0xFFFFC107, // Amber
    0xFFFF9800, // Orange
    0xFFFF5722, // Deep Orange
    0xFF795548, // Brown
    0xFF9E9E9E, // Grey
    0xFF607D8B, // Blue Grey
  ];

  final List<IconData> _presetIcons = [
    Icons.shopping_cart,
    Icons.restaurant,
    Icons.directions_car,
    Icons.home,
    Icons.health_and_safety,
    Icons.movie,
    Icons.school,
    Icons.work,
    Icons.monetization_on,
    Icons.flight,
    Icons.fitness_center,
    Icons.pets,
    Icons.child_friendly,
    Icons.card_giftcard,
    Icons.wifi,
    Icons.local_grocery_store,
    Icons.local_cafe,
    Icons.local_bar,
    Icons.local_pizza,
    Icons.local_laundry_service,
    Icons.checkroom, // Clothes
    Icons.electrical_services,
    Icons.plumbing,
    Icons.build,
    Icons.computer,
    Icons.phone_android,
    Icons.videogame_asset,
    Icons.book,
    Icons.library_music,
    Icons.local_hospital,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      _selectedColor = widget.category!.color ?? 0xFF6C63FF;
      _selectedIconCode = widget.category!.iconCode ?? Icons.category.codePoint;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.category == null ? "New Category" : "Edit Category",
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20.h),
            TextField(
              controller: _nameController,
              style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary),
              decoration: InputDecoration(
                labelText: "Category Name",
                labelStyle: TextStyle(color: isDark ? Colors.white54 : AppColors.lightTextSecondary),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: isDark ? Colors.white24 : AppColors.lightBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(_selectedColor)),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Text("Color", style: TextStyle(color: isDark ? Colors.white70 : AppColors.lightTextSecondary)),
            SizedBox(height: 10.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: _presetColors.map((c) {
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = c),
                  child: Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: _selectedColor == c
                          ? Border.all(color: isDark ? Colors.white : AppColors.lightTextPrimary, width: 3)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 20.h),
            Text("Icon", style: TextStyle(color: isDark ? Colors.white70 : AppColors.lightTextSecondary)),
            SizedBox(height: 10.h),
            SizedBox(
              height: 200.h,
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 8.w,
                  mainAxisSpacing: 8.h,
                ),
                itemCount: _presetIcons.length,
                itemBuilder: (context, index) {
                  final icon = _presetIcons[index];
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedIconCode = icon.codePoint),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _selectedIconCode == icon.codePoint
                            ? Color(_selectedColor).withValues(alpha: 0.3)
                            : isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(8.r),
                        border: _selectedIconCode == icon.codePoint
                            ? Border.all(color: Color(_selectedColor))
                            : null,
                      ),
                      child: Icon(
                        icon,
                        color: _selectedIconCode == icon.codePoint
                            ? Color(_selectedColor)
                            : isDark ? Colors.white54 : AppColors.lightTextSecondary,
                        size: 24.sp,
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 20.h),
            ElevatedButton(
              onPressed: () {
                if (_nameController.text.trim().isEmpty) return;

                final finalModel = CategoryModel(
                  id: widget.category?.id ?? '',
                  name: _nameController.text.trim(),
                  color: _selectedColor,
                  iconCode: _selectedIconCode,
                );

                widget.onSave(finalModel);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(_selectedColor),
                padding: EdgeInsets.symmetric(vertical: 12.h),
              ),
              child: Text(
                "Save",
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
