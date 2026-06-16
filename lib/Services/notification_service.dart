import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:money_control/Platform/notification_platform.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init({
    void Function(NotificationResponse)? onDidReceiveNotificationResponse,
  }) async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings can be added here
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    String channelId = 'general_notifications',
    String channelName = 'General Notifications',
  }) async {
    // 1. Show Local Notification
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'General app notifications',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
          styleInformation: BigTextStyleInformation(body),
        );

    NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      DateTime.now().microsecondsSinceEpoch % 2147483647, // unique id
      title,
      body,
      platformChannelSpecifics,
    );

    // 2. Persist to Firestore
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.email)
            .collection('notifications')
            .add({
              'title': title,
              'body': body,
              'timestamp': FieldValue.serverTimestamp(),
              'read': false,
              'type': channelId,
            });
      }
    } catch (e) {
      // Fail silently for persistence so we don't crash app flow
      debugPrint("Error saving notification: $e");
    }
  }
}
