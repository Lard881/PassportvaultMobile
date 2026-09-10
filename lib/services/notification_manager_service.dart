import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import '../services/api_service.dart';

/// Enhanced Notification Manager for PassportVault
/// Handles grouped notifications with WorkManager support
class NotificationManagerService {
  static final NotificationManagerService _instance = NotificationManagerService._internal();
  factory NotificationManagerService() => _instance;
  NotificationManagerService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Notification settings keys
  static const String _keyNotificationsEnabled = 'pv_notifications_enabled';
  static const String _keyNotificationHour = 'pv_notification_hour';
  static const String _keyNotificationMinute = 'pv_notification_minute';
  static const String _keyReminderDays = 'pv_reminder_days';
  static const String _keyExpiredEnabled = 'pv_expired_enabled';
  static const String _keyExpiredDays = 'pv_expired_days';
  static const String _keyLastCheckTime = 'pv_last_check_time';

  // Notification IDs for grouped notifications
  static const int _notificationId30Days = 1001;
  static const int _notificationId7Days = 1002;
  static const int _notificationId1Day = 1003;
  static const int _notificationIdExpired = 1004;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();
    
    // Auto-detect and set device's timezone
    try {
      final String currentTimeZone = DateTime.now().timeZoneName;
      
      String tzLocation = 'UTC';
      if (currentTimeZone.contains('GMT')) {
        tzLocation = 'Africa/Accra';
      } else if (currentTimeZone.contains('WAT')) {
        tzLocation = 'Africa/Lagos';
      } else if (currentTimeZone.contains('EAT')) {
        tzLocation = 'Africa/Nairobi';
      } else if (currentTimeZone.contains('CAT')) {
        tzLocation = 'Africa/Harare';
      } else if (currentTimeZone.contains('SAST')) {
        tzLocation = 'Africa/Johannesburg';
      }
      
      tz.setLocalLocation(tz.getLocation(tzLocation));
      debugPrint('[NotificationManager] Timezone: ${tz.local.name}');
    } catch (e) {
      debugPrint('[NotificationManager] Failed to detect timezone, using UTC: $e');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
    
    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
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
    debugPrint('[NotificationManager] Initialized');
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final androidGranted = await androidPlugin?.requestNotificationsPermission() ?? true;

    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }

    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final iosGranted = await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    ) ?? true;

    final exactAlarmGranted = await Permission.scheduleExactAlarm.isGranted;
    
    debugPrint('[NotificationManager] Permissions - Notification: $androidGranted, ExactAlarm: $exactAlarmGranted');

    return androidGranted && iosGranted && exactAlarmGranted;
  }

  /// Check if permissions are granted
  Future<bool> arePermissionsGranted() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final androidGranted = await androidPlugin?.areNotificationsEnabled() ?? true;
    
    final exactAlarmGranted = await Permission.scheduleExactAlarm.isGranted;

    return androidGranted && exactAlarmGranted;
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[NotificationManager] Notification tapped: ${response.payload}');
    // TODO: Navigate to documents page
  }

  /// Get notification settings
  Future<Map<String, dynamic>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    return {
      'notificationsEnabled': prefs.getBool(_keyNotificationsEnabled) ?? true,
      'notificationHour': prefs.getInt(_keyNotificationHour) ?? 9,
      'notificationMinute': prefs.getInt(_keyNotificationMinute) ?? 0,
      'reminderDays': jsonDecode(prefs.getString(_keyReminderDays) ?? '[30, 7, 1]'),
      'expiredNotificationsEnabled': prefs.getBool(_keyExpiredEnabled) ?? true,
      'expiredNotificationDays': jsonDecode(prefs.getString(_keyExpiredDays) ?? '["monday", "tuesday", "friday"]'),
    };
  }

  /// Save notification settings
  Future<void> saveSettings({
    required bool notificationsEnabled,
    required int notificationHour,
    required int notificationMinute,
    required List<int> reminderDays,
    required bool expiredNotificationsEnabled,
    required List<String> expiredNotificationDays,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setBool(_keyNotificationsEnabled, notificationsEnabled);
    await prefs.setInt(_keyNotificationHour, notificationHour);
    await prefs.setInt(_keyNotificationMinute, notificationMinute);
    await prefs.setString(_keyReminderDays, jsonEncode(reminderDays));
    await prefs.setBool(_keyExpiredEnabled, expiredNotificationsEnabled);
    await prefs.setString(_keyExpiredDays, jsonEncode(expiredNotificationDays));
    
    debugPrint('[NotificationManager] Settings saved');
  }

  /// Check documents and send GROUPED notifications (called by WorkManager)
  static Future<void> checkAndNotifyGrouped() async {
    debugPrint('[NotificationManager] ========== GROUPED NOTIFICATION CHECK ==========');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsEnabled = prefs.getBool(_keyNotificationsEnabled) ?? true;
      
      if (!notificationsEnabled) {
        debugPrint('[NotificationManager] Notifications disabled');
        return;
      }

      // Get settings
      final reminderDaysList = jsonDecode(prefs.getString(_keyReminderDays) ?? '[30, 7, 1]') as List;
      final reminderDays = reminderDaysList.map((e) => e as int).toList();
      final expiredEnabled = prefs.getBool(_keyExpiredEnabled) ?? true;
      final expiredDaysList = jsonDecode(prefs.getString(_keyExpiredDays) ?? '["monday", "tuesday", "friday"]') as List;
      final expiredDays = expiredDaysList.map((e) => e.toString()).toList();

      // Fetch documents from API
      final response = await ApiService.getDocuments();
      
      if (response['success'] != true || response['data'] == null) {
        debugPrint('[NotificationManager] ❌ Failed to fetch documents');
        return;
      }
      
      final documents = response['data'] as List;
      final now = DateTime.now();

      // Group documents by expiry status
      final Map<int, List<Map<String, dynamic>>> expiringGroups = {
        30: [],
        7: [],
        1: [],
      };
      final List<Map<String, dynamic>> expiredDocs = [];

      // Categorize documents
      for (var doc in documents) {
        if (doc['expiry_date'] == null) continue;

        final expiryDate = DateTime.parse(doc['expiry_date']);
        final daysUntilExpiry = expiryDate.difference(now).inDays;

        // Check for expiring soon
        for (var reminderDay in reminderDays) {
          if (daysUntilExpiry == reminderDay) {
            expiringGroups[reminderDay]?.add({
              'name': doc['document_name'] ?? 'Document',
              'type': doc['document_type'] ?? '',
              'days': reminderDay,
            });
          }
        }

        // Check for expired (only on specified days)
        if (expiredEnabled && daysUntilExpiry < 0) {
          final daysOfWeek = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
          final today = daysOfWeek[now.weekday % 7];
          
          if (expiredDays.contains(today)) {
            expiredDocs.add({
              'name': doc['document_name'] ?? 'Document',
              'type': doc['document_type'] ?? '',
              'daysAgo': daysUntilExpiry.abs(),
            });
          }
        }
      }

      // Send grouped notifications
      int sentCount = 0;

      // 30-day expiring group
      if (expiringGroups[30]!.isNotEmpty) {
        await _sendGroupedNotification(
          id: _notificationId30Days,
          title: '📋 ${expiringGroups[30]!.length} document${expiringGroups[30]!.length > 1 ? 's' : ''} expiring in 30 days',
          documents: expiringGroups[30]!,
          priority: 'default',
        );
        sentCount++;
      }

      // 7-day expiring group
      if (expiringGroups[7]!.isNotEmpty) {
        await _sendGroupedNotification(
          id: _notificationId7Days,
          title: '⚠️ ${expiringGroups[7]!.length} document${expiringGroups[7]!.length > 1 ? 's' : ''} expiring in 7 days',
          documents: expiringGroups[7]!,
          priority: 'high',
        );
        sentCount++;
      }

      // 1-day expiring group
      if (expiringGroups[1]!.isNotEmpty) {
        await _sendGroupedNotification(
          id: _notificationId1Day,
          title: '🚨 ${expiringGroups[1]!.length} document${expiringGroups[1]!.length > 1 ? 's' : ''} expiring TOMORROW',
          documents: expiringGroups[1]!,
          priority: 'max',
        );
        sentCount++;
      }

      // Expired group
      if (expiredDocs.isNotEmpty) {
        await _sendExpiredGroupNotification(
          id: _notificationIdExpired,
          title: '❌ ${expiredDocs.length} expired document${expiredDocs.length > 1 ? 's' : ''}',
          documents: expiredDocs,
        );
        sentCount++;
      }

      // Save last check time
      await prefs.setString(_keyLastCheckTime, now.toIso8601String());

      debugPrint('[NotificationManager] ========== Sent $sentCount grouped notification(s) ==========');
    } catch (e) {
      debugPrint('[NotificationManager] ❌ Error: $e');
    }
  }

  /// Send a grouped notification for expiring documents
  static Future<void> _sendGroupedNotification({
    required int id,
    required String title,
    required List<Map<String, dynamic>> documents,
    String priority = 'default',
  }) async {
    final notifications = FlutterLocalNotificationsPlugin();

    // Build body text (show first 3, then count)
    String body = '';
    final displayCount = documents.length > 3 ? 3 : documents.length;
    
    for (int i = 0; i < displayCount; i++) {
      final doc = documents[i];
      body += '• ${doc['name']}';
      if (doc['type'].toString().isNotEmpty) {
        body += ' (${doc['type']})';
      }
      if (i < displayCount - 1) body += '\n';
    }
    
    if (documents.length > 3) {
      body += '\n+ ${documents.length - 3} more...';
    }

    final androidDetails = AndroidNotificationDetails(
      'passportvault_alerts',
      'Document Alerts',
      channelDescription: 'Notifications for expiring and expired documents',
      importance: priority == 'max' ? Importance.max : (priority == 'high' ? Importance.high : Importance.defaultImportance),
      priority: priority == 'max' ? Priority.max : (priority == 'high' ? Priority.high : Priority.defaultPriority),
      color: const Color(0xFF0d6efd),
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(body),
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await notifications.show(id, title, body, details);
    debugPrint('[NotificationManager] ✅ Sent grouped notification: $title');
  }

  /// Send a grouped notification for expired documents
  static Future<void> _sendExpiredGroupNotification({
    required int id,
    required String title,
    required List<Map<String, dynamic>> documents,
  }) async {
    final notifications = FlutterLocalNotificationsPlugin();

    // Build body text
    String body = '';
    final displayCount = documents.length > 3 ? 3 : documents.length;
    
    for (int i = 0; i < displayCount; i++) {
      final doc = documents[i];
      body += '• ${doc['name']}';
      if (doc['type'].toString().isNotEmpty) {
        body += ' (${doc['type']})';
      }
      body += ' - ${doc['daysAgo']} day${doc['daysAgo'] > 1 ? 's' : ''} ago';
      if (i < displayCount - 1) body += '\n';
    }
    
    if (documents.length > 3) {
      body += '\n+ ${documents.length - 3} more...';
    }

    final androidDetails = AndroidNotificationDetails(
      'passportvault_alerts',
      'Document Alerts',
      channelDescription: 'Notifications for expiring and expired documents',
      importance: Importance.high,
      priority: Priority.high,
      color: const Color(0xFFdc3545),
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(body),
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await notifications.show(id, title, body, details);
    debugPrint('[NotificationManager] ✅ Sent expired notification: $title');
  }

  /// Get last check time
  Future<String?> getLastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastCheckTime);
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
    debugPrint('[NotificationManager] All notifications cancelled');
  }
}

// Global instance
final notificationManager = NotificationManagerService();
