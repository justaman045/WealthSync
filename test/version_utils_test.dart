import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Utils/version_utils.dart';

void main() {
  group('isNewerVersion()', () {
    test('detects a higher patch/minor/major', () {
      expect(isNewerVersion('2.0.161', '2.0.156'), isTrue);
      expect(isNewerVersion('2.1.0', '2.0.999'), isTrue);
      expect(isNewerVersion('3.0.0', '2.9.9'), isTrue);
    });

    test('equal versions are not newer', () {
      expect(isNewerVersion('2.0.161', '2.0.161'), isFalse);
    });

    test('older remote is not newer', () {
      expect(isNewerVersion('2.0.156', '2.0.161'), isFalse);
      expect(isNewerVersion('1.9.9', '2.0.0'), isFalse);
    });

    test('ignores a leading v tag prefix', () {
      expect(isNewerVersion('v2.0.161', '2.0.161'), isFalse);
      expect(isNewerVersion('v2.0.161', '2.0.156'), isTrue);
      expect(isNewerVersion('V2.0.161', '2.0.156'), isTrue);
    });

    test('ignores +build and -suffix qualifiers', () {
      expect(isNewerVersion('2.0.161+161', '2.0.161'), isFalse);
      expect(isNewerVersion('2.0.161+161', '2.0.156+156'), isTrue);
      expect(isNewerVersion('2.0.161-beta', '2.0.161'), isFalse);
      expect(isNewerVersion('2.0.161-beta', '2.0.160'), isTrue);
    });

    test('treats missing components as zero', () {
      expect(isNewerVersion('2.1', '2.1.0'), isFalse);
      expect(isNewerVersion('2.1', '2.0.9'), isTrue);
      expect(isNewerVersion('2.0.1', '2'), isTrue);
      expect(isNewerVersion('2', '2.0.0'), isFalse);
    });

    test('unparseable components fall back to zero instead of throwing', () {
      expect(isNewerVersion('', '2.0.0'), isFalse);
      expect(isNewerVersion('abc', '2.0.0'), isFalse);
      expect(isNewerVersion('2.x.1', '2.0.0'), isTrue);
    });

    test('trims surrounding whitespace', () {
      expect(isNewerVersion(' 2.0.161 ', ' 2.0.156 '), isTrue);
    });
  });
}
