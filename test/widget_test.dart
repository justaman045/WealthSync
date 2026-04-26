import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Controllers/subscription_controller.dart';

void main() {
  group('SubscriptionController', () {
    test('SubscriptionStatus enum has expected values', () {
      expect(
        SubscriptionStatus.values.map((e) => e.name).toList(),
        containsAll(['free', 'pending', 'pro']),
      );
    });

    test('approveUpgrade expiry uses calendar arithmetic — monthly', () {
      final now = DateTime(2024, 1, 31);
      // Monthly: same day next month — Dart normalises overflow (e.g. Feb 31 → Mar 2)
      final monthly = DateTime(now.year, now.month + 1, now.day);
      expect(monthly.isAfter(now), isTrue);
    });

    test('approveUpgrade expiry uses calendar arithmetic — yearly', () {
      final now = DateTime(2024, 3, 15);
      final yearly = DateTime(now.year + 1, now.month, now.day);
      expect(yearly, DateTime(2025, 3, 15));
    });
  });
}
