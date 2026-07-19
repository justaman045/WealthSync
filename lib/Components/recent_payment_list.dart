import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:money_control/Components/tx_tile.dart';
import 'package:get/get.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Components/empty_state.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Components/shimmer_loading.dart';

class RecentPaymentList extends StatefulWidget {
  final Color? cardColor;
  final Color? textColor;
  final Color? receivedColor;
  final Color? sentColor;

  const RecentPaymentList({
    super.key,
    this.cardColor,
    this.textColor,
    this.receivedColor,
    this.sentColor,
  });

  @override
  State<RecentPaymentList> createState() => _RecentPaymentListState();
}

class _RecentPaymentListState extends State<RecentPaymentList> {
  bool _entranceAnimationDone = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(
        child: Text("Not logged in",
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      );
    }

    if (!Get.isRegistered<TransactionController>()) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0),
        child: TransactionListShimmer(),
      );
    }
    final controller = Get.find<TransactionController>();

    return Obx(() {
      if (controller.isLoading.value) {
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: TransactionListShimmer(),
        );
      }

      if (controller.transactions.isEmpty) {
        return EmptyStateWidget(
          title: "No Transactions",
          subtitle: kIsWeb
              ? "Could not load transactions. Tap retry to try again."
              : "You haven't made any transactions yet.",
          icon: Icons.receipt_long_outlined,
          actionLabel: kIsWeb ? "Retry" : null,
          onAction: kIsWeb
              ? () {
                  controller.bindTransactions();
                  controller.bindCategories();
                }
              : null,
        );
      }

      final recentTxs = controller.transactions
          .where(
            (txn) => txn.senderId == user.uid || txn.recipientId == user.uid,
          )
          .take(8)
          .toList();

      if (recentTxs.isEmpty) {
        return const EmptyStateWidget(
          title: "No Transactions",
          subtitle: "You haven't made any transactions yet.",
          icon: Icons.receipt_long_outlined,
        );
      }

      final isDark = Theme.of(context).brightness == Brightness.dark;
      final txTextColor = isDark ? Colors.white : Colors.black87;

      final shouldAnimate = !_entranceAnimationDone;
      if (shouldAnimate) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _entranceAnimationDone = true);
        });
      }

      return GlassContainer(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        borderRadius: BorderRadius.circular(24.r),
        child: Column(
          children: recentTxs.asMap().entries.map((entry) {
            final index = entry.key;
            final tx = entry.value;
            final bool received = tx.recipientId == user.uid;

            final tile = TxTile(
              key: ValueKey(tx.id),
              tx: tx,
              received: received,
              textColor: txTextColor,
              receivedColor: AppColors.success,
              sentColor: AppColors.error,
            );

            if (!shouldAnimate) return tile;

            return tile
                .animate(
                  key: ValueKey('anim_${tx.id}'),
                  delay: (index * 50).ms,
                )
                .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                .slideY(
                  begin: 0.2,
                  end: 0,
                  duration: 300.ms,
                  curve: Curves.easeOut,
                );
          }).toList(),
        ),
      );
    });
  }
}
