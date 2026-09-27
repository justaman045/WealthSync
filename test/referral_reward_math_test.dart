import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Services/referral_service.dart';

/// The referral payout is the only place the app grants Pro access without a
/// purchase, so its arithmetic is worth pinning down independently of
/// Firestore: an off-by-one here silently over- or under-pays every referrer.
void main() {
  final now = DateTime(2026, 3, 1);

  group('referral trial reward math', () {
    test('no claims grants nothing', () {
      expect(
        ReferralService.debugComputeTrialEnd(now: now, pendingClaims: 0),
        now,
      );
    });

    test('one claim grants 30 days', () {
      expect(
        ReferralService.debugComputeTrialEnd(now: now, pendingClaims: 1),
        now.add(const Duration(days: 30)),
      );
    });

    test('two claims grant 60 days but are capped at 45', () {
      expect(
        ReferralService.debugComputeTrialEnd(now: now, pendingClaims: 2),
        now.add(const Duration(days: 45)),
      );
    });

    test('a large claim count cannot exceed the 45 day cap', () {
      for (final claims in [3, 10, 100, 10000]) {
        expect(
          ReferralService.debugComputeTrialEnd(
            now: now,
            pendingClaims: claims,
          ),
          now.add(const Duration(days: 45)),
          reason: '$claims claims must stay clamped to the cap',
        );
      }
    });

    test('a future existing expiry is extended from its current end', () {
      final existing = now.add(const Duration(days: 12));
      expect(
        ReferralService.debugComputeTrialEnd(
          now: now,
          pendingClaims: 1,
          currentExpiry: existing,
        ),
        existing.add(const Duration(days: 30)),
      );
    });

    test('an elapsed expiry restarts from now', () {
      final elapsed = now.subtract(const Duration(days: 5));
      expect(
        ReferralService.debugComputeTrialEnd(
          now: now,
          pendingClaims: 1,
          currentExpiry: elapsed,
        ),
        now.add(const Duration(days: 30)),
      );
    });

    test('a missing expiry restarts from now', () {
      expect(
        ReferralService.debugComputeTrialEnd(
          now: now,
          pendingClaims: 1,
          currentExpiry: null,
        ),
        now.add(const Duration(days: 30)),
      );
    });

    test('an expiry already past the cap is pulled back to the cap', () {
      final farFuture = now.add(const Duration(days: 400));
      expect(
        ReferralService.debugComputeTrialEnd(
          now: now,
          pendingClaims: 1,
          currentExpiry: farFuture,
        ),
        now.add(const Duration(days: 45)),
      );
    });
  });
}
