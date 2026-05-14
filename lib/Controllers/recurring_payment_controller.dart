import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:money_control/Models/recurring_payment_model.dart';
import 'package:money_control/Services/cache_service.dart';
import 'package:money_control/Services/recurring_service.dart';

class RecurringPaymentController extends GetxController {
  static RecurringPaymentController get to => Get.find();

  final RecurringService _service = RecurringService();
  final _auth = FirebaseAuth.instance;
  final RxDouble pendingSubscriptions = 0.0.obs;

  String? get _userEmail => _auth.currentUser?.email;
  String get _cacheKey => 'recurring_${_userEmail ?? ''}';

  @override
  void onInit() {
    super.onInit();
    _loadFromCache();
    _fetchFromFirestore();
  }

  void _loadFromCache() {
    final cached = LocalCacheService.get(_cacheKey);
    if (cached != null) {
      final list = (cached as List).map((e) {
        final map = LocalCacheService.hiveRestore(Map<String, dynamic>.from(e as Map));
        final id = map.remove('_id') as String? ?? '';
        return RecurringPayment.fromMap(id, map);
      }).toList();
      pendingSubscriptions.value = _computeMonthlyTotal(list);
    }
  }

  Future<void> _fetchFromFirestore() async {
    try {
      final list = await _service.getPaymentsOnce();
      if (_userEmail != null) {
        final cacheData = list.map((t) {
          final map = t.toMap();
          map['_id'] = t.id;
          return LocalCacheService.hiveSafe(map);
        }).toList();
        LocalCacheService.put(_cacheKey, cacheData, ttl: LocalCacheService.slow5m);
      }
      pendingSubscriptions.value = _computeMonthlyTotal(list);
    } catch (_) {
    }
  }

  double _computeMonthlyTotal(List<RecurringPayment> payments) {
    double total = 0;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    for (var p in payments) {
      if (!p.isActive) continue;
      if (p.nextDueDate.year == now.year && p.nextDueDate.month == now.month) {
        total += p.amount;
      } else if (p.nextDueDate.isBefore(startOfMonth)) {
        total += p.amount;
      }
    }
    return total;
  }
}
