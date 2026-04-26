import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:money_control/Components/glass_container.dart';

class ShimmerLoading extends StatelessWidget {
  final Widget child;
  const ShimmerLoading({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.grey[300]!,
      highlightColor: isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.grey[100]!,
      child: child,
    );
  }
}

class TransactionListShimmer extends StatelessWidget {
  const TransactionListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: List.generate(5, (index) => const _ShimmerItem()));
  }
}

class _ShimmerItem extends StatelessWidget {
  const _ShimmerItem();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: GlassContainer(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            ShimmerLoading(
              child: Container(
                width: 40.w,
                height: 40.w,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerLoading(
                    child: Container(
                      width: 120.w,
                      height: 16.h,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  ShimmerLoading(
                    child: Container(
                      width: 80.w,
                      height: 12.h,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            ShimmerLoading(
              child: Container(width: 60.w, height: 20.h, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class ForecastShimmer extends StatelessWidget {
  const ForecastShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ShimmerLoading(
          child: Container(
            width: 150.w,
            height: 30.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        ),
        SizedBox(height: 30.h),
        _sectionShim(),
        SizedBox(height: 16.h),
        _cardShim(),
        SizedBox(height: 12.h),
        _cardShim(),
        SizedBox(height: 40.h),
        _sectionShim(),
        SizedBox(height: 16.h),
        _cardShim(),
        SizedBox(height: 12.h),
        _cardShim(),
      ],
    );
  }

  Widget _sectionShim() {
    return ShimmerLoading(
      child: Row(
        children: [
          Container(width: 4, height: 16, color: Colors.white),
          SizedBox(width: 8.w),
          Container(width: 60.w, height: 16.h, color: Colors.white),
          SizedBox(width: 8.w),
          Expanded(child: Container(height: 1, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _cardShim() {
    return GlassContainer(
      padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 20.w),
      borderRadius: BorderRadius.circular(24.r),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              ShimmerLoading(
                child: Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              ShimmerLoading(
                child: Container(
                  width: 100.w,
                  height: 16.h,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          ShimmerLoading(
            child: Container(width: 80.w, height: 20.h, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
