// Stub for home_widget on web
import 'dart:async';

class HomeWidgetData {
  final String id;
  final dynamic value;
  HomeWidgetData(this.id, this.value);
}

class HomeWidget {
  static Future<void> saveWidgetData<T>(String id, T? data) async {}
  static Future<void> updateWidget(
      {String? androidName, String? iosName}) async {}
  static Future<void> setAppGroupId(String id) async {}
  static Future<Uri?> initiallyLaunchedFromHomeWidget() async => null;
  static Stream<Uri> get widgetClicked => const Stream.empty();
}
