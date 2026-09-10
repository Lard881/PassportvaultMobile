import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Initialize notifications
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
    debugPrint('[NotificationService] Initialized');
  }

  // Request permissions
  Future<bool> requestPermissions() async {
    // Android 13+ requires runtime permission
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final androidGranted = await androidPlugin?.requestNotificationsPermission() ?? true;

    // iOS permission request
    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final iosGranted = await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    ) ?? true;

    return androidGranted && iosGranted;
  }

  static Function(String? payload)? onNotificationTapCallback;

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[NotificationService] Notification tapped: ${response.payload}');
    if (onNotificationTapCallback != null) {
      onNotificationTapCallback!(response.payload);
    }
  }

  // Show immediate notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String priority = 'default',
  }) async {
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'passportvault_channel',
      'PassportVault Notifications',
      channelDescription: 'Document expiry reminders and alerts',
      importance: priority == 'high' ? Importance.high : Importance.defaultImportance,
      priority: priority == 'high' ? Priority.high : Priority.defaultPriority,
      color: const Color(0xFF0d6efd),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, details, payload: payload);
    debugPrint('[NotificationService] Showed notification: $title');
  }

  // Schedule notification for document expiry
  Future<void> scheduleExpiryNotification({
    required int documentId,
    required String documentName,
    required String documentType,
    required DateTime expiryDate,
  }) async {
    final now = DateTime.now();
    
    // Schedule 30 days before expiry
    final thirtyDaysBefore = expiryDate.subtract(const Duration(days: 30));
    if (thirtyDaysBefore.isAfter(now)) {
      await _scheduleNotification(
        id: documentId * 100 + 30,
        title: 'Document Expiring Soon',
        body: '$documentName ($documentType) expires in 30 days',
        scheduledDate: thirtyDaysBefore,
        payload: 'document:$documentId',
      );
    }

    // Schedule 7 days before expiry
    final sevenDaysBefore = expiryDate.subtract(const Duration(days: 7));
    if (sevenDaysBefore.isAfter(now)) {
      await _scheduleNotification(
        id: documentId * 100 + 7,
        title: 'Document Expiring This Week',
        body: '$documentName ($documentType) expires in 7 days',
        scheduledDate: sevenDaysBefore,
        payload: 'document:$documentId',
      );
    }

    // Schedule on expiry date
    if (expiryDate.isAfter(now)) {
      await _scheduleNotification(
        id: documentId * 100,
        title: 'Document Expired',
        body: '$documentName ($documentType) has expired today',
        scheduledDate: expiryDate,
        payload: 'document:$documentId',
      );
    }
  }

  // Schedule a notification
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'passportvault_expiry',
      'Document Expiry',
      channelDescription: 'Notifications for expiring documents',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFF0d6efd),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint('[NotificationService] Scheduled notification for: $scheduledDate');
  }

  // Cancel notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
    debugPrint('[NotificationService] Cancelled notification: $id');
  }

  // Cancel all notifications for a document
  Future<void> cancelDocumentNotifications(int documentId) async {
    await _notifications.cancel(documentId * 100 + 30);
    await _notifications.cancel(documentId * 100 + 7);
    await _notifications.cancel(documentId * 100);
    debugPrint('[NotificationService] Cancelled all notifications for document: $documentId');
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    debugPrint('[NotificationService] Cancelled all notifications');
  }

  // Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }
}

// Global instance
final notificationService = NotificationService();
