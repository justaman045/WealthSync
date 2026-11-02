import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Services/widget_action_queue.dart';
import 'package:money_control/Services/widget_service.dart';
import 'package:money_control/Utils/widget_action.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The home-screen widget is tappable while the app is locked, signed out or
/// mid-onboarding, so a tap must never be routed from the plugin listener.
/// These checks pin the queue-and-route-once-ready design, the widget's own
/// settings round trip, and the Android side that has to honour them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseWidgetAction', () {
    test('the + Add deep link maps to a transaction', () {
      expect(
        parseWidgetAction(Uri.parse('homeWidget://add_transaction')),
        WidgetAction.addTransaction,
      );
    });

    test('a plain body tap carries no action', () {
      // The body is a launcher intent with no URI: the app just opens.
      expect(parseWidgetAction(null), isNull);
    });

    test('unknown hosts are ignored instead of guessed', () {
      expect(parseWidgetAction(Uri.parse('homeWidget://home')), isNull);
      expect(parseWidgetAction(Uri.parse('homeWidget://open')), isNull);
      expect(parseWidgetAction(Uri.parse('homeWidget://add_transactions')), isNull);
      expect(parseWidgetAction(Uri.parse('https://add_transaction')), isNull);
    });
  });

  group('WidgetActionQueue', () {
    setUp(WidgetActionQueue.reset);

    test('a queued action is handed over exactly once', () {
      WidgetActionQueue.push(WidgetAction.addTransaction);
      expect(WidgetActionQueue.take(), WidgetAction.addTransaction);
      expect(WidgetActionQueue.take(), isNull);
      expect(WidgetActionQueue.pending.value, isNull);
    });

    test('a newer tap supersedes a waiting one', () {
      WidgetActionQueue.push(WidgetAction.addTransaction);
      WidgetActionQueue.push(WidgetAction.addTransaction);
      expect(WidgetActionQueue.take(), WidgetAction.addTransaction);
      expect(WidgetActionQueue.take(), isNull);
    });

    test('readiness is remembered until the shell says otherwise', () {
      expect(WidgetActionQueue.ready.value, isFalse);
      WidgetActionQueue.markReady(true);
      expect(WidgetActionQueue.ready.value, isTrue);
      WidgetActionQueue.markReady(false);
      expect(WidgetActionQueue.ready.value, isFalse);
    });
  });

  group('widget settings', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('the shortcut defaults to shown', () async {
      expect(await WidgetService.showQuickAdd(), isTrue);
    });

    test('hiding the shortcut survives a reload', () async {
      // The plugin channel is absent in a unit test; the preference must be
      // written before that call so the switch never reverts on relaunch.
      await WidgetService.updateSettings(showQuickAdd: false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(WidgetService.showQuickAddKey), isFalse);
      expect(await WidgetService.showQuickAdd(), isFalse);
    });
  });

  group('the tap is never routed from the listener', () {
    test('main.dart queues the action and gates it on the shell', () {
      final source = File('lib/main.dart').readAsStringSync();

      final start = source.indexOf('void _initWidgetClickHandling()');
      final end = source.indexOf('/// Routes a queued widget action');
      expect(start, greaterThan(0));
      expect(end, greaterThan(start));
      final listener = source.substring(start, end);

      // Both cold and warm taps go through the pure parser and the queue.
      expect(listener, contains('parseWidgetAction(uri)'));
      expect(listener, contains('WidgetActionQueue.push'));
      // A direct navigation here is the bug: it lands on top of the splash,
      // the login screen or the biometric lock.
      expect(listener, isNot(contains('PaymentScreen')));
      expect(listener, isNot(contains('Get.to')));

      // The flush refuses to run before the shell is on screen and unlocked.
      expect(source, contains('if (!WidgetActionQueue.ready.value) return;'));
      expect(source, contains('_bioService.lockActive'));
    });

    test('sign-out drops a queued tap', () {
      final source =
          File('lib/Controllers/auth_controller.dart').readAsStringSync();
      final teardown = source.indexOf('disposeUserScopedState()');
      expect(teardown, greaterThan(0));
      expect(
        source.substring(teardown),
        contains('WidgetActionQueue.reset()'),
        reason: 'a tap queued for one account must not fire for the next',
      );
    });

    test('the auth checker publishes readiness for the main shell only', () {
      final source = File('lib/main.dart').readAsStringSync();
      expect(source, contains('_markShellReady(true);'));
      expect(source, contains('_markShellReady(false);'));

      // Ready must be flipped in the onboarded branch, not in the splash or
      // the login-screen branch.
      final readyIndex = source.indexOf('_markShellReady(true);');
      final onboardedIndex = source.indexOf('if (isOnboarded) {');
      expect(onboardedIndex, greaterThan(0));
      expect(readyIndex, greaterThan(onboardedIndex));
    });
  });

  group('the preview matches the real widget', () {
    test('its mock + Add replays the widget action', () {
      final source =
          File('lib/Screens/home_widget_preview.dart').readAsStringSync();
      expect(source, contains('WidgetActionQueue.push'));
      expect(source, contains('WidgetAction.addTransaction'));
      // The old copy claimed the whole widget opened the add screen; only the
      // + Add shortcut does.
      expect(source, contains('homeWidgetStepTapBody'));
      expect(source, contains('homeWidgetQuickAddTitle'));
    });

    test('Android applies the shortcut setting and keeps tap intents immutable', () {
      final kotlin = File(
        'android/app/src/main/kotlin/app/vercel/justaman045/money_control/'
        'MoneyControlWidget.kt',
      ).readAsStringSync();

      expect(kotlin, contains('mc_show_quick_add'));
      expect(kotlin, contains('R.id.widget_tap_hint'));
      expect(kotlin, contains('View.GONE'));
      // A mutable PendingIntent on Android 12+ throws; keep it explicit.
      expect(kotlin, contains('PendingIntent.FLAG_IMMUTABLE'));
      expect(kotlin, contains('homeWidget://add_transaction'));
      // Body tap stays a plain launch, matching `parseWidgetAction(null)`.
      expect(kotlin, contains('Intent(context, MainActivity::class.java)'));
    });
  });
}
