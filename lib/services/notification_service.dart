import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'game_api.dart';

final _localNotifications = FlutterLocalNotificationsPlugin();
StreamSubscription<RemoteMessage>? _foregroundMessages;
StreamSubscription<String>? _tokenRefreshes;

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationService {
  NotificationService._();

  static bool _ready = false;
  static GameApi? _api;

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
      const channel = AndroidNotificationChannel(
        'general_notifications',
        'اعلان‌های سوپر بازی',
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
      _tokenRefreshes ??= FirebaseMessaging.instance.onTokenRefresh.listen((
        token,
      ) {
        final api = _api;
        if (api != null && api.hasSession) {
          unawaited(_registerToken(api, token));
        }
      });
      _ready = true;
    } catch (_) {
      // The game remains usable on devices without Firebase or Google Play services.
      _ready = false;
    }
  }

  static Future<void> sync(GameApi api) async {
    if (!_ready || !api.hasSession) return;
    _api = api;
    try {
      final permission = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final authorized =
          permission.authorizationStatus == AuthorizationStatus.authorized ||
          permission.authorizationStatus == AuthorizationStatus.provisional;
      if (!authorized) return;
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _registerToken(api, token);
    } catch (_) {
      // Registration retries at the next app start and when FCM refreshes it.
    }
  }

  static Future<void> _registerToken(GameApi api, String token) async {
    try {
      final info = await PackageInfo.fromPlatform();
      await api.registerPushToken(token, info.version, info.buildNumber);
    } catch (_) {
      // A token refresh must never interrupt the active game session.
    }
  }

  static Future<void> _showMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title?.trim().isNotEmpty == true
        ? notification!.title!
        : 'سوپر بازی';
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
          'اعلان‌های سوپر بازی',
          channelDescription: 'اطلاع‌رسانی مسابقه‌ها و پیام‌های مدیریت',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_notification',
        ),
      ),
    );
  }
}
