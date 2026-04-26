import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyController extends GetxController {
  static CurrencyController get to => Get.find();

  final RxString currencyCode = "INR".obs;
  final RxString currencySymbol = "₹".obs;

  @override
  void onInit() {
    super.onInit();
    _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    currencyCode.value = prefs.getString('currency_code') ?? "INR";
    currencySymbol.value = prefs.getString('currency_symbol') ?? "₹";
  }

  Future<void> setCurrency(String code, String symbol) async {
    currencyCode.value = code;
    currencySymbol.value = symbol;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency_code', code);
    await prefs.setString('currency_symbol', symbol);
  }
}
