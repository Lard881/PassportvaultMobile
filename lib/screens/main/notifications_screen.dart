import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/cache_service.dart';
import '../settings/fcm_notification_settings_screen.dart';
import '../../widgets/skeleton_loader.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<dynamic> _notifications = [];
  String _priorityFilter = 'All Priorities';

  @override
  void initState() {
    super.initState();
    _loadCachedDataAndRefresh();
  }

  /// Stale-while-revalidate pattern: Show cache instantly, fetch fresh in background
  Future<void> _loadCachedDataAndRefresh() async {
    // Step 1: Load cached data instantly
    final cachedNotifications = await CacheService.getNotificationsCache();
    if (mounted && cachedNotifications.isNotEmpty) {
      setState(() {
        _notifications = cachedNotifications;
        _isLoading = false;
      });
    }

    // Step 2: Check if cache is stale
    final isStale = await CacheService.isNotificationsCacheStale();

    // Step 3: If stale, fetch fresh data in background
    if (isStale || cachedNotifications.isEmpty) {
      _fetchNotifications();
    }
  }

  Future<void> _fetchNotifications() async {
    // Don't show loading spinner if we have cached data
    if (_notifications.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final response = await ApiService.getNotifications();
      if (response['success'] == true) {
        final notifications = response['data'] ?? [];
        await CacheService.saveNotificationsCache(notifications);

        if (mounted) {
          setState(() {
            _notifications = notifications;
          });
        }
      }
    } catch (error) {
      // Don't show error if we have cached data
      if (mounted && _notifications.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load notifications: $error'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAsRead(dynamic notificationId) async {
    // Store original notification for rollback
    final originalNotification = _notifications.firstWhere(
      (n) => n['id']?.toString() == notificationId?.toString(),
      orElse: () => {},
    );
    final originalReadStatus = originalNotification['is_read'] ?? false;

    try {
      // Optimistic UI: Mark as read instantly
      final idStr = notificationId?.toString();
      setState(() {
        for (var n in _notifications) {
          if (n['id']?.toString() == idStr) {
            n['is_read'] = true;
          }
        }
      });
      await CacheService.saveNotificationsCache(_notifications);

      final response = await ApiService.markNotificationAsRead(idStr);
      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Marked as read'),
              backgroundColor: AppTheme.successColor,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (error) {
      // Rollback on error
      if (mounted && originalNotification.isNotEmpty) {
        setState(() {
          for (var n in _notifications) {
            if (n['id']?.toString() == notificationId?.toString()) {
              n['is_read'] = originalReadStatus;
            }
          }
        });
        await CacheService.saveNotificationsCache(_notifications);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark as read: $error'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    // Store original state for rollback
    final originalNotifications = _notifications
        .map((n) => Map<String, dynamic>.from(n))
        .toList();

    try {
      // Optimistic UI: Mark all as read instantly
      setState(() {
        for (var n in _notifications) {
          n['is_read'] = true;
        }
      });

      final response = await ApiService.markAllNotificationsAsRead();
      if (response['success'] != true) {
        // Fallback to loop if bulk endpoint fails
        final unread = originalNotifications
            .where((n) => n['is_read'] == false)
            .toList();
        for (var notification in unread) {
          final updateResponse = await ApiService.markNotificationAsRead(
            notification['id'],
          );
          if (updateResponse['success'] != true) {
            throw StateError(
              updateResponse['message']?.toString() ??
                  'Failed to mark a notification as read',
            );
          }
        }
      }

      await _fetchNotifications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _notifications = originalNotifications;
        });
        try {
          await CacheService.saveNotificationsCache(_notifications);
        } catch (cacheError) {
          debugPrint(
            '[NotificationsScreen] Failed to restore notification cache: '
            '$cacheError',
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark all as read: $error'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    }
  }

  Future<void> _deleteNotification(dynamic notificationId) async {
    final idStr = notificationId?.toString();
    if (idStr == null || idStr.isEmpty) return;

    // Save previous state for rollback in case of failure
    final previousNotifications = List<dynamic>.from(_notifications);
    setState(() {
      _notifications.removeWhere((n) => n['id']?.toString() == idStr);
    });

    try {
      final response = await ApiService.deleteNotification(idStr);
      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification deleted'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        await _fetchNotifications();
      } else {
        throw Exception(response['message'] ?? 'Failed to delete');
      }
    } catch (error) {
      // Rollback
      setState(() {
        _notifications = previousNotifications;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $error'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    }
  }

  List<dynamic> _getFilteredNotifications() {
    if (_priorityFilter == 'All Priorities') {
      return _notifications;
    }
    return _notifications
        .where((n) => n['priority'] == _priorityFilter)
        .toList();
  }

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'HIGH':
        return AppTheme.dangerColor;
      case 'MEDIUM':
        return AppTheme.warningColor;
      case 'LOW':
        return AppTheme.successColor;
      default:
        return AppTheme.lightTextSecondary;
    }
  }

  IconData _getPriorityIcon(String? priority) {
    switch (priority) {
      case 'HIGH':
        return Icons.error;
      case 'MEDIUM':
        return Icons.warning;
      case 'LOW':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  String _getTimeAgo(dynamic dateString) {
    if (dateString == null) return '';

    try {
      final date = DateTime.parse(dateString.toString());
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inSeconds < 60) return 'Just now';
      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} minutes ago';
      }
      if (difference.inHours < 24) {
        return '${difference.inHours} hours ago';
      }
      if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      }

      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotifications = _getFilteredNotifications();
    final unreadCount = _notifications
        .where((n) => n['is_read'] == false)
        .length;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark
        ? AppTheme.darkBgPrimary
        : AppTheme.lightBgSecondary;
    final textColor = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;
    final subtitleColor = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.lightTextSecondary;
    final cardBg = isDark ? AppTheme.darkBgCard : AppTheme.lightBgCard;
    final borderColor = isDark
        ? AppTheme.darkBorderColor
        : AppTheme.lightBorderColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: _isLoading
          ? SkeletonLoader.notificationList()
          : RefreshIndicator(
              onRefresh: _fetchNotifications,
              color: AppTheme.primaryColor,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Notifications',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  unreadCount == 0
                                      ? 'You are all caught up'
                                      : '$unreadCount unread notification${unreadCount == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Notification settings',
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const FCMNotificationSettingsScreen(),
                                ),
                              );
                            },
                            icon: Icon(
                              Icons.settings_outlined,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Priority filter and bulk action
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _priorityFilter,
                                  isExpanded: true,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textColor,
                                  ),
                                  dropdownColor: cardBg,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'All Priorities',
                                      child: Text('All priorities'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'HIGH',
                                      child: Text('High priority'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'MEDIUM',
                                      child: Text('Medium priority'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'LOW',
                                      child: Text('Low priority'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _priorityFilter = value);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Mark all as read',
                              onPressed: _markAllAsRead,
                              icon: const Icon(Icons.done_all),
                              color: AppTheme.primaryColor,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // Notifications list
                  if (filteredNotifications.isEmpty)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(36),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 52,
                              color: subtitleColor,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No notifications',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _notifications.isEmpty
                                  ? "You're all caught up."
                                  : 'No notifications match this filter.',
                              style: TextStyle(
                                fontSize: 14,
                                color: subtitleColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final notification = filteredNotifications[index];
                          return _buildNotificationCard(notification);
                        }, childCount: filteredNotifications.length),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              ),
            ),
    );
  }

  Widget _buildNotificationCard(dynamic notification) {
    final isRead = notification['is_read'] == true;
    final priority = notification['priority'] as String?;
    final color = _getPriorityColor(priority);
    final icon = _getPriorityIcon(priority);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkBgCard : AppTheme.lightBgCard;
    final textColor = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;
    final subtitleColor = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.lightTextSecondary;
    final borderColor = isDark
        ? AppTheme.darkBorderColor
        : AppTheme.lightBorderColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              notification['title'] ?? 'Notification',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                          ),
                          Text(
                            _getTimeAgo(notification['created_at']),
                            style: TextStyle(
                              fontSize: 12,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        notification['message'] ?? '',
                        style: TextStyle(fontSize: 14, color: subtitleColor),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              priority ?? 'NORMAL',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              if (!isRead)
                                IconButton(
                                  icon: const Icon(Icons.check, size: 20),
                                  color: AppTheme.primaryColor,
                                  onPressed: () =>
                                      _markAsRead(notification['id']),
                                  tooltip: 'Mark as read',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                ),
                                color: subtitleColor,
                                onPressed: () =>
                                    _deleteNotification(notification['id']),
                                tooltip: 'Delete',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
