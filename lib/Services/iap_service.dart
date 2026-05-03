import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:get/get.dart';
import 'package:money_control/Controllers/subscription_controller.dart';
import 'package:money_control/Services/error_handler.dart';

class IapService {
  static final IapService _instance = IapService._internal();
  factory IapService() => _instance;
  IapService._internal();

  static const String kMonthlyId = 'money_control_monthly';
  static const String kYearlyId = 'money_control_yearly';
  static const Set<String> _productIds = {kMonthlyId, kYearlyId};

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  final RxList<ProductDetails> products = <ProductDetails>[].obs;
  final RxBool isAvailable = false.obs;
  final RxBool isLoading = false.obs;

  Future<void> init() async {
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

  Future<void> buySubscription(String productId) async {
    final product = products.firstWhereOrNull((p) => p.id == productId);
    if (product == null) {
      ErrorHandler.showError(
        'Product not available. Please check your connection and try again.',
      );
      return;
    }
    isLoading.value = true;
    final param = PurchaseParam(productDetails: product);
    try {
      await _iap.buyNonConsumable(purchaseParam: param);
      // isLoading is reset in _handlePurchases after outcome is known
    } catch (e) {
      isLoading.value = false;
      ErrorHandler.showError('Failed to initiate purchase. Please try again.');
    }
  }

  Future<void> restorePurchases() async {
    isLoading.value = true;
    await _iap.restorePurchases();
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          // Payment initiated but not completed (e.g. UPI redirect in progress)
          continue;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          await SubscriptionController.to.activateGooglePlaySubscription(
            purchase,
          );
          break;

        case PurchaseStatus.error:
          ErrorHandler.showError(
            purchase.error?.message ?? 'Purchase failed. Please try again.',
          );
          break;

        case PurchaseStatus.canceled:
          // User dismissed the payment sheet — do nothing
          break;
      }
    }
    isLoading.value = false;
  }

  void dispose() {
    _purchaseSub?.cancel();
  }
}
