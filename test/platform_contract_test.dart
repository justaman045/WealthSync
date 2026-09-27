import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Native/host contracts that fail *silently* when broken.
///
/// None of the mismatches below produce a Dart compile error or a failing unit
/// test — they produce a feature that simply never runs on a real device:
///   * a BGTaskScheduler identifier missing from Info.plist means iOS refuses
///     every schedule (BGTaskSchedulerErrorDomain Code 3) and background SMS
///     import / expense reminders never fire;
///   * a missing plugin-registrant callback means the background isolate boots
///     with no Firebase/SharedPreferences and its work quietly no-ops;
///   * a platform offered on a build with no native implementation behind it
///     throws MissingPluginException at the moment the user taps it.
///
/// `test/firestore_indexes_test.dart` is the same idea for composite indexes.
/// The identifier iOS uses for a periodic task: the `uniqueName` argument of
/// `registerPeriodicTask`, not the `taskName` the callback receives.
String uniqueNameFromWorker(String workerSource) {
  final match = RegExp(
    r'''registerPeriodicTask\(\s*['"]([^'"]+)['"]''',
  ).firstMatch(workerSource);
  expect(match, isNotNull, reason: 'no registerPeriodicTask call found');
  return match!.group(1)!;
}

void main() {
  late String workerSource;
  late String plist;
  late String appDelegate;

  setUpAll(() {
    workerSource = File(
      'lib/Services/background_worker.dart',
    ).readAsStringSync();
    plist = File('ios/Runner/Info.plist').readAsStringSync();
    appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
  });

  group('iOS background work', () {
    test('the periodic task identifier is declared in Info.plist', () {
      final uniqueName = uniqueNameFromWorker(workerSource);
      expect(
        plist,
        contains('BGTaskSchedulerPermittedIdentifiers'),
        reason: 'Info.plist has no BGTaskSchedulerPermittedIdentifiers key',
      );
      expect(
        plist,
        contains('<string>$uniqueName</string>'),
        reason:
            'iOS schedules "$uniqueName" but Info.plist does not advertise it. '
            'Every background schedule then fails with Code 3 and the periodic '
            'SMS auto-import / expense reminder never runs on iOS.',
      );
    });

    test('background modes are declared for BGTaskScheduler', () {
      expect(plist, contains('<key>UIBackgroundModes</key>'));
      expect(
        RegExp(r'<string>(fetch|processing)</string>').hasMatch(plist),
        isTrue,
        reason: 'UIBackgroundModes must include fetch and/or processing',
      );
    });

    test('AppDelegate wires the background plugin registrant', () {
      expect(
        appDelegate,
        contains('setPluginRegistrantCallback'),
        reason:
            'the background isolate runs in its own registry; without this '
            'callback it has no Firebase/SharedPreferences and silently no-ops',
      );
      expect(appDelegate, contains('GeneratedPluginRegistrant.register'));
    });

    test('AppDelegate imports the federated Apple module that exists', () {
      // workmanager split into workmanager_android / workmanager_apple at 0.8.0.
      // Importing the retired "workmanager_ios" module breaks the iOS build.
      expect(appDelegate, contains('import workmanager_apple'));
      expect(
        appDelegate.contains('import workmanager_ios'),
        isFalse,
        reason: 'workmanager_ios is not a module in workmanager >= 0.8.0',
      );
    });
  });

  group('Android-only capabilities', () {
    test('UPI entry points are gated on a real Android build', () {
      // dart:io's Platform would break the web build, so the gate has to go
      // through the shared helper.
      for (final path in [
        'lib/Screens/add_transaction.dart',
        'lib/Screens/homescreen.dart',
      ]) {
        expect(
          File(path).readAsStringSync(),
          contains('isAndroidPlatform'),
          reason: '$path offers an Android-only native feature ungated',
        );
      }
      expect(
        File('lib/Utils/platform_support.dart').readAsStringSync(),
        contains('defaultTargetPlatform'),
        reason: 'the helper must stay web-safe (no dart:io)',
      );
    });

    test('the SMS import screen refuses non-Android builds', () {
      final source = File('lib/Screens/sms_import_screen.dart').readAsStringSync();
      expect(source, contains('isAndroidPlatform'));
    });
  });
}
