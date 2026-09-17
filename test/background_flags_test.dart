import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Services/background_worker.dart';

void main() {
  group('resolveBackgroundFlags', () {
    const hidden = {
      'sms_auto_import': 'hidden',
      'expense_reminder': 'hidden',
      'recurring': 'enabled',
    };
    const server = {
      'sms_auto_import': 'enabled',
      'notifications': 'comingSoon',
    };
    const legacy = {'sms_auto_import': 'enabled', 'home_widget': 'hidden'};

    test('live server read is authoritative when present', () {
      final resolved = resolveBackgroundFlags(
        server: server,
        mirror: hidden,
        legacyCache: legacy,
      );
      expect(resolved, server);
    });

    test('fails CLOSED: hidden mirror values survive a failed server read', () {
      for (final source in [hidden, Map<String, String>.of(hidden)]) {
        final resolved = resolveBackgroundFlags(
          server: null,
          mirror: source,
          legacyCache: legacy,
        );
        expect(resolved['sms_auto_import'], 'hidden');
        expect(resolved['recurring'], 'enabled');
      }
    });

    test('empty mirror defers to the legacy cache', () {
      final resolved = resolveBackgroundFlags(
        server: null,
        mirror: const {},
        legacyCache: legacy,
      );
      expect(resolved, legacy);
    });

    test('no mirror and no cache defaults to all-enabled empty map', () {
      final resolved = resolveBackgroundFlags(
        server: null,
        mirror: const {},
        legacyCache: const {},
      );
      expect(resolved, isEmpty);
    });

    test('server success overrides a stale hidden mirror', () {
      final resolved = resolveBackgroundFlags(
        server: const {'sms_auto_import': 'enabled'},
        mirror: const {'sms_auto_import': 'hidden'},
        legacyCache: legacy,
      );
      expect(resolved['sms_auto_import'], 'enabled');
    });

    test('hidden key is preserved even when legacy says enabled', () {
      final resolved = resolveBackgroundFlags(
        server: null,
        mirror: const {'sms_auto_import': 'hidden'},
        legacyCache: const {'sms_auto_import': 'enabled'},
      );
      expect(resolved['sms_auto_import'], 'hidden');
    });
  });
}