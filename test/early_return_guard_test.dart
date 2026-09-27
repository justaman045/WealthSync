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
  final lines = source.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (!line.startsWith('if (') && !line.startsWith('if(')) continue;
    if (!line.endsWith('{')) continue;
    // An `if (...) {` is empty when the next non-blank line closes it. A single
    // statement on the following line means the body is real.
    for (var j = i + 1; j < lines.length && j < i + 3; j++) {
      final next = lines[j].trim();
      if (next.isEmpty) continue;
      if (next == '}' || next == '};') return true;
      break;
    }
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

  test('the scanner does not flag an if with a real body', () {
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
