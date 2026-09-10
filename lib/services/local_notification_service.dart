import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  static bool _initialized = false;

  /// Initialize notification service
  static Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone data
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    // TODO: Navigate to document detail screen
    // You can add navigation logic here later
    print('[Notification] Tapped: ${response.payload}');
  }

  /// Request notification permissions (Android 13+)
  static Future<bool> requestPermissions() async {
    if (!_initialized) await initialize();

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final bool? granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }

    final IOSFlutterLocalNotificationsPlugin? iosPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    if (iosPlugin != null) {
      final bool? granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  /// Check if notifications are enabled in settings
  static Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true; // Default: enabled
  }

  /// Get notification time from settings (hour in 24-hour format)
  static Future<int> getNotificationHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('notification_hour') ?? 9; // Default: 9 AM
  }

  /// Get notification minute from settings
  static Future<int> getNotificationMinute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('notification_minute') ?? 0; // Default: 0 minutes
  }

  /// Get reminder days from settings
  static Future<List<int>> getReminderDays() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('reminder_days');
    if (stored != null) {
      return stored.map((e) => int.parse(e)).toList();
    }
    return [30, 7, 1]; // Default: 30, 7, 1 days before
  }

  /// Check if expired notifications are enabled
  static Future<bool> areExpiredNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('expired_notifications_enabled') ?? true; // Default: enabled
  }

  /// Get expired notification days (Monday, Tuesday, Friday)
  static Future<List<String>> getExpiredNotificationDays() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('expired_notification_days');
    return stored ?? ['monday', 'tuesday', 'friday']; // Default: Mon, Tue, Fri
  }

  /// Check if expired notification should be scheduled for a specific date
  static Future<bool> _shouldScheduleExpiredNotification(DateTime date) async {
    final selectedDays = await getExpiredNotificationDays();
    final weekday = date.weekday; // 1 = Monday, 2 = Tuesday, ..., 7 = Sunday
    
    final dayNames = {
      1: 'monday',
      2: 'tuesday',
      3: 'wednesday',
      4: 'thursday',
      5: 'friday',
      6: 'saturday',
      7: 'sunday',
    };
    
    final dayName = dayNames[weekday] ?? '';
    return selectedDays.contains(dayName);
  }

  /// Schedule notifications for a document
  static Future<void> scheduleDocumentExpiryNotifications({
    required String documentId,
    required String documentName,
    required DateTime expiryDate,
  }) async {
    if (!_initialized) await initialize();

    // Check if notifications are enabled
    final enabled = await areNotificationsEnabled();
    if (!enabled) return;

    // Get user preferences
    final notificationHour = await getNotificationHour();
    final notificationMinute = await getNotificationMinute();
    final reminderDays = await getReminderDays();
    final expiredNotificationsEnabled = await areExpiredNotificationsEnabled();

    // Cancel existing notifications for this document
    await cancelDocumentNotifications(documentId);

    // ===== SCHEDULE NOTIFICATIONS BEFORE EXPIRY =====
    for (final days in reminderDays) {
      final notificationDate = expiryDate.subtract(Duration(days: days));
      
      // Skip if date is in the past
      if (notificationDate.isBefore(DateTime.now())) continue;

      // Set notification time to user's preferred hour AND minute
      final scheduledDate = DateTime(
        notificationDate.year,
        notificationDate.month,
        notificationDate.day,
        notificationHour,
        notificationMinute, // Use exact minute
        0, // second
      );

      // Skip if scheduled time is in the past
      if (scheduledDate.isBefore(DateTime.now())) continue;

      // Create unique notification ID
      final notificationId = _generateNotificationId(documentId, days);

      // Create notification message
      String message;
      if (days == 1) {
        message = '$documentName expires tomorrow!';
      } else if (days == 7) {
        message = '$documentName expires in 1 week';
      } else {
        message = '$documentName expires in $days days';
      }

      // Schedule notification
      await _notificationsPlugin.zonedSchedule(
        notificationId,
        'Document Expiring Soon',
        message,
        tz.TZDateTime.from(scheduledDate, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'document_expiry',
            'Document Expiry Reminders',
            channelDescription: 'Notifications for expiring documents',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: documentId,
      );

      print('[Notification] Scheduled for $documentName: $scheduledDate (${days}d before)');
    }

    // ===== SCHEDULE NOTIFICATIONS AFTER EXPIRY (3 consecutive days) =====
    // Only if user enabled expired notifications
    if (expiredNotificationsEnabled) {
      for (int dayAfter = 1; dayAfter <= 3; dayAfter++) {
        final notificationDate = expiryDate.add(Duration(days: dayAfter));
        
        // Check if this day is in the selected weekly schedule
        final shouldSchedule = await _shouldScheduleExpiredNotification(notificationDate);
        if (!shouldSchedule) {
          print('[Notification] Skipping expired notification for $documentName on ${notificationDate.toString().split(' ')[0]} - not in weekly schedule');
          continue;
        }
        
        // Set notification time to user's preferred hour AND minute
        final scheduledDate = DateTime(
          notificationDate.year,
          notificationDate.month,
          notificationDate.day,
          notificationHour,
          notificationMinute, // Use exact minute
          0, // second
        );

        // Skip if scheduled time is in the past
        if (scheduledDate.isBefore(DateTime.now())) continue;

        // Create unique notification ID (use negative numbers for expired notifications)
        final notificationId = _generateNotificationId(documentId, -dayAfter);

        // Create notification message based on day
        String title;
        String message;
        if (dayAfter == 1) {
          title = 'Document Expired';
          message = '$documentName has expired! Please renew it.';
        } else if (dayAfter == 2) {
          title = 'Document Expired';
          message = '$documentName expired 1 day ago. Please renew it.';
        } else {
          title = 'Document Expired';
          message = '$documentName expired 2 days ago. Please renew it soon.';
        }

        // Schedule notification
        await _notificationsPlugin.zonedSchedule(
          notificationId,
          title,
          message,
          tz.TZDateTime.from(scheduledDate, tz.local),
          NotificationDetails(
            android: AndroidNotificationDetails(
              'document_expiry',
              'Document Expiry Reminders',
              channelDescription: 'Notifications for expiring documents',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: documentId,
      );

        print('[Notification] Scheduled expired notification for $documentName: $scheduledDate (Day $dayAfter after expiry)');
      }
    }
  }

  /// Cancel all notifications for a specific document
  static Future<void> cancelDocumentNotifications(String documentId) async {
    if (!_initialized) await initialize();

    final reminderDays = [30, 7, 1]; // Check all possible reminder days
    for (final days in reminderDays) {
      final notificationId = _generateNotificationId(documentId, days);
      await _notificationsPlugin.cancel(notificationId);
    }

    // Cancel expired notifications (Day 1, 2, 3 after expiry)
    for (int dayAfter = 1; dayAfter <= 3; dayAfter++) {
      final notificationId = _generateNotificationId(documentId, -dayAfter);
      await _notificationsPlugin.cancel(notificationId);
    }
  }

  /// Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    if (!_initialized) await initialize();
    await _notificationsPlugin.cancelAll();
  }

  /// Get pending notifications (for debugging)
  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_initialized) await initialize();
    return await _notificationsPlugin.pendingNotificationRequests();
  }

  /// Generate unique notification ID from document ID and days
  static int _generateNotificationId(String documentId, int days) {
    // Create a simple hash from documentId and days
    // This ensures same document + same days = same ID
    final hash = documentId.hashCode + days;
    return hash.abs() % 2147483647; // Max int32 value
  }

  /// Send immediate test notification
  static Future<void> sendTestNotification() async {
    if (!_initialized) await initialize();

    await _notificationsPlugin.show(
      999999, // Test notification ID
      'Test Notification',
      'Notifications are working! You will receive reminders when documents are about to expire.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test Notifications',
          channelDescription: 'Test notification channel',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
