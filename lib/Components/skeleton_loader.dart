import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Components/shimmer_loading.dart'; // Reuse base ShimmerLoading

class SkeletonBlock extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBlock({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class SkeletonCard extends StatelessWidget {
  final double? width;
  final double? height;
  final Widget? child;

  const SkeletonCard({super.key, this.width, this.height, this.child});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      width: width,
      height: height,
      padding: EdgeInsets.all(20.w),
      borderRadius: BorderRadius.circular(24.r),
      child: child ?? const SizedBox.shrink(),
    );
  }
}

// -----------------------------------------------------
// WEALTH BUILDER SKELETON
// Net Worth Card + Asset Grid
// -----------------------------------------------------
class WealthSkeleton extends StatelessWidget {
  const WealthSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Net Worth Card
          SkeletonCard(
            height: 180.h,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBlock(width: 120.w, height: 16.h),
                SizedBox(height: 20.h),
                SkeletonBlock(width: 200.w, height: 40.h),
                const Spacer(),
                SkeletonBlock(width: 150.w, height: 14.h),
              ],
            ),
          ),
          SizedBox(height: 30.h),

          // Section Title
          SkeletonBlock(width: 100.w, height: 20.h),
          SizedBox(height: 16.h),

          // Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              childAspectRatio: 0.8,
            ),
            itemCount: 6,
            itemBuilder: (context, index) {
              return SkeletonCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SkeletonBlock(width: 30.w, height: 30.w, radius: 15),
                        SizedBox(width: 10.w),
                        SkeletonBlock(width: 60.w, height: 12.h),
                      ],
                    ),
                    const Spacer(),
                    SkeletonBlock(width: 100.w, height: 24.h),
                    SizedBox(height: 8.h),
                    SkeletonBlock(width: 80.w, height: 10.h),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------
// AI INSIGHTS SKELETON
// Forecast Card + Daily Limit + Heatmap
// -----------------------------------------------------
class InsightsSkeleton extends StatelessWidget {
  const InsightsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Forecast Card (Total Budget)
          SkeletonCard(
            height: 200.h,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonBlock(width: 140.w, height: 16.h),
                    SkeletonBlock(width: 24.w, height: 24.w, radius: 12),
                  ],
                ),
                SizedBox(height: 20.h),
                SkeletonBlock(width: 180.w, height: 42.h),
                SizedBox(height: 20.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonBlock(width: 80.w, height: 14.h),
                    SkeletonBlock(width: 80.w, height: 14.h),
                  ],
                ),
                const Spacer(),
                SkeletonBlock(width: double.infinity, height: 30.h, radius: 10),
              ],
            ),
          ),
          SizedBox(height: 20.h),

          // Daily Limit Card
          SkeletonCard(
            height: 140.h,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBlock(width: 180.w, height: 18.h),
                SizedBox(height: 20.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBlock(width: 100.w, height: 12.h),
                        SizedBox(height: 8.h),
                        SkeletonBlock(width: 60.w, height: 20.h),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SkeletonBlock(width: 100.w, height: 12.h),
                        SizedBox(height: 8.h),
                        SkeletonBlock(width: 60.w, height: 20.h),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),

          // Heatmap Placeholder
          SkeletonCard(
            height: 200.h,
            width: double.infinity,
            child: Center(
              child: SkeletonBlock(width: 300.w, height: 150.h),
            ),
          ),
        ],
      ),
    );
  }
}
