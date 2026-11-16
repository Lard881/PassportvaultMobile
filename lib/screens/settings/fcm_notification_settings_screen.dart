import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../config/app_theme.dart';
import '../../services/fcm_notification_service.dart';
import '../../services/api_service.dart';

/// FCM Notification Settings Screen
/// Allows users to configure notification preferences
class FCMNotificationSettingsScreen extends StatefulWidget {
  const FCMNotificationSettingsScreen({super.key});

  @override
  State<FCMNotificationSettingsScreen> createState() =>
      _FCMNotificationSettingsScreenState();
}

class _FCMNotificationSettingsScreenState
    extends State<FCMNotificationSettingsScreen> {
  bool _isLoading = true;
  bool _notificationsEnabled = true;
  bool _emailNotificationsEnabled = false;
  bool _isSavingEmailNotifications = false;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 9, minute: 0);
  List<int> _reminderDays = [30, 7, 1];
  List<String> _allowedWeekdays = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
  ];
  String _userTimezone = 'UTC';
  String _accountEmail = '';
  String? _emailSettingsError;
  String? _fcmToken;
  bool get _hasEnabledReminderDelivery =>
      _notificationsEnabled || _emailNotificationsEnabled;

  final List<int> _availableReminderDays = [30, 14, 7, 3, 1];
  final List<String> _allWeekdays = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  @override
  void initState() {
    super.initState();
    _detectTimezone();
    _loadSettings();
  }

  /// Detect user's timezone
  void _detectTimezone() {
    try {
      // Get system timezone name
      final systemTimezoneName = DateTime.now().timeZoneName;

      // Try to get IANA timezone from timezone package
      final location = tz.local.name;

      // Prefer IANA timezone name (e.g., Africa/Accra)
      if (location.isNotEmpty && location != 'UTC' && location != 'GMT') {
        _userTimezone = location;
      } else if (systemTimezoneName == 'GMT' || systemTimezoneName == 'UTC') {
        // If system shows GMT/UTC, default to Africa/Accra for Ghana
        // User can change this if needed
        _userTimezone = 'Africa/Accra';
      } else {
        _userTimezone = systemTimezoneName;
      }
    } catch (e) {
      // Fallback to Africa/Accra (Ghana timezone)
      _userTimezone = 'Africa/Accra';
    }
    debugPrint('[NotificationSettings] Detected timezone: $_userTimezone');
  }

  /// Load current notification settings from backend
  Future<void> _loadSettings() async {
    try {
      setState(() => _isLoading = true);

      // Get current user profile
      final response = await ApiService.getUserProfile();

      if (response['success'] == true && response['data'] is Map) {
        final data = Map<String, dynamic>.from(response['data'] as Map);

        setState(() {
          _notificationsEnabled = data['notification_enabled'] ?? true;
          _fcmToken = data['fcm_token'];
          _accountEmail = data['email']?.toString() ?? '';

          // Parse notification time
          if (data['notification_time'] != null) {
            final timeParts = data['notification_time'].toString().split(':');
            if (timeParts.length >= 2) {
              final hour = int.tryParse(timeParts[0]);
              final minute = int.tryParse(timeParts[1]);
              if (hour != null &&
                  hour >= 0 &&
                  hour <= 23 &&
                  minute != null &&
                  minute >= 0 &&
                  minute <= 59) {
                _notificationTime = TimeOfDay(hour: hour, minute: minute);
              }
            }
          }

          // Parse reminder days
          if (data['reminder_days'] is List) {
            final reminderDays = List<int>.from(data['reminder_days']);
            if (reminderDays.isNotEmpty) {
              _reminderDays = reminderDays;
            }
          }

          // Parse allowed weekdays
          if (data['allowed_weekdays'] is List) {
            final allowedWeekdays = List<String>.from(data['allowed_weekdays']);
            if (allowedWeekdays.isNotEmpty) {
              _allowedWeekdays = allowedWeekdays;
            }
          }

          // DON'T overwrite detected timezone with database value
          // Keep using the detected timezone (_userTimezone)
          // This ensures Africa/Accra is always used, not UTC
        });
      } else if (response['success'] != true) {
        throw Exception(
          response['message'] ?? 'Could not load notification settings',
        );
      }

      await _loadEmailNotificationPreference();

      // Get FCM token if not already stored
      if (_fcmToken == null || _fcmToken!.isEmpty) {
        _fcmToken = fcmNotificationService.fcmToken;

        // Save token to database if user is logged in
        if (_fcmToken != null && _fcmToken!.isNotEmpty) {
          await fcmNotificationService.saveTokenToDatabase();
        }
      }
    } catch (e) {
      debugPrint('[NotificationSettings] Error loading: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load notification settings: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadEmailNotificationPreference() async {
    try {
      final response = await ApiService.getSettings();
      final settings = response['data'];
      if (response['success'] != true ||
          settings is! Map ||
          settings['email_notifications'] is! bool) {
        throw Exception(
          response['message'] ?? 'Email notification setting is unavailable',
        );
      }

      if (mounted) {
        setState(() {
          _emailNotificationsEnabled = settings['email_notifications'] as bool;
          _emailSettingsError = null;
        });
      }
    } catch (error) {
      debugPrint(
        '[NotificationSettings] Error loading email preference: $error',
      );
      if (mounted) {
        setState(() {
          _emailNotificationsEnabled = false;
          _emailSettingsError = error.toString().replaceFirst(
            'Exception: ',
            '',
          );
        });
      }
    }
  }

  Future<void> _handleEmailNotificationsChanged(bool enabled) async {
    setState(() => _isSavingEmailNotifications = true);
    try {
      final response = await ApiService.updateEmailNotifications(enabled);
      if (response['success'] != true) {
        throw Exception(
          response['message'] ?? 'Could not save email notification setting',
        );
      }

      if (mounted) {
        setState(() {
          _emailNotificationsEnabled = enabled;
          _emailSettingsError = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? 'Email expiry reminders enabled'
                  : 'Email expiry reminders disabled',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
      debugPrint(
        '[NotificationSettings] Error saving email preference: $error',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not save email preference: '
              '${error.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingEmailNotifications = false);
      }
    }
  }

  /// Save notification settings to backend
  Future<void> _saveSettings() async {
    try {
      // Format time as HH:MM:SS
      final timeString =
          '${_notificationTime.hour.toString().padLeft(2, '0')}:'
          '${_notificationTime.minute.toString().padLeft(2, '0')}:00';

      final response = await ApiService.updateUserProfile({
        'notification_enabled': _notificationsEnabled,
        'notification_time': timeString,
        'reminder_days': _reminderDays,
        'allowed_weekdays': _allowedWeekdays,
        'timezone': _userTimezone,
        'fcm_token': _fcmToken,
      });

      if (mounted) {
        if (response['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Notification settings saved'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save: ${response['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[NotificationSettings] Error saving: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Show time picker
  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _notificationTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).colorScheme.surface,
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _notificationTime = picked);
      await _saveSettings();
    }
  }

  String _formatTime() {
    final hour = _notificationTime.hour > 12
        ? _notificationTime.hour - 12
        : (_notificationTime.hour == 0 ? 12 : _notificationTime.hour);
    final minute = _notificationTime.minute.toString().padLeft(2, '0');
    final period = _notificationTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _capitalizeFirst(String text) {
    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notification Settings'),
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Enable/Disable Notifications
          Card(
            elevation: 2,
            child: SwitchListTile(
              title: const Text('Enable Push Notifications'),
              subtitle: const Text('Receive alerts for expiring documents'),
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() => _notificationsEnabled = value);
                _saveSettings();
              },
              activeThumbColor: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),

          Card(
            elevation: 2,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.email_outlined),
                  title: const Text('Email Expiry Reminders'),
                  subtitle: Text(
                    _accountEmail.isEmpty
                        ? 'No email address is available for this account'
                        : 'Sent automatically to $_accountEmail',
                  ),
                  value: _emailNotificationsEnabled,
                  onChanged:
                      _isSavingEmailNotifications ||
                          _emailSettingsError != null ||
                          _accountEmail.isEmpty
                      ? null
                      : _handleEmailNotificationsChanged,
                  activeThumbColor: AppTheme.primaryColor,
                ),
                if (_emailSettingsError != null)
                  ListTile(
                    dense: true,
                    title: Text(
                      _emailSettingsError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: 'Retry',
                      onPressed: _isSavingEmailNotifications
                          ? null
                          : _loadEmailNotificationPreference,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Notification Time
          Card(
            elevation: 2,
            child: ListTile(
              title: const Text('Daily Check Time'),
              subtitle: Text(
                'Notifications sent at ${_formatTime()} ($_userTimezone)',
              ),
              trailing: const Icon(Icons.access_time),
              onTap: _hasEnabledReminderDelivery ? _selectTime : null,
              enabled: _hasEnabledReminderDelivery,
            ),
          ),
          const SizedBox(height: 16),

          // Reminder Days
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Expiry Reminders',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Get notified this many days before expiry:',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: _availableReminderDays.map((days) {
                      final isSelected = _reminderDays.contains(days);
                      return FilterChip(
                        label: Text('$days ${days == 1 ? 'day' : 'days'}'),
                        selected: isSelected,
                        onSelected: _hasEnabledReminderDelivery
                            ? (selected) {
                                if (!selected && _reminderDays.length == 1) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Select at least one reminder lead time',
                                      ),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                  return;
                                }
                                setState(() {
                                  if (selected) {
                                    _reminderDays.add(days);
                                    _reminderDays.sort(
                                      (a, b) => b.compareTo(a),
                                    );
                                  } else {
                                    _reminderDays.remove(days);
                                  }
                                });
                                _saveSettings();
                              }
                            : null,
                        selectedColor: AppTheme.primaryColor.withValues(
                          alpha: 0.2,
                        ),
                        checkmarkColor: AppTheme.primaryColor,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Allowed Weekdays
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notification Days',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Receive notifications on these days:',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: _allWeekdays.map((day) {
                      final isSelected = _allowedWeekdays.contains(day);
                      return FilterChip(
                        label: Text(_capitalizeFirst(day).substring(0, 3)),
                        selected: isSelected,
                        onSelected: _hasEnabledReminderDelivery
                            ? (selected) {
                                setState(() {
                                  if (selected) {
                                    _allowedWeekdays.add(day);
                                  } else {
                                    if (_allowedWeekdays.length > 1) {
                                      _allowedWeekdays.remove(day);
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'At least one day must be selected',
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  }
                                });
                                _saveSettings();
                              }
                            : null,
                        selectedColor: AppTheme.primaryColor.withValues(
                          alpha: 0.2,
                        ),
                        checkmarkColor: AppTheme.primaryColor,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
