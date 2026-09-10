import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/api_service.dart';

/// FCM Notification Service for PassportVault
/// Handles Firebase Cloud Messaging integration
class FCMNotificationService {
  static final FCMNotificationService _instance = FCMNotificationService._internal();
  factory FCMNotificationService() => _instance;
  FCMNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  bool _initialized = false;
  String? _fcmToken;

  /// Initialize FCM and request permissions
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Request notification permissions (iOS)
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // Initialize local notifications for foreground display
        await _initializeLocalNotifications();

        // Get FCM token
        _fcmToken = await _firebaseMessaging.getToken();
        debugPrint('[FCM] Token: $_fcmToken');

        // Save token to Supabase
        if (_fcmToken != null) {
          await _saveFCMTokenToDatabase(_fcmToken!);
        }

        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          debugPrint('[FCM] Token refreshed: $newToken');
          _fcmToken = newToken;
          _saveFCMTokenToDatabase(newToken);
        });

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle background messages (when app is in background but not terminated)
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

        // Handle messages when app was terminated
        final initialMessage = await _firebaseMessaging.getInitialMessage();
        if (initialMessage != null) {
          _handleMessageOpenedApp(initialMessage);
        }

        _initialized = true;
        debugPrint('[FCM] Initialized successfully');
      } else {
        debugPrint('[FCM] Permission denied');
      }
    } catch (e) {
      debugPrint('[FCM] Initialization error: $e');
    }
  }

  /// Initialize local notifications for foreground display
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('[FCM] Local notification tapped: ${response.payload}');
        // TODO: Navigate to documents screen
      },
    );
  }

  /// Handle foreground messages (when app is open)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[FCM] Foreground message received');
    debugPrint('[FCM] Title: ${message.notification?.title}');
    debugPrint('[FCM] Body: ${message.notification?.body}');

    // Display notification even when app is in foreground
    await _showLocalNotification(message);
  }

  /// Handle message when user taps notification
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('[FCM] Message opened app');
    debugPrint('[FCM] Data: ${message.data}');
    
    // TODO: Navigate based on notification data
    // For example, navigate to documents screen
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'passportvault_alerts',
      'Document Alerts',
      channelDescription: 'Notifications for expiring and expired documents',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFF0d6efd),
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'PassportVault',
      message.notification?.body ?? '',
      details,
      payload: message.data.toString(),
    );
  }

  /// Save FCM token to Supabase database
  Future<void> _saveFCMTokenToDatabase(String token) async {
    try {
      // Check if user is logged in first
      final authToken = await ApiService.getToken();
      if (authToken == null) {
        debugPrint('[FCM] User not logged in, skipping token save');
        return;
      }

      final response = await ApiService.updateUserProfile({
        'fcm_token': token,
      });

      if (response['success']) {
        debugPrint('[FCM] Token saved to database');
      } else {
        debugPrint('[FCM] Failed to save token: ${response['message']}');
      }
    } catch (e) {
      debugPrint('[FCM] Error saving token: $e');
    }
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Save token to database manually (call after login)
  Future<bool> saveTokenToDatabase() async {
    if (_fcmToken == null) {
      debugPrint('[FCM] No token to save');
      return false;
    }

    try {
      final authToken = await ApiService.getToken();
      if (authToken == null) {
        debugPrint('[FCM] User not logged in');
        return false;
      }

      final response = await ApiService.updateUserProfile({
        'fcm_token': _fcmToken,
      });

      if (response['success']) {
        debugPrint('[FCM] ✅ Token saved to database after login');
        return true;
      } else {
        debugPrint('[FCM] ❌ Failed to save token: ${response['message']}');
        return false;
      }
    } catch (e) {
      debugPrint('[FCM] Error saving token: $e');
      return false;
    }
  }

  /// Refresh FCM token manually
  Future<String?> refreshToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      if (_fcmToken != null) {
        await _saveFCMTokenToDatabase(_fcmToken!);
      }
      return _fcmToken;
    } catch (e) {
      debugPrint('[FCM] Error refreshing token: $e');
      return null;
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM] Background message received');
  debugPrint('[FCM] Title: ${message.notification?.title}');
  debugPrint('[FCM] Body: ${message.notification?.body}');
}

/// Initialize background handler
Future<void> initializeFCMBackgroundHandler() async {
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
}

// Global instance
final fcmNotificationService = FCMNotificationService();
