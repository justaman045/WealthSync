import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Utils/wealth_math.dart';

/// The home balance card's headline figure is assembled from two opt-in,
/// session-only overlays. The signs are the whole point: a card that silently
/// adds dues instead of subtracting them (or vice versa) misreports someone's net
/// worth, and `flutter analyze` cannot see a wrong sign.
void main() {
  group('computeDisplayTotal', () {
    test('is the plain balance when both overlays are off', () {
      expect(
        computeDisplayTotal(balance: 5000, netLent: 900, pendingDues: 1200),
        5000,
      );
    });

    test('adds net lent money only when included', () {
      expect(
        computeDisplayTotal(balance: 5000, netLent: 900, includeLent: true),
        5900,
      );
    });

    test('subtracts pending dues only when included', () {
      expect(
        computeDisplayTotal(balance: 5000, pendingDues: 1200, includeDues: true),
        3800,
      );
    });

    test('combines both overlays in opposite directions', () {
      expect(
        computeDisplayTotal(
          balance: 5000,
          netLent: 900,
          includeLent: true,
          pendingDues: 1200,
          includeDues: true,
        ),
        4700,
      );
    });

    test('a negative net lent balance is deducted when included', () {
      // Owed-more-than-lent must reduce the headline, never inflate it.
      expect(
        computeDisplayTotal(balance: 5000, netLent: -1500, includeLent: true),
        3500,
      );
    });

    test('is not clamped: dues can take the headline negative', () {
      // Hiding a negative position would misreport it; the card shows the truth.
      expect(
        computeDisplayTotal(
          balance: 500,
          pendingDues: 1200,
          includeDues: true,
        ),
        -700,
      );
    });

    test('including dues at zero pending changes nothing', () {
      expect(
        computeDisplayTotal(balance: 5000, pendingDues: 0, includeDues: true),
        5000,
      );
    });

    test('including a zero net lent balance changes nothing', () {
      expect(
        computeDisplayTotal(balance: 5000, netLent: 0, includeLent: true),
        5000,
      );
    });

    test('dues subtract regardless of a negative starting balance', () {
      expect(
        computeDisplayTotal(
          balance: -200,
          pendingDues: 300,
          includeDues: true,
        ),
        -500,
      );
    });
  });
}
