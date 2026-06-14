import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // 1. Initialize local notifications
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

    // Note: Firebase Messaging (FCM) removed. 
    // To implement push notifications using Supabase, 
    // you would typically use Supabase Edge Functions to trigger 
    // notifications via FCM or another provider, but since we are 
    // removing Firebase, we'll keep only local notification logic.
  }

  /// Handles routing/logic for specific notification types
  static void _handleNotificationClick(String? type) {
    if (type == null) return;
    
    debugPrint("Notification Clicked with Type: $type");
    
    // logic based on specific types
    switch (type) {
      case 'tier_upgrade':
        break;
      case 'reward_unlocked':
        break;
      case 'verification':
        break;
      case 'top10_updated':
      case 'nearby_top10':
        break;
      case 'review_voted':
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
