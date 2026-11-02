import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Switches shipped with an invisible thumb: 13 call sites set
/// `activeThumbColor: AppColors.primary`, the same colour the theme uses for
/// the selected **track**, so the thumb and track merged into one solid pill
/// and "on" read as "no thumb at all". The theme in `Components/colors.dart`
/// already draws an `onPrimary` thumb on a `primary` track, so call sites must
/// not override the thumb colour at all. `activeThumbColor` is also deprecated.
///
/// A source scan is deliberate: a `Switch` with the wrong thumb colour is
/// perfectly valid Flutter and no widget test asserts on it.
void main() {
  test('no screen overrides a switch thumb colour', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // The theme itself is where the thumb colour is *supposed* to be set.
      if (entity.path.endsWith('lib/Components/colors.dart')) continue;

      final source = entity.readAsStringSync();
      for (final line in source.split('\n')) {
        if (line.contains('activeThumbColor')) {
          offenders.add('${entity.path}: ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Switch thumb colour belongs in switchTheme, not at the call '
          'site:\n${offenders.join('\n')}',
    );
  });
}
