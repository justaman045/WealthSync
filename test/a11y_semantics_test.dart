import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Components/section_title.dart';
import 'package:money_control/Config/app_strings.dart';

// The home screen's AppBar is a row of icon-only buttons. Without explicit
// semantics a screen reader announces them all as the same anonymous
// "button", and a user has no way to tell the search action from the
// goals action. These tests pin the three ways that regress:
//
//   1. a new AppBar button added without a `semanticLabel`,
//   2. an ARB key that resolves to an empty or duplicate label, and
//   3. the "View All" link losing its button role.
//
// The first is a source contract (the whole home screen is far too
// Firebase-bound to mount in a unit test); the second reads the ARB
// directly; the third is a real widget test, because SectionTitle has no
// dependencies at all.

/// Returns the call expression that starts at the opening parenthesis at
/// [openIndex], matching nested parentheses and ignoring string literals.
String _callAt(String source, int openIndex) {
  var depth = 0;
  var i = openIndex;
  var inSingleQuote = false;
  var inDoubleQuote = false;

  while (i < source.length) {
    final c = source[i];
    if (inSingleQuote) {
      if (c == r'\') {
        i += 2;
        continue;
      }
      if (c == "'") inSingleQuote = false;
    } else if (inDoubleQuote) {
      if (c == r'\') {
        i += 2;
        continue;
      }
      if (c == '"') inDoubleQuote = false;
    } else if (c == "'") {
      inSingleQuote = true;
    } else if (c == '"') {
      inDoubleQuote = true;
    } else if (c == '(') {
      depth++;
    } else if (c == ')') {
      depth--;
      if (depth == 0) return source.substring(openIndex, i + 1);
    }
    i++;
  }
  return source.substring(openIndex);
}

void main() {
  group('home AppBar action buttons', () {
    test('every action button passes a semantic label', () {
      final source = File('lib/Screens/homescreen.dart').readAsStringSync();

      // Everything before the helper's own definition is the call sites.
      final body = source.split('Widget _buildActionButton(').first;

      final calls = <String>[];
      var index = body.indexOf('_buildActionButton(');
      while (index != -1) {
        final open = body.indexOf('(', index);
        calls.add(_callAt(body, open));
        index = body.indexOf('_buildActionButton(', index + 1);
      }

      expect(calls, isNotEmpty, reason: 'no call sites found');
      expect(calls.length, greaterThanOrEqualTo(7));

      for (final call in calls) {
        expect(
          call,
          contains('semanticLabel:'),
          reason:
              'an AppBar action button has no semanticLabel — a screen '
              'reader would announce it as an anonymous button:\n$call',
        );
      }
    });
  });

  group('accessibility strings', () {
    late Map<String, dynamic> arb;

    setUpAll(() {
      arb =
          jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
              as Map<String, dynamic>;
    });

    Map<String, dynamic> a11yLabels() => {
      for (final entry in arb.entries)
        if (entry.key.startsWith('a11y')) entry.key: entry.value,
    };

    test('every a11y label is present and non-empty', () {
      final labels = a11yLabels();
      expect(labels, isNotEmpty, reason: 'no a11y strings defined');

      for (final entry in labels.entries) {
        expect(
          entry.value,
          isA<String>(),
          reason: '${entry.key} is not a string',
        );
        expect(
          (entry.value as String).trim(),
          isNotEmpty,
          reason:
              '${entry.key} is an empty label — it would be announced as '
              'a blank button',
        );
      }
    });

    test('a11y labels are unique', () {
      // Two controls that announce the same thing are indistinguishable to a
      // screen reader, so a copy-pasted label is as broken as a missing one.
      final values = a11yLabels().values.toList();
      expect(values.toSet().length, values.length);
    });
  });

  group('SectionTitle', () {
    // NOTE: flutter_test renders every glyph as a full-width box, so text is
    // far wider than it is on a device. The title is kept short so the row
    // fits — the test is about semantics, not layout.
    Future<void> pumpTitle(
      WidgetTester tester, {
      required String title,
      VoidCallback? onTap,
    }) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            home: Scaffold(
              body: SectionTitle(title: title, onTap: onTap),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the "View All" link is announced as a button', (tester) async {
      await pumpTitle(tester, title: 'Recent', onTap: () {});

      final handle = tester.getSemantics(find.text(AppStrings.viewAll));
      expect(
        handle,
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          label: AppStrings.viewAll,
        ),
      );
    });

    testWidgets('a title with no action has no "View All" link', (
      tester,
    ) async {
      await pumpTitle(tester, title: 'Recent');

      expect(find.text(AppStrings.viewAll), findsNothing);
    });
  });
}
