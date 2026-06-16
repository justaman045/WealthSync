// Stub for flutter_local_notifications on web

// ignore_for_file: unused_import

class AndroidFlutterLocalNotificationsPlugin {
  Future<bool?> requestNotificationsPermission() async => false;
}

class FlutterLocalNotificationsPlugin {
  Future<void> initialize(
    covariant InitializationSettings settings, {
    void Function(NotificationResponse)? onDidReceiveNotificationResponse,
  }) async {}
  Future<void> show(int id, String? title, String? body,
      NotificationDetails? details,
      {String? payload}) async {}
  dynamic resolvePlatformSpecificImplementation<T>() => null;
}

class AndroidNotificationDetails {
  final String channelId;
  final String channelName;
  final String? channelDescription;
  final Importance? importance;
  final Priority? priority;
  final String? ticker;
  final dynamic styleInformation;
  AndroidNotificationDetails(this.channelId, this.channelName,
      {this.channelDescription,
      this.importance,
      this.priority,
      this.ticker,
      this.styleInformation});
}

class InitializationSettings {
  final AndroidInitializationSettings? android;
  const InitializationSettings({this.android});
}

class AndroidInitializationSettings {
  final String? defaultIcon;
  const AndroidInitializationSettings(this.defaultIcon);
}

class NotificationDetails {
  final AndroidNotificationDetails? android;
  NotificationDetails({this.android});
}

class NotificationResponse {
  String? get payload => '';
}

class Importance {
  static const max = Importance._();
  const Importance._();
}

class Priority {
  static const high = Priority._();
  const Priority._();
}

class BigTextStyleInformation {
  final String bigText;
  BigTextStyleInformation(this.bigText);
}
