import 'package:get/get.dart';
import 'package:money_control/Utils/widget_action.dart';

/// Holds a widget tap until the app can actually honour it.
///
/// The widget is live even on the lock screen, during the splash, on the login
/// screen and while onboarding is unfinished. Routing straight from the widget
/// listener pushed the add-transaction screen *over* the login screen, so the
/// user signed in behind a floating payment sheet they never asked for. Actions
/// are queued here instead and drained by the root widget once the signed-in
/// main shell owns the frame (and the biometric lock, if any, is open).
class WidgetActionQueue {
  WidgetActionQueue._();

  /// The latest tap, if one is still waiting. A newer tap supersedes an older
  /// one: the user tapped again, so the newest intent is the real one.
  static final Rx<WidgetAction?> pending = Rx<WidgetAction?>(null);

  /// True while a signed-in, onboarded user is looking at the main shell.
  /// Owned by the auth checker so "ready" includes sign-in and onboarding,
  /// not merely "a frame has been painted".
  static final RxBool ready = false.obs;

  static void push(WidgetAction action) {
    pending.value = action;
  }

  /// Returns the queued action (if any) and clears it, so a retry cannot fire
  /// the same navigation twice.
  static WidgetAction? take() {
    final action = pending.value;
    pending.value = null;
    return action;
  }

  static void markReady(bool value) {
    if (ready.value == value) return;
    ready.value = value;
  }

  /// Test hook: forget any queued action and the readiness flag.
  static void reset() {
    pending.value = null;
    ready.value = false;
  }
}
