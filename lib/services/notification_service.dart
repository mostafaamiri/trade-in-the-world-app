import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'game_api.dart';

final _localNotifications = FlutterLocalNotificationsPlugin();
StreamSubscription<RemoteMessage>? _foregroundMessages;

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationService {
  NotificationService._();

  static bool _ready = false;

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
      const channel = AndroidNotificationChannel(
        'general_notifications',
        'اعلان‌های تجارت در جهان',
        description: 'اطلاع‌رسانی مسابقه‌ها و پیام‌های مدیریت',
        importance: Importance.high,
      );
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_notification'),
      );
      await _localNotifications.initialize(settings);
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
      _foregroundMessages ??= FirebaseMessaging.onMessage.listen(_showMessage);
      _ready = true;
    } catch (_) {
      // The game remains usable on devices without Firebase or Google Play services.
      _ready = false;
    }
  }

  static Future<void> sync(GameApi api) async {
    if (!_ready || !api.hasSession) return;
    try {
      final permission = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (permission.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      final info = await PackageInfo.fromPlatform();
      await api.registerPushToken(token, info.version, info.buildNumber);
    } catch (_) {
      // Push registration is non-blocking and retries at the next app start.
    }
  }

  static Future<void> _showMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title?.trim().isNotEmpty == true
        ? notification!.title!
        : 'تجارت در جهان';
    final body = notification?.body?.trim().isNotEmpty == true
        ? notification!.body!
        : message.data['body']?.toString() ?? '';
    if (body.isEmpty) return;
    await _localNotifications.show(
      message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'general_notifications',
          'اعلان‌های تجارت در جهان',
          channelDescription: 'اطلاع‌رسانی مسابقه‌ها و پیام‌های مدیریت',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_notification',
        ),
      ),
    );
  }
}
