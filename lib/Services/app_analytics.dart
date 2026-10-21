import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Canonical event names. Keep every event name here — a bare string at a call
/// site drifts silently (`paywall_view` vs `paywallView`) and the two become
/// different funnels in the console with no error anywhere.
class AnalyticsEvent {
  AnalyticsEvent._();

  // Onboarding / activation funnel
  static const String onboardingStarted = 'onboarding_started';
  static const String onboardingCompleted = 'onboarding_completed';
  static const String signupCompleted = 'signup_completed';
  static const String loginCompleted = 'login_completed';

  // Core loop
  static const String transactionAdded = 'transaction_added';
  static const String transactionSearched = 'transaction_searched';
  static const String accountLinked = 'account_linked';

  // Monetization
  static const String paywallViewed = 'paywall_viewed';
  static const String paywallDismissed = 'paywall_dismissed';
  static const String purchaseStarted = 'purchase_started';
  static const String purchaseCompleted = 'purchase_completed';
  static const String trialStarted = 'trial_started';

  // Retention
  static const String referralApplied = 'referral_applied';
  static const String exportUsed = 'export_used';

  /// The user downloaded a complete, restorable account archive. Tracked
  /// separately from [exportUsed] because the two answer different questions:
  /// an export is "I want a copy for my records", a backup is "I want to be
  /// able to get my account back" — and only the latter is a safety net.
  static const String fullBackupDownloaded = 'full_backup_downloaded';

  /// A restore from a downloaded archive completed, with how many documents
  /// came back and whether any collection failed. Logged from the *result*, not
  /// the tap, so a failed restore that reported success is visible here.
  static const String fullBackupRestored = 'full_backup_restored';

  /// A user reached a feature that an admin has set to `comingSoon` or
  /// `hidden`. This is the demand signal for what to build next, and the only
  /// way to know which of the feature flags are dead weight.
  static const String featureGateHit = 'feature_gate_hit';
}

/// Thin, typed wrapper over [FirebaseAnalytics] and [FirebaseCrashlytics].
///
/// Two rules this exists to enforce:
///
/// 1. **Never throw.** Analytics is diagnostics; a failed `logEvent` must not
///    take down the flow that called it. Every method swallows and debug-prints.
/// 2. **Never block.** Calls are fire-and-forget — no call site awaits them.
///
/// On web the JS SDK has the same ordering constraint as Firestore (see the
/// b815/ca9 note in AGENTS.md), so [init] is called from `main.dart` only after
/// the persistent listeners exist, and this class does not subscribe to
/// anything itself.
class AppAnalytics {
  AppAnalytics._();

  static FirebaseAnalytics? _analytics;
  static bool _enabled = false;

  /// True once [init] has run on a platform that supports analytics.
  static bool get isEnabled => _enabled;

  /// Overridable so tests can assert what was logged without Firebase.
  @visibleForTesting
  static void Function(String name, Map<String, Object>? params)? debugLogHook;

  /// Binds the Firebase Analytics instance. Safe to call more than once.
  ///
  /// [enabled] is false in integration tests (`mainCommon(isTest: true)`), which
  /// keeps test traffic out of the production funnel.
  static void init({required bool enabled}) {
    if (!enabled) {
      _enabled = false;
      return;
    }
    try {
      _analytics = FirebaseAnalytics.instance;
      _enabled = true;
    } catch (e) {
      // Unsupported platform, or Firebase not initialised yet.
      debugPrint('AppAnalytics: unavailable ($e)');
      _enabled = false;
    }
  }

  /// Logs a named event. [params] values must be `String`/`num`/`bool` —
  /// anything else is dropped rather than throwing at the call site.
  static void log(String name, [Map<String, Object?>? params]) {
    final safe = _sanitize(params);
    debugLogHook?.call(name, safe);
    if (!_enabled) {
      debugPrint('AppAnalytics: $name ${safe ?? ''}');
      return;
    }
    try {
      _analytics?.logEvent(name: name, parameters: safe);
    } catch (e) {
      debugPrint('AppAnalytics: logEvent failed ($e)');
    }
  }

  /// Records a non-fatal with context. Use this for caught errors that
  /// currently only reach a `debugPrint` and are therefore invisible in
  /// release builds.
  static void recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
    Map<String, Object?>? context,
  }) {
    if (kDebugMode) {
      debugPrint('AppAnalytics.recordError[$reason]: $error');
    }
    try {
      // Nullable values are dropped rather than stringified — `purchase.productID`
      // and friends are `String?`, and requiring non-null here forces a `!` at
      // the call site. Values are stringified because Crashlytics' `information`
      // wants strings.
      final info = context?.entries
          .where((e) => e.value != null)
          .map((e) => '${e.key}=${e.value}')
          .toList();
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: reason,
        fatal: fatal,
        information: (info == null || info.isEmpty) ? const <String>[] : info,
      );
    } catch (e) {
      debugPrint('AppAnalytics: recordError failed ($e)');
    }
  }

  /// Attaches the signed-in user so crashes/events can be grouped per account.
  /// **Must be cleared on sign-out** — see the note in `disposeUserScopedState`.
  static void setUserId(String? uid) {
    try {
      FirebaseCrashlytics.instance.setUserIdentifier(uid ?? '');
    } catch (e) {
      debugPrint('AppAnalytics: setUserId failed ($e)');
    }
  }

  /// Whether Crashlytics collection is on. Debug builds are excluded so a
  /// developer's hot-reload crash never lands in the production dashboard.
  static void configureCollection() {
    try {
      FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
    } catch (e) {
      debugPrint('AppAnalytics: configureCollection failed ($e)');
    }
  }

  /// `logEvent` rejects non-primitive parameter values; drop them instead of
  /// letting the SDK throw into a UI flow.
  static Map<String, Object>? _sanitize(Map<String, Object?>? params) {
    if (params == null || params.isEmpty) return null;
    final out = <String, Object>{};
    params.forEach((k, v) {
      if (v == null) return;
      if (v is String || v is num || v is bool) {
        out[k] = v;
      }
    });
    return out.isEmpty ? null : out;
  }
}
