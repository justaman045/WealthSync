import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Services/app_analytics.dart';

/// AppAnalytics is diagnostics: it must never throw into a UI flow and never
/// block one. These tests pin the two properties that matter — the sanitizer
/// drops values the SDK would reject, and every public method is safe to call
/// before `init()` (which is the state in tests and on unsupported platforms).
void main() {
  tearDown(() => AppAnalytics.debugLogHook = null);

  group('AppAnalytics', () {
    test('is disabled by default and log() does not throw', () {
      expect(AppAnalytics.isEnabled, isFalse);
      // Must be callable before init() — main.dart inits late, and test
      // harnesses never call it at all.
      expect(
        () => AppAnalytics.log(AnalyticsEvent.transactionAdded, {'type': 'send'}),
        returnsNormally,
      );
    });

    test('init(enabled: false) stays disabled', () {
      AppAnalytics.init(enabled: false);
      expect(AppAnalytics.isEnabled, isFalse);
    });

    test('log() forwards a sanitized payload to the debug hook', () {
      final calls = <(String, Map<String, Object>?)>[];
      AppAnalytics.debugLogHook = (name, params) => calls.add((name, params));

      AppAnalytics.log(AnalyticsEvent.paywallViewed, {
        'source': 'home',
        'scroll_to_payment': true,
        'count': 3,
      });

      expect(calls, hasLength(1));
      expect(calls.first.$1, AnalyticsEvent.paywallViewed);
      expect(calls.first.$2, {
        'source': 'home',
        'scroll_to_payment': true,
        'count': 3,
      });
    });

    /// The SDK throws on non-primitive parameter values. Since `log` is called
    /// from inside UI flows (tap handlers, initState), that throw would take
    /// down the flow — so unsupported values must be dropped, not passed.
    test('sanitizer drops nulls and non-primitive values', () {
      final calls = <(String, Map<String, Object>?)>[];
      AppAnalytics.debugLogHook = (name, params) => calls.add((name, params));

      AppAnalytics.log(AnalyticsEvent.featureGateHit, {
        'feature': 'goal_sharing',
        'dropped_null': null,
        'dropped_list': <String>['a', 'b'],
        'dropped_map': {'k': 'v'},
        'dropped_object': Object(),
      });

      final params = calls.single.$2;
      expect(params, isNotNull);
      expect(params!.keys, ['feature']);
      expect(params['feature'], 'goal_sharing');
    });

    test('an all-unusable payload logs the event with null params', () {
      final calls = <(String, Map<String, Object>?)>[];
      AppAnalytics.debugLogHook = (name, params) => calls.add((name, params));

      AppAnalytics.log(AnalyticsEvent.loginCompleted, {'x': null});

      expect(calls.single.$2, isNull);
    });

    test('params are optional', () {
      final calls = <(String, Map<String, Object>?)>[];
      AppAnalytics.debugLogHook = (name, params) => calls.add((name, params));

      AppAnalytics.log(AnalyticsEvent.loginCompleted);

      expect(calls.single.$1, AnalyticsEvent.loginCompleted);
      expect(calls.single.$2, isNull);
    });

    test('recordError/setUserId are safe with no Firebase app initialised', () {
      // In `flutter test` there is no Firebase app; a throw here would surface
      // as a test failure in whatever UI flow called it.
      expect(
        () => AppAnalytics.recordError(
          StateError('boom'),
          StackTrace.current,
          reason: 'unit',
          context: {'k': 'v'},
        ),
        returnsNormally,
      );
      expect(() => AppAnalytics.setUserId('uid-1'), returnsNormally);
      expect(() => AppAnalytics.setUserId(null), returnsNormally);
    });

    test('event names are unique — a duplicate collapses two funnels', () {
      const names = [
        AnalyticsEvent.onboardingStarted,
        AnalyticsEvent.onboardingCompleted,
        AnalyticsEvent.signupCompleted,
        AnalyticsEvent.loginCompleted,
        AnalyticsEvent.transactionAdded,
        AnalyticsEvent.transactionSearched,
        AnalyticsEvent.accountLinked,
        AnalyticsEvent.paywallViewed,
        AnalyticsEvent.paywallDismissed,
        AnalyticsEvent.purchaseStarted,
        AnalyticsEvent.purchaseCompleted,
        AnalyticsEvent.trialStarted,
        AnalyticsEvent.referralApplied,
        AnalyticsEvent.exportUsed,
        AnalyticsEvent.featureGateHit,
      ];
      expect(names.toSet(), hasLength(names.length));
      // Firebase caps event names at 40 chars and forbids spaces.
      for (final n in names) {
        expect(n.length, lessThanOrEqualTo(40), reason: n);
        expect(n.contains(' '), isFalse, reason: n);
      }
    });
  });
}
