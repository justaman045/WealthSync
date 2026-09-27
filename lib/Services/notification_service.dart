import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:money_control/Platform/notification_platform.dart';
import 'package:money_control/Services/feature_flag_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Master on/off for ALL app notifications (in-app + background). Lives in
/// SharedPreferences so both the foreground [NotificationService] and the
/// WorkManager isolate can read it.
const String notificationsMasterEnabledKey = 'notifications_all_enabled';

/// Per-channel toggle prefix — the full preference key is
/// `notif_enabled_<channelId>` so each notification channel can be muted
/// independently while `hidden` on the global `notifications` flag is the
/// admin-level kill switch.
const String notificationChannelEnabledKeyPrefix = 'notif_enabled_';
String notificationChannelEnabledKey(String channelId) =>
    '$notificationChannelEnabledKeyPrefix$channelId';

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
    String? payload,
  }) async {
    // Many callers fire this without awaiting (a subscription status change, a
    // budget alert). A throw — plugin not registered, no Android channel, a
    // prefs read failure — would then surface as an unhandled async error in
    // whatever unrelated code happened to be running. A failed notification is
    // never worth that, so this boundary swallows everything and logs.
    try {
      await _showNotification(
        title: title,
        body: body,
        channelId: channelId,
        channelName: channelName,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Notification "$title" could not be shown: $e');
    }
  }

  static Future<void> _showNotification({
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    String? payload,
  }) async {
    // Kill-switch: a `hidden` notifications flag (admin) suppresses ALL
    // notification posting — no display and no Firestore history entry.
    if (Get.isRegistered<FeatureFlagService>() &&
        FeatureFlagService.to.isHidden('notifications')) {
      return;
    }
    // User prefs: master toggle + per-channel toggle (Settings → General →
    // Notifications). Missing keys default to on so old installs keep working.
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(notificationsMasterEnabledKey) ?? true)) return;
    if (!(prefs.getBool(notificationChannelEnabledKey(channelId)) ?? true)) {
      return;
    }

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
      payload: payload,
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
