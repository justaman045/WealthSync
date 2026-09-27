import 'package:flutter/foundation.dart';

/// Whether the app is running on a real Android build.
///
/// Uses [defaultTargetPlatform] rather than `dart:io`'s `Platform.isAndroid`
/// because importing `dart:io` breaks the web (GitHub Pages) build. Paired with
/// `!kIsWeb` so a mobile browser — which also reports
/// `TargetPlatform.android` — is never treated as native Android.
///
/// Needed wherever a capability is implemented as an Android-only native
/// plugin and would otherwise be offered on iOS:
///   * UPI payments — Kotlin MethodChannel `money_control/upi`
///   * SMS reading/import — `sms_maintained` / `permission_handler`, no iOS
///     entitlement or `PERMISSION_SMS` pod macro is configured
bool get isAndroidPlatform =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
