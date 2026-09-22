import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  debugPrint('[FCM BACKGROUND] Message ID: ${message.messageId}, Data: ${message.data}');
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;
  static String? _fcmToken;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'mediq_live_channel',
    'MEDIQ Live Chamber Notifications',
    description: 'Real-time alerts for appointments, queue calls, doctor breaks and delays',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static String? get fcmToken => _fcmToken;

  /// Initialize Firebase & Local Notifications
  static Future<void> initialize({GlobalKey<NavigatorState>? navigatorKey}) async {
    if (_isInitialized) return;

    try {
      // 1. Initialize Firebase Core
      await Firebase.initializeApp();

      // 2. Set Background Handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 3. Request Notification Permissions
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('[FCM] User notification permission status: ${settings.authorizationStatus}');

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 4. Setup Local Notifications for Foreground Alerts (Android & iOS)
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
      );


      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('[FCM LOCAL TAP] Payload: ${response.payload}');
          if (response.payload != null && response.payload!.isNotEmpty) {
            _handleNotificationPayload(response.payload);
          }
        },
      );

      // 5. Create Android Notification Channel
      final androidPlatform = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        await androidPlatform.createNotificationChannel(_channel);
        try {
          await androidPlatform.requestNotificationsPermission();
        } catch (e) {
          debugPrint('[FCM PERM ERROR] $e');
        }
      }

      // 6. Foreground Notification Listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM FOREGROUND] Title: ${message.notification?.title}, Body: ${message.notification?.body}');
        _showForegroundNotification(message);
      });

      // 7. Background Tap Listener
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM OPENED APP] Message: ${message.data}');
        _handleNotificationData(message.data);
      });

      // 8. Terminated App Tap
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCM INITIAL MESSAGE] Message: ${initialMessage.data}');
        _handleNotificationData(initialMessage.data);
      }

      // 9. Retrieve and save FCM Token
      try {
        _fcmToken = await messaging.getToken();
        debugPrint('[FCM TOKEN] $_fcmToken');
        await syncTokenWithBackend();
      } catch (e) {
        debugPrint('[FCM TOKEN ERROR] $e');
      }

      // 10. Listen for Token Refresh
      messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        syncTokenWithBackend();
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('[FCM INIT ERROR] $e');
    }
  }

  /// Show Heads-up banner when notification arrives in Foreground
  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;

    final title = notification?.title ?? message.data['title'] ?? 'MEDIQ Notification';
    final body = notification?.body ?? message.data['body'] ?? '';

    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.high,
      icon: android?.smallIcon ?? '@mipmap/ic_launcher',
      color: const Color(0xFF246BFD),
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(body),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );


    final id = message.messageId.hashCode;
    final payload = jsonEncode(message.data);

    await _localNotifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformDetails,
      payload: payload,
    );
  }

  /// Handle Notification Payload Routing
  static void _handleNotificationPayload(String? payloadStr) {
    if (payloadStr == null || payloadStr.isEmpty) return;
    try {
      final data = jsonDecode(payloadStr) as Map<String, dynamic>;
      _handleNotificationData(data);
    } catch (_) {}
  }

  static void _handleNotificationData(Map<String, dynamic> data) {
    final target = data['target_screen']?.toString() ?? '';
    debugPrint('[FCM ROUTING] Target screen: $target, Data: $data');
    // Can be used for custom navigation or event bus dispatch
  }

  /// Sync device FCM Token with Backend
  static Future<void> syncTokenWithBackend() async {
    try {
      if (_fcmToken == null || _fcmToken!.isEmpty) {
        _fcmToken = await FirebaseMessaging.instance.getToken();
      }
      if (_fcmToken == null || _fcmToken!.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();

      // Check if user is logged in (auth_token is primary in Mediq)
      final token = prefs.getString('auth_token') ?? prefs.getString('access_token') ?? ApiService.authToken;
      if (token == null || token.isEmpty) {
        debugPrint('[FCM SYNC] User not logged in yet, skipping device token sync.');
        return;
      }

      if (ApiService.authToken == null || ApiService.authToken!.isEmpty) {
        ApiService.authToken = token;
      }

      final userDataStr = prefs.getString('user_data');
      String userKey = '';
      if (userDataStr != null && userDataStr.isNotEmpty) {
        try {
          final userMap = jsonDecode(userDataStr);
          userKey = '${userMap['id']}_';
        } catch (_) {}
      }

      final syncKey = 'last_synced_fcm_${userKey}_$_fcmToken';
      if (prefs.getBool(syncKey) == true) {
        debugPrint('[FCM SYNC] Device token already synced for user: $userKey');
        return;
      }

      final deviceType = Platform.isAndroid ? 'ANDROID' : (Platform.isIOS ? 'IOS' : 'WEB');

      await ApiService.post('/users/device-token', {
        'fcm_token': _fcmToken,
        'device_type': deviceType,
        'device_name': Platform.operatingSystemVersion,
      });

      await prefs.setBool(syncKey, true);
      debugPrint('[FCM SYNC] Successfully synced device token with backend.');
    } catch (e) {
      debugPrint('[FCM SYNC ERROR] $e');
    }
  }
}