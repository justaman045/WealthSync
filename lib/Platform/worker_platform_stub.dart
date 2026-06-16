// Stub for workmanager on web
import 'dart:async';

class Workmanager {
  static Workmanager? _instance;
  factory Workmanager() => _instance ??= Workmanager._();
  Workmanager._();
  Future<void> initialize(void Function() callbackDispatcher,
      {bool isInDebugMode = false}) async {}
  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    Duration frequency = const Duration(minutes: 15),
    dynamic existingWorkPolicy,
  }) async {}
  Future<bool> executeTask(
      Future<bool> Function(String, String?) callback) async {
    return true;
  }
}

class ExistingPeriodicWorkPolicy {
  static const update = ExistingPeriodicWorkPolicy._();
  const ExistingPeriodicWorkPolicy._();
}
