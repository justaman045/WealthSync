// Stub for in_app_purchase on web
import 'dart:async';

class InAppPurchase {
  static InAppPurchase get instance => _instance;
  static final _instance = InAppPurchase._();
  InAppPurchase._();

  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();

  Future<bool> isAvailable() async => false;
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(<ProductDetails>[], []);
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
  }) async =>
      false;
  Future<bool> buyNonConsumable({
    required PurchaseParam purchaseParam,
  }) async =>
      false;
  Future<bool> restorePurchases() async => false;
  Future<bool> completePurchase(PurchaseDetails details) async => false;
}

class ProductDetails {
  final String id;
  final String title;
  final String description;
  final String price;
  final String currencySymbol;
  final String currencyCode;
  final double rawPrice;
  ProductDetails({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.currencySymbol,
    required this.currencyCode,
    this.rawPrice = 0,
  });
}

class ProductDetailsResponse {
  final List<ProductDetails> productDetails;
  final List<String> notFoundIDs;
  ProductDetailsResponse(this.productDetails, this.notFoundIDs);
}

class PurchaseDetails {
  final String? productID;
  final String? purchaseID;
  final PurchaseVerificationData verificationData;
  final String? transactionDate;
  final PurchaseStatus status;
  final bool pendingCompletePurchase;
  final IAPError? error;
  PurchaseDetails({
    this.productID,
    this.purchaseID,
    PurchaseVerificationData? verificationData,
    this.transactionDate,
    this.status = PurchaseStatus.purchased,
    this.pendingCompletePurchase = false,
    this.error,
  }) : verificationData = verificationData ?? PurchaseVerificationData();
}

class PurchaseVerificationData {
  final String serverVerificationData;
  final String localVerificationData;
  final String source;
  PurchaseVerificationData({
    this.serverVerificationData = '',
    this.localVerificationData = '',
    this.source = '',
  });
}

class PurchaseParam {
  final ProductDetails productDetails;
  final String? applicationUserName;
  PurchaseParam({required this.productDetails, this.applicationUserName});
}

class IAPError {
  final String message;
  IAPError(this.message);
}

enum PurchaseStatus {
  purchased,
  error,
  pending,
  canceled,
  restored,
}
