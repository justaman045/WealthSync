import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Screens/Settings/general_settings.dart';
import 'package:money_control/Services/background_worker.dart';
import 'package:money_control/Services/sms_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('autoImportWatermarkKey', () {
    test('formats the per-user prefs key', () {
      expect(
        SmsService.autoImportWatermarkKey('a@b.com'),
        'last_sms_scan_ms_a@b.com',
      );
    });
  });

  group('setAutoImportEnabled', () {
    test('enabling flips the flag and seeds the watermark to ~now', () async {
      SharedPreferences.setMockInitialValues({'user_email': 'auto@test.com'});
      final before = DateTime.now().millisecondsSinceEpoch;

      await SmsService.setAutoImportEnabled(true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(SmsService.autoImportEnabledKey), isTrue);
      final ms = prefs.getInt('last_sms_scan_ms_auto@test.com');
      expect(ms, isNotNull);
      expect(ms, inInclusiveRange(before, DateTime.now().millisecondsSinceEpoch));
    });

    test('re-enabling overwrites the previous watermark (new enable time)',
        () async {
      SharedPreferences.setMockInitialValues({
        'user_email': 'auto@test.com',
        'last_sms_scan_ms_auto@test.com': 987654321,
      });

      await SmsService.setAutoImportEnabled(true);

      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt('last_sms_scan_ms_auto@test.com');
      expect(ms, isNot(987654321));
      expect(ms, greaterThan(987654321));
    });

    test('disabling flips the flag but leaves the watermark untouched',
        () async {
      SharedPreferences.setMockInitialValues({
        'user_email': 'auto@test.com',
        'last_sms_scan_ms_auto@test.com': 123456789,
      });

      await SmsService.setAutoImportEnabled(false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(SmsService.autoImportEnabledKey), isFalse);
      // Turning off never rescans history; the watermark only moves when
      // re-enabled.
      expect(prefs.getInt('last_sms_scan_ms_auto@test.com'), 123456789);
    });

    test('enabling without a known email still flips the flag (no backfill)',
        () async {
      await SmsService.setAutoImportEnabled(true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(SmsService.autoImportEnabledKey), isTrue);
      // No user_email in prefs and no Firebase auth in tests -> no watermark
      // written; the background importer's missing-watermark default (start
      // from now) prevents any historical backfill.
      expect(prefs.getKeys(), contains(SmsService.autoImportEnabledKey));
    });
  });

  group('resolveSmsScanStart', () {
    test('missing watermark (0) starts from now, never epoch', () {
      final now = DateTime(2026, 1, 15, 12);
      expect(resolveSmsScanStart(lastScanMs: 0, now: now), now);
    });

    test('negative watermark is treated as a seed', () {
      final now = DateTime(2026, 2, 1, 9);
      expect(resolveSmsScanStart(lastScanMs: -1, now: now), now);
    });

    test('a stored watermark is honored', () {
      final ms = DateTime(2026, 1, 10, 8, 30).millisecondsSinceEpoch;
      expect(
        resolveSmsScanStart(lastScanMs: ms),
        DateTime.fromMillisecondsSinceEpoch(ms),
      );
    });
  });

  group('nextSmsAutoImportEstimate', () {
    test('null when never scanned', () {
      expect(nextSmsAutoImportEstimate(lastScanMs: 0), isNull);
      expect(nextSmsAutoImportEstimate(lastScanMs: -1), isNull);
    });

    test('projects watermark + scan interval', () {
      final base = DateTime(2026, 1, 10, 8, 30).millisecondsSinceEpoch;
      expect(
        nextSmsAutoImportEstimate(lastScanMs: base),
        DateTime.fromMillisecondsSinceEpoch(base + smsScanInterval.inMilliseconds),
      );
    });

    test('estimate tracks the smsScanInterval const', () {
      expect(smsScanInterval, const Duration(minutes: 15));
    });
  });

  group('formatCountdown', () {
    test('zero renders as 00:00', () {
      expect(formatCountdown(Duration.zero), '00:00');
    });

    test('clamps negative to 00:00', () {
      expect(formatCountdown(const Duration(seconds: -5)), '00:00');
    });

    test('sub-hour renders as mm:ss', () {
      expect(formatCountdown(const Duration(seconds: 61)), '01:01');
      expect(formatCountdown(const Duration(minutes: 14, seconds: 32)), '14:32');
    });

    test('past an hour renders as h:mm:ss', () {
      expect(
        formatCountdown(
          const Duration(hours: 1, minutes: 2, seconds: 3),
        ),
        '1:02:03',
      );
    });
  });
}