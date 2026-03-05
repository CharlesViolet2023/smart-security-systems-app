// =============================================================================
// notification_service.dart - Push Notification Handler (Mobile App Side)
// =============================================================================
//
// This file sets up the Android app to RECEIVE push notifications from the
// Raspberry Pi (which sends them via Firebase Cloud Messaging).
//
// HOW PUSH NOTIFICATIONS WORK:
//   1. The Raspberry Pi sends a notification to Firebase (Google's cloud)
//   2. Firebase delivers it to all phones subscribed to the "office_security" topic
//   3. This file receives the notification and displays it on the phone
//
// There are 3 scenarios for receiving notifications:
//   - App is OPEN (foreground): we manually show a local notification banner
//   - App is in BACKGROUND: Android automatically shows the notification
//   - App is CLOSED (terminated): Android shows it; tapping it opens the app
//
// SETUP:
//   This file asks the user for permission to show notifications, subscribes
//   to the "office_security" Firebase topic, and creates a notification
//   channel (Android's way of grouping notifications by category).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Manages all push notification functionality for the SmartSec app.
class NotificationService {
  // Firebase Messaging instance - handles communication with Firebase
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Local notifications plugin - used to show notification banners
  // when the app is in the foreground (Firebase can't do this automatically)
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Set up everything needed for push notifications.
  /// Called once when the app starts (from main.dart).
  Future<void> initialize() async {
    // --- Step 1: Ask the user for permission to show notifications ---
    // On Android 13+, apps must explicitly request notification permission.
    // The user will see a popup asking "Allow SmartSec to send notifications?"
    final settings = await _messaging.requestPermission(
      alert: true,        // Allow banner notifications
      badge: true,        // Allow badge count on app icon
      sound: true,        // Allow notification sounds
      criticalAlert: true, // Allow critical alerts (bypass Do Not Disturb)
    );
    debugPrint('Notification permission: ${settings.authorizationStatus}');

    // --- Step 2: Subscribe to the "office_security" topic ---
    // This tells Firebase: "Send me all notifications meant for the office security system."
    // The Raspberry Pi's notifications.py sends to this same topic.
    await _messaging.subscribeToTopic('office_security');
    debugPrint('Subscribed to topic: office_security');

    // --- Step 3: Set up local notification display ---
    // When the app is open (foreground), Firebase doesn't automatically show
    // a notification banner. We use the local notifications plugin to do that.
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // Use app icon
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped, // Handle taps
    );

    // --- Step 4: Create a notification channel ---
    // Android requires notifications to belong to a "channel" (category).
    // Users can control each channel separately in phone settings
    // (e.g., mute security alerts but keep other notifications).
    const channel = AndroidNotificationChannel(
      'security_alerts',                // Channel ID (must match the one sent by Pi)
      'Security Alerts',                // Channel name (shown in phone settings)
      description: 'Notifications for door access and security alerts',
      importance: Importance.high,      // High importance = shows as a banner
      playSound: true,                  // Play a sound when received
      enableVibration: true,            // Vibrate the phone
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // --- Step 5: Set up message handlers ---

    // When a notification arrives while the app is OPEN (foreground)
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // When user TAPS a notification that arrived while app was in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Check if the app was opened by tapping a notification while it was CLOSED
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App opened from terminated state via notification');
    }

    // Print the FCM token (useful for debugging - you can use this token
    // to send test notifications from the Firebase Console)
    final token = await _messaging.getToken();
    debugPrint('FCM Token: $token');
  }

  /// Called when a notification arrives while the app is OPEN.
  /// Since Android doesn't show a banner automatically in this case,
  /// we manually create and display a local notification.
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    // Choose a color for the notification based on what type of event it is
    // Red = intruder (urgent!), Orange = unauthorized, Green = door opened, Blue = other
    final eventType = message.data['event_type'] ?? '';
    Color color;
    switch (eventType) {
      case 'intruder':
        color = const Color(0xFFFF0000);  // Red - urgent alert
        break;
      case 'unauthorized':
        color = const Color(0xFFFF9800);  // Orange - warning
        break;
      case 'door_open':
        color = const Color(0xFF4CAF50);  // Green - normal access
        break;
      default:
        color = const Color(0xFF2196F3);  // Blue - general info
    }

    // Display the notification as a banner on the phone
    _localNotifications.show(
      notification.hashCode,  // Unique ID for this notification
      notification.title,     // Title text (e.g., "Door Opened")
      notification.body,      // Body text (e.g., "John accessed at 14:30")
      NotificationDetails(
        android: AndroidNotificationDetails(
          'security_alerts',    // Must match the channel ID created above
          'Security Alerts',
          channelDescription: 'Notifications for door access and security alerts',
          importance: Importance.high,
          priority: Priority.high,
          color: color,
          icon: '@mipmap/ic_launcher',  // Small icon shown in notification
          playSound: true,
        ),
      ),
    );
  }

  /// Called when the user taps a notification that arrived while the app was in the background.
  /// Could be used to navigate to a specific screen (e.g., the event details).
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.notification?.title}');
  }

  /// Called when the user taps a local notification (the ones we create in foreground).
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Local notification tapped: ${response.payload}');
  }
}
