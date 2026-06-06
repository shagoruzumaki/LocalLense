import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    debugPrint("Handling a background message: ${message.messageId}");
  }

  static Future<void> init() async {
    // 1. Request permissions
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Initialize local notifications for foreground display
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    
    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        _handleNotificationClick(details.payload);
      },
    );

    // 3. Save/Update FCM Token
    await updateToken();

    // 4. Listen for token refreshes
    _fcm.onTokenRefresh.listen((newToken) => updateToken(newToken));

    // 5. Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 6. Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        showNotification(
          title: message.notification!.title ?? '',
          body: message.notification!.body ?? '',
          payload: message.data['type'] ?? 'general',
        );
      }
    });

    // 7. Handle notification taps (Background & Terminated state)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationClick(message.data['type']);
    });

    _fcm.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _handleNotificationClick(message.data['type']);
      }
    });
  }

  /// Updates the FCM token in Supabase for the current user
  static Future<void> updateToken([String? token]) async {
    try {
      final fcmToken = token ?? await _fcm.getToken();
      if (fcmToken == null) return;

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client
            .from('users')
            .update({'fcm_token': fcmToken})
            .eq('id', user.id);
        debugPrint('FCM Token updated successfully');
      }
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }

  /// Handles routing/logic for specific notification types
  static void _handleNotificationClick(String? type) {
    if (type == null) return;
    
    debugPrint("Notification Clicked with Type: $type");
    
    // logic based on specific types
    switch (type) {
      case 'tier_upgrade':
        // Navigate to Profile or Badge page
        break;
      case 'reward_unlocked':
        // Navigate to Rewards page
        break;
      case 'verification':
        // Navigate to Verification status page
        break;
      case 'top10_updated':
      case 'nearby_top10':
        // Navigate to Rankings page
        break;
      case 'review_voted':
        // Navigate to the specific review or notification center
        break;
      default:
        debugPrint("Unhandled notification type: $type");
    }
  }

  /// Show a local notification
  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'locallens_general',
        'General Notifications',
        importance: Importance.high,
        priority: Priority.high,
        color: Color(0xFFFFD700),
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: payload,
    );
  }
}
