import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Required so the plugins the background isolate needs are registered on
    // the headless engine's registry. `callbackDispatcher` in
    // lib/Services/background_worker.dart boots a separate Dart isolate, whose
    // registry is NOT the one populated by GeneratedPluginRegistrant below —
    // without this callback the isolate starts with no Firebase/SharedPreferences
    // and the periodic SMS auto-import / expense reminder silently no-op on
    // iOS. (Android needs no equivalent: WorkManager starts the worker itself.)
    //
    // The BGTaskScheduler launch handlers and the scheduled task itself are
    // registered by the plugin at schedule time and again on every app launch
    // (workmanager_apple >= 0.9.1), so no further native registration is
    // needed here.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
