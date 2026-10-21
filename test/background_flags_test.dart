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

  group('shouldRunDailySnapshot', () {
    // Late evening, the window the snapshot is meant to run in.
    final lateEvening = DateTime(2026, 10, 21, 22, 30);

    test('runs in the late-evening window when nothing ran today', () {
      expect(
        shouldRunDailySnapshot(
          now: lateEvening,
          lastSuccessDay: null,
          lastAttemptMs: null,
        ),
        isTrue,
      );
    });

    test('does not run before 22:00', () {
      expect(
        shouldRunDailySnapshot(
          now: DateTime(2026, 10, 21, 21, 59),
          lastSuccessDay: null,
          lastAttemptMs: null,
        ),
        isFalse,
      );
    });

    test('does not run twice on the same day', () {
      expect(
        shouldRunDailySnapshot(
          now: lateEvening,
          lastSuccessDay: '2026-10-21',
          lastAttemptMs: null,
        ),
        isFalse,
      );
    });

    test("a previous day's success does not block today", () {
      expect(
        shouldRunDailySnapshot(
          now: lateEvening,
          lastSuccessDay: '2026-10-20',
          lastAttemptMs: null,
        ),
        isTrue,
      );
    });

    test('a failed attempt is retried, but not before an hour', () {
      final recentAttempt = lateEvening.millisecondsSinceEpoch -
          const Duration(minutes: 30).inMilliseconds;
      expect(
        shouldRunDailySnapshot(
          now: lateEvening,
          lastSuccessDay: null,
          lastAttemptMs: recentAttempt,
        ),
        isFalse,
      );

      // An hour later the day is still open (the run failed), so it retries.
      final hourLater = DateTime(2026, 10, 21, 23, 30);
      expect(
        shouldRunDailySnapshot(
          now: hourLater,
          lastSuccessDay: null,
          lastAttemptMs: lateEvening.millisecondsSinceEpoch,
        ),
        isTrue,
      );
    });

    test('the retry gap is configurable', () {
      final now = DateTime(2026, 10, 21, 22, 5);
      final attempt = now.millisecondsSinceEpoch -
          const Duration(minutes: 5).inMilliseconds;
      expect(
        shouldRunDailySnapshot(
          now: now,
          lastSuccessDay: null,
          lastAttemptMs: attempt,
          minHoursBetweenAttempts: 1,
        ),
        isFalse,
      );
      expect(
        shouldRunDailySnapshot(
          now: now,
          lastSuccessDay: null,
          lastAttemptMs: attempt,
          minHoursBetweenAttempts: 0,
        ),
        isTrue,
      );
    });
  });
}