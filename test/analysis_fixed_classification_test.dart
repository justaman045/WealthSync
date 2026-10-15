import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Utils/wealth_math.dart';

/// Guards the Smart Daily Limit classification fix.
///
/// The card splits spending into fixed vs. discretionary to compute the amount
/// left to spend. That split must be the SAME rule for the current-month
/// variable total, today's variable total, and the fixed forecast — otherwise a
/// bill recorded under a name the exact keyword set missed was counted as
/// discretionary while its forecast was still reserved, silently zeroing the
/// daily limit (the "₹0 over 17 days" report).
///
/// `analysis.dart` used to carry a local `fixedCategories` set with exact
/// `contains(cat.toLowerCase())` matching. This test pins the screen to the
/// shared, tested `isFixedExpenseCategory` helper so the two decision points
/// can never drift apart again.
void main() {
  test('analysis.dart uses the shared classifier, not a local exact-match set',
      () {
    final source = File('lib/Screens/analysis.dart').readAsStringSync();

    expect(
      source.contains('fixedCategories'),
      isFalse,
      reason: 'analysis.dart must not reintroduce the local fixedCategories set; '
          'use isFixedExpenseCategory() from wealth_math.dart',
    );

    final usages = RegExp(r'isFixedExpenseCategory\(').allMatches(source).length;
    expect(
      usages,
      greaterThanOrEqualTo(3),
      reason: 'the current-month variable total, today\'s fixed total, and the '
          'fixed forecast must all classify via isFixedExpenseCategory()',
    );
  });

  test('the shared classifier is exported and behaves', () {
    // Compile-time existence check plus a spot check.
    expect(isFixedExpenseCategory('Bills'), isTrue);
    expect(isFixedExpenseCategory('Coffee'), isFalse);
  });
}
