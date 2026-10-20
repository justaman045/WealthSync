import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:money_control/Platform/iap_platform.dart';
import 'package:get/get.dart';
import 'package:money_control/Controllers/subscription_controller.dart';
import 'package:money_control/Services/error_handler.dart';
import 'package:money_control/Services/app_analytics.dart';

class IapService {
  static final IapService _instance = IapService._internal();
  factory IapService() => _instance;
  IapService._internal();

  static const String kMonthlyId = 'money_control_monthly';
  static const String kYearlyId = 'money_control_yearly';
  static const Set<String> _productIds = {kMonthlyId, kYearlyId};

  /// Whether [productId] is one this app actually sells. Any other id (a stale
  /// build, a different app's product, a null) must never grant a plan.
  static bool isKnownProduct(String? productId) =>
      productId != null && _productIds.contains(productId);

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  Timer? _watchdog;

  final RxList<ProductDetails> products = <ProductDetails>[].obs;
  final RxBool isAvailable = false.obs;
  final RxBool isLoading = false.obs;

  Future<void> init() async {
    // Never let a stale value from a previous session lock the buy button.
    isLoading.value = false;
    isAvailable.value = await _iap.isAvailable();
    if (!isAvailable.value) return;

    _purchaseSub = _iap.purchaseStream.listen(
      _handlePurchases,
      onError: (e) => ErrorHandler.showError('Purchase stream error: $e'),
    );

    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    final response = await _iap.queryProductDetails(_productIds);
    products.assignAll(response.productDetails);
  }

  /// Force-clears [isLoading] if a store call never resolves (emulator without
  /// Play billing, unsigned debug build, web without a configured merchant, iOS
  /// without StoreKit products). On several platforms the buy future completes
  /// at initiation and the real outcome arrives via the purchase stream, which
  /// may never emit when the store is unavailable — so a watchdog, not a future
  /// timeout, is what guarantees the subscribe button recovers.
  void _armWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 30), () {
      isLoading.value = false;
    });
  }

  void _cancelWatchdog() {
    _watchdog?.cancel();
    _watchdog = null;
  }

  Future<void> buySubscription(String productId) async {
    final product = products.firstWhereOrNull((p) => p.id == productId);
    if (product == null) {
      ErrorHandler.showError(
        'Product not available. Please check your connection and try again.',
      );
      return;
    }
    isLoading.value = true;
    _armWatchdog();
    final param = PurchaseParam(productDetails: product);
    try {
      await _iap.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      ErrorHandler.showError('Failed to initiate purchase. Please try again.');
    } finally {
      _cancelWatchdog();
      isLoading.value = false;
    }
  }

  Future<void> restorePurchases() async {
    isLoading.value = true;
    _armWatchdog();
    try {
      await _iap.restorePurchases();
    } finally {
      _cancelWatchdog();
      isLoading.value = false;
    }
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    try {
      for (final purchase in purchases) {
        switch (purchase.status) {
          case PurchaseStatus.pending:
            continue;

          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            if (!IapService.isKnownProduct(purchase.productID)) {
              // A product we don't sell (stale build / other app / null) must
              // never be completed or granted a plan.
              debugPrint(
                'Ignoring unknown IAP product: ${purchase.productID}',
              );
              continue;
            }
            if (purchase.pendingCompletePurchase) {
              await _iap.completePurchase(purchase);
            }
            AppAnalytics.log(AnalyticsEvent.purchaseCompleted, {
              'product_id': purchase.productID,
              'restored': purchase.status == PurchaseStatus.restored,
            });
            await SubscriptionController.to.activateGooglePlaySubscription(
              purchase,
            );
            break;

          case PurchaseStatus.error:
            AppAnalytics.recordError(
              purchase.error ?? StateError('IAP error'),
              StackTrace.current,
              reason: 'iap.purchaseError',
              context: {'product_id': purchase.productID},
            );
            ErrorHandler.showError(
              purchase.error?.message ?? 'Purchase failed. Please try again.',
            );
            break;

          case PurchaseStatus.canceled:
            AppAnalytics.log(AnalyticsEvent.paywallDismissed, {
              'product_id': purchase.productID,
              'reason': 'canceled',
            });
            break;
        }
      }
    } finally {
      _cancelWatchdog();
      isLoading.value = false;
    }
  }

  void dispose() {
    _cancelWatchdog();
    _purchaseSub?.cancel();
  }
}
