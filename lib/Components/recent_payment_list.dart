import 'package:money_control/l10n/app_localizations.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:money_control/Components/tx_tile.dart';
import 'package:get/get.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Components/empty_state.dart';

import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Components/shimmer_loading.dart';
import 'package:money_control/Utils/animation.dart';

class RecentPaymentList extends StatefulWidget {
  final Color? textColor;
  final Color? receivedColor;
  final Color? sentColor;

  const RecentPaymentList({
    super.key,
    this.textColor,
    this.receivedColor,
    this.sentColor,
  });

  @override
  State<RecentPaymentList> createState() => _RecentPaymentListState();
}

class _RecentPaymentListState extends State<RecentPaymentList> {
  bool _entranceAnimationDone = false;
  Timer? _entranceTimer;

  @override
  void dispose() {
    _entranceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final l10n = AppLocalizations.of(context)!;
    if (user == null) {
      return Center(
        child: Text(
          l10n.logged,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
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
      // `transactions.isEmpty` is true on every cold start, which used to make
      // the home screen claim "You haven't made any transactions yet" before
      // the first snapshot arrived. Only trust emptiness after a load.
      if (!controller.hasLoadedOnce.value) {
        if (controller.isStreamDead.value) {
          return EmptyStateWidget(
            title: l10n.homeDataUnavailableTitle,
            subtitle: l10n.homeDataUnavailableSubtitle,
            icon: Icons.cloud_off_rounded,
            actionLabel: l10n.retry,
            onAction: () => controller.refreshData(),
          );
        }
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: TransactionListShimmer(),
        );
      }

      final recentTxs = controller.recentTransactions;
      if (recentTxs.isEmpty) {
        return EmptyStateWidget(
          title: l10n.noTransactions,
          subtitle: l10n.noTransactionsSubtitle,
          icon: Icons.receipt_long_outlined,
        );
      }

      final isDark = Theme.of(context).brightness == Brightness.dark;
      final txTextColor =
          widget.textColor ?? (isDark ? Colors.white : Colors.black87);

      final shouldAnimate = !_entranceAnimationDone;
      if (shouldAnimate) {
        // Flip the flag only after the stagger + fade has finished. Flipping
        // it in a post-frame callback tore the wrappers down on the very next
        // frame, so the entrance animation never actually played.
        _entranceTimer?.cancel();
        _entranceTimer = Timer(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          setState(() => _entranceAnimationDone = true);
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
              receivedColor: widget.receivedColor ?? AppColors.success,
              sentColor: widget.sentColor ?? AppColors.error,
            );

            if (!shouldAnimate) return tile;

            return animatedItem(tile, index, slide: true);
          }).toList(),
        ),
      );
    });
  }
}
