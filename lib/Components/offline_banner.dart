import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Services/connectivity_controller.dart';

/// Slim full-width banner shown while the device has no network. Renders
/// nothing (zero height) when online so it adds no layout cost in the common
/// case.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ConnectivityController>()) {
      return const SizedBox.shrink();
    }
    return Obx(() {
      if (ConnectivityController.to.isOnline.value) {
        return const SizedBox.shrink();
      }
      return Material(
        color: AppColors.error,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  "You're offline — changes will sync when you reconnect.",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
