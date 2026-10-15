import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards against the `if (guard) { }` regression: an early-return guard whose
/// body lost its `return;` is invisible to `flutter analyze` and to every
/// behavioural test, because the guarded action simply runs anyway.
///
/// That exact shape shipped to master inside a feature-flag kill-switch (three
/// flags that could no longer hide their screen) and in front of a
/// `Get.find<SubscriptionController>()` that throws when the controller is not
/// registered — while the suite was fully green. This test is the only thing
/// that catches it, so it is deliberately a source scan rather than a widget
/// test.
bool _hasEmptyIfBody(String source) {
  for (final match in RegExp(r'\bif\s*\(').allMatches(source)) {
    final open = match.end - 1; // index of '('
    var depth = 0;
    var close = -1;
    for (var i = open; i < source.length; i++) {
      final c = source[i];
      if (c == '(') {
        depth++;
      } else if (c == ')') {
        depth--;
        if (depth == 0) {
          close = i;
          break;
        }
      }
    }
    if (close < 0) continue;

    // The empty-body signature is a `{` immediately after the condition, i.e.
    // with only whitespace in between. `if (mounted) setState(() {});` must NOT
    // match, because its braces belong to setState, not the if.
    var j = close + 1;
    while (j < source.length && (source[j] == ' ' || source[j] == '\t')) {
      j++;
    }
    if (j >= source.length || source[j] != '{') continue;

    var braceDepth = 0;
    var end = -1;
    for (var k = j; k < source.length; k++) {
      final c = source[k];
      if (c == '{') {
        braceDepth++;
      } else if (c == '}') {
        braceDepth--;
        if (braceDepth == 0) {
          end = k;
          break;
        }
      }
    }
    if (end < 0) continue;
    if (source.substring(j + 1, end).trim().isEmpty) return true;
  }
  return false;
}

void main() {
  test('no lib/ source has an empty if body (a guard that lost its return)', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (_hasEmptyIfBody(entity.readAsStringSync())) {
        offenders.add(entity.path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'These files contain `if (...) { }` — restore the early return:\n'
          '${offenders.join('\n')}',
    );
  });

  test('the scanner itself detects an empty if body', () {
    // Guard the guard: a scanner that silently matches nothing would let the
    // regression return unnoticed.
    expect(
      _hasEmptyIfBody('''
void f() {
  if (!ready) {
  }
  doThing();
}
'''),
      isTrue,
    );
  });

  test('the scanner detects a single-line empty if body', () {
    expect(
      _hasEmptyIfBody('''
void f() {
  if (!ready) {}
  doThing();
}
'''),
      isTrue,
    );
    expect(
      _hasEmptyIfBody('''
void f() {
  if (!ensureFeatureVisible(context, 'key')) { }
  doThing();
}
'''),
      isTrue,
    );
    expect(
      _hasEmptyIfBody('''
void f() {
  if (!ready) {} else { doThing(); }
}
'''),
      isTrue,
    );
  });

  test('the scanner ignores an if with a real body', () {
    expect(
      _hasEmptyIfBody('''
void f() {
  if (!ready) {
    return;
  }
  doThing();
}
'''),
      isFalse,
    );
  });

  test('the scanner ignores other intentionally empty blocks', () {
    // `catch {}` and bare `{}` are idiomatic; only `if` is the regression.
    expect(
      _hasEmptyIfBody('''
void f() {
  try { risky(); } catch (_) {}
  for (var i in xs) {}
}
'''),
      isFalse,
    );
  });
}
