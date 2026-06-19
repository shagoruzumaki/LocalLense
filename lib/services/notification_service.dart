import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static GlobalKey<NavigatorState>? _navigatorKey;

  static Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;

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
  }

  /// Handles routing/logic for specific notification types
  static void _handleNotificationClick(String? type) {
    if (type == null) return;
    
    debugPrint("Notification Clicked with Type: $type");
    
    // Logic to navigate when a system notification is tapped
    _navigatorKey?.currentState?.pushNamed('/notifications');
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
