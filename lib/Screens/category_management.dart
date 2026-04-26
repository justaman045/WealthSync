import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Models/cateogary.dart';
import 'package:money_control/Services/category_service.dart';
import 'package:money_control/Utils/icon_helper.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Controllers/subscription_controller.dart';
import 'package:money_control/Components/pro_lock_widget.dart';

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
            // Check Limit
            final subCtrl = Get.find<SubscriptionController>();
            final txCtrl = Get.find<TransactionController>();

            if (!subCtrl.isPro && txCtrl.categories.length >= 10) {
              Navigator.pop(context); // Close dialog
              showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF1A1A2E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24.r),
                  ),
                ),
                builder: (context) => const ProLockWidget(
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
    final navigator = Navigator.of(context);
    Get.defaultDialog(
      title: "Delete Category",
      middleText: "Are you sure you want to delete '${category.name}'?",
      textConfirm: "Delete",
      textCancel: "Cancel",
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: () async {
        await _categoryService.deleteCategory(category.id);
        navigator.pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "Manage Categories",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1A1A2E),
              const Color(0xFF16213E).withValues(alpha: 0.95),
            ],
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
                    style: TextStyle(color: Colors.white),
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
                    style: TextStyle(color: Colors.white54),
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
                color: Colors.white,
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
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E2C),
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
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20.h),
            TextField(
              controller: _nameController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Category Name",
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(_selectedColor)),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Text("Color", style: TextStyle(color: Colors.white70)),
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
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 20.h),
            Text("Icon", style: TextStyle(color: Colors.white70)),
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
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8.r),
                        border: _selectedIconCode == icon.codePoint
                            ? Border.all(color: Color(_selectedColor))
                            : null,
                      ),
                      child: Icon(
                        icon,
                        color: _selectedIconCode == icon.codePoint
                            ? Color(_selectedColor)
                            : Colors.white54,
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
                  color: Colors.white,
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
