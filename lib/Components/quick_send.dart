import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Components/cateogary_initial_icon.dart';
import 'package:money_control/Components/methods.dart';
import 'package:money_control/Controllers/transaction_controller.dart';

import 'package:money_control/Screens/add_transaction.dart';

class QuickSendRow extends StatefulWidget {
  final Color? cardColor;
  final Color? textColor;

  const QuickSendRow({super.key, this.cardColor, this.textColor});

  @override
  State<QuickSendRow> createState() => _QuickSendRowState();
}

class _QuickSendRowState extends State<QuickSendRow> {
  final TransactionController _controller = Get.find<TransactionController>();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final containerColor = isDark
        ? scheme.surface.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.8);

    return Obx(() {
      if (_controller.isLoading.value) {
        return _buildShimmer(isDark, containerColor);
      }

      if (_controller.sortedCategoryNames.isEmpty) {
        // If truly empty
        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 16.w),
          decoration: BoxDecoration(
            color: containerColor,
            borderRadius: BorderRadius.circular(24.r),
          ),
          child: Center(
            child: Text(
              "No categories found",
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.6),
                fontSize: 13.sp,
              ),
            ),
          ),
        );
      }

      final topCategories = _controller.sortedCategoryNames.take(3).toList();

      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 16.w),
        decoration: BoxDecoration(
          color: containerColor,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.grey.withValues(alpha: 0.1),
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: Builder(
          builder: (context) {
            if (topCategories.length == 1) {
              return Row(
                children: [
                  Expanded(
                    child: Center(
                      child: _neonQuickSender(
                        asset: CategoryInitialsIcon(
                          categoryName: topCategories.first,
                          size: 40,
                        ),
                        name: topCategories.first,
                        color: const Color(0xFF00E5FF), // Neon Cyan
                        isDark: isDark,
                        onTap: () {
                          gotoPage(
                            PaymentScreen(
                              type: PaymentType.send,
                              cateogary: topCategories.first,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            } else {
              // Assign neon colors cyclically
              final colors = [
                const Color(0xFF00E5FF), // Cyan
                const Color(0xFFEA80FC), // Purple
                const Color(0xFFFF4081), // Pink
                const Color(0xFFFDD835), // Yellow
              ];

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: topCategories.asMap().entries.map((entry) {
                  final index = entry.key;
                  final categoryName = entry.value;
                  final color = colors[index % colors.length];

                  return _neonQuickSender(
                    asset: CategoryInitialsIcon(
                      categoryName: categoryName,
                      size: 40.r,
                    ),
                    name: categoryName,
                    color: color,
                    isDark: isDark,
                    onTap: () {
                      gotoPage(
                        PaymentScreen(
                          type: PaymentType.send,
                          cateogary: categoryName,
                        ),
                      );
                    },
                  );
                }).toList(),
              );
            }
          },
        ),
      );
    });
  }

  Widget _neonQuickSender({
    required Widget asset,
    required String name,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: asset,
          ),
          SizedBox(height: 8.h),
          SizedBox(
            width: 70.w,
            child: Text(
              name,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.9)
                    : Colors.black87,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer(bool isDark, Color containerColor) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Shimmer.fromColors(
        baseColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.1),
        highlightColor: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (index) {
            return Column(
              children: [
                Container(
                  width: 50.r,
                  height: 50.r,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(height: 8.h),
                Container(width: 40.w, height: 10.h, color: Colors.white),
              ],
            );
          }),
        ),
      ),
    );
  }
}
