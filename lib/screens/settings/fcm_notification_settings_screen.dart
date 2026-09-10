import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../services/fcm_notification_service.dart';
import '../../services/api_service.dart';

/// FCM Notification Settings Screen
/// Allows users to configure notification preferences
class FCMNotificationSettingsScreen extends StatefulWidget {
  const FCMNotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<FCMNotificationSettingsScreen> createState() => _FCMNotificationSettingsScreenState();
}

class _FCMNotificationSettingsScreenState extends State<FCMNotificationSettingsScreen> {
  bool _isLoading = true;
  bool _notificationsEnabled = true;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 9, minute: 0);
  List<int> _reminderDays = [30, 7, 1];
  List<String> _allowedWeekdays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];
  String _userTimezone = 'UTC';
  String? _fcmToken;

  final List<int> _availableReminderDays = [30, 14, 7, 3, 1];
  final List<String> _allWeekdays = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday'
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
      
      if (response['success'] && response['data'] != null) {
        final data = response['data'];
        
        setState(() {
          _notificationsEnabled = data['notification_enabled'] ?? true;
          _fcmToken = data['fcm_token'];
          
          // Parse notification time
          if (data['notification_time'] != null) {
            final timeParts = data['notification_time'].toString().split(':');
            _notificationTime = TimeOfDay(
              hour: int.parse(timeParts[0]),
              minute: int.parse(timeParts[1]),
            );
          }
          
          // Parse reminder days
          if (data['reminder_days'] != null) {
            _reminderDays = List<int>.from(data['reminder_days']);
          }
          
          // Parse allowed weekdays
          if (data['allowed_weekdays'] != null) {
            _allowedWeekdays = List<String>.from(data['allowed_weekdays']);
          }
          
          // DON'T overwrite detected timezone with database value
          // Keep using the detected timezone (_userTimezone)
          // This ensures Africa/Accra is always used, not UTC
          
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
      
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
      setState(() => _isLoading = false);
    }
  }

  /// Save notification settings to backend
  Future<void> _saveSettings() async {
    try {
      // Format time as HH:MM:SS
      final timeString = '${_notificationTime.hour.toString().padLeft(2, '0')}:'
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
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
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
              backgroundColor: Colors.white,
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
          backgroundColor: const Color(0xFF0d6efd),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: const Color(0xFF0d6efd),
        foregroundColor: Colors.white,
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
              activeColor: const Color(0xFF0d6efd),
            ),
          ),
          const SizedBox(height: 16),

          // Notification Time
          Card(
            elevation: 2,
            child: ListTile(
              title: const Text('Daily Check Time'),
              subtitle: Text('Notifications sent at ${_formatTime()} ($_userTimezone)'),
              trailing: const Icon(Icons.access_time),
              onTap: _notificationsEnabled ? _selectTime : null,
              enabled: _notificationsEnabled,
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
                        onSelected: _notificationsEnabled
                            ? (selected) {
                                setState(() {
                                  if (selected) {
                                    _reminderDays.add(days);
                                    _reminderDays.sort((a, b) => b.compareTo(a));
                                  } else {
                                    _reminderDays.remove(days);
                                  }
                                });
                                _saveSettings();
                              }
                            : null,
                        selectedColor: const Color(0xFF0d6efd).withOpacity(0.2),
                        checkmarkColor: const Color(0xFF0d6efd),
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
                        onSelected: _notificationsEnabled
                            ? (selected) {
                                setState(() {
                                  if (selected) {
                                    _allowedWeekdays.add(day);
                                  } else {
                                    if (_allowedWeekdays.length > 1) {
                                      _allowedWeekdays.remove(day);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('At least one day must be selected'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  }
                                });
                                _saveSettings();
                              }
                            : null,
                        selectedColor: const Color(0xFF0d6efd).withOpacity(0.2),
                        checkmarkColor: const Color(0xFF0d6efd),
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
