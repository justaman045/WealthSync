import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The dues chip used to render "- - ₹1,200 due": the ARB string already starts
/// with the minus sign, so the call site only has to supply the amount. Adding a
/// prefix at the call site is invisible to `analyze` and to every math test —
/// this asserts the convention from both ends so it cannot come back.
void main() {
  final arb = jsonDecode(
    File('lib/l10n/app_en.arb').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('the localized dues label owns its leading minus', () {
    expect(arb['balanceDuesDue'] as String, startsWith('- '));
    expect(arb['balanceDuesHidden'] as String, startsWith('- '));
    expect(arb['balanceNoDues'] as String, startsWith('- '));
  });

  test('the call site does not add a second minus', () {
    final source = File('lib/Components/balance_card.dart').readAsStringSync();
    final call = RegExp(r'balanceDuesDue\((.*?)\)\,', dotAll: true)
        .firstMatch(source);
    expect(call, isNotNull, reason: 'balanceDuesDue call site disappeared');
    expect(
      call!.group(1),
      isNot(contains("'- ")),
      reason: 'the ARB value already starts with "- "; pass the amount only',
    );
  });
}
