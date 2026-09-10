import 'package:flutter/material.dart';
import '../../services/api_service.dart';

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
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.getNotifications();
      if (response['success'] == true) {
        setState(() {
          _notifications = response['data'] ?? [];
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load notifications: $error'),
            backgroundColor: const Color(0xFFdc3545),
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
    try {
      final idStr = notificationId?.toString();
      setState(() {
        for (var n in _notifications) {
          if (n['id']?.toString() == idStr) {
            n['is_read'] = true;
          }
        }
      });
      final response = await ApiService.markNotificationAsRead(idStr);
      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Marked as read'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
      await _fetchNotifications();
    } catch (error) {
      // Silent fail or refresh
      await _fetchNotifications();
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      setState(() {
        for (var n in _notifications) {
          n['is_read'] = true;
        }
      });
      
      final response = await ApiService.markAllNotificationsAsRead();
      if (response['success'] != true) {
        // Fallback to loop if bulk endpoint fails
        final unread = _notifications.where((n) => n['is_read'] == false).toList();
        for (var notification in unread) {
          await ApiService.markNotificationAsRead(notification['id']);
        }
      }
      
      await _fetchNotifications();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            backgroundColor: Color(0xFF198754),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark all as read: $error'),
            backgroundColor: const Color(0xFFdc3545),
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
            backgroundColor: const Color(0xFFdc3545),
          ),
        );
      }
    }
  }

  List<dynamic> _getFilteredNotifications() {
    if (_priorityFilter == 'All Priorities') {
      return _notifications;
    }
    return _notifications.where((n) => n['priority'] == _priorityFilter).toList();
  }

  Map<String, int> _getPriorityCounts() {
    final unread = _notifications.where((n) => n['is_read'] == false).toList();
    return {
      'HIGH': unread.where((n) => n['priority'] == 'HIGH').length,
      'MEDIUM': unread.where((n) => n['priority'] == 'MEDIUM').length,
      'LOW': unread.where((n) => n['priority'] == 'LOW').length,
    };
  }

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'HIGH':
        return const Color(0xFFdc3545);
      case 'MEDIUM':
        return const Color(0xFFffc107);
      case 'LOW':
        return const Color(0xFF28a745);
      default:
        return const Color(0xFF6c757d);
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
      if (difference.inMinutes < 60) return '${difference.inMinutes} minutes ago';
      if (difference.inHours < 24) return '${difference.inHours} hours ago';
      if (difference.inDays < 7) return '${difference.inDays} days ago';
      
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotifications = _getFilteredNotifications();
    final priorityCounts = _getPriorityCounts();
    final unreadCount = _notifications.where((n) => n['is_read'] == false).length;
    final totalActive = priorityCounts['HIGH']! + priorityCounts['MEDIUM']! + priorityCounts['LOW']!;
    
    // Dark mode detection
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? const Color(0xFFF8F9FA) : const Color(0xFF212529);
    final subtitleColor = isDark ? const Color(0xFFADB5BD) : const Color(0xFF6c757d);
    final cardBg = isDark ? const Color(0xFF242424) : Colors.white;
    final borderColor = isDark ? const Color(0xFF404040) : const Color(0xFFDEE2E6);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF0d6efd)),
                  const SizedBox(height: 16),
                  Text(
                    'Loading notifications...',
                    style: TextStyle(color: subtitleColor),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchNotifications,
              color: const Color(0xFF0d6efd),
              child: CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),

                  // Summary Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          // Active Notifications Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0d6efd).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.notifications,
                                    color: Color(0xFF0d6efd),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      totalActive.toString(),
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                        height: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Active Notifications',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: subtitleColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Priority Cards
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.2,
                            children: [
                              _buildPriorityCard(
                                'HIGH',
                                priorityCounts['HIGH']!,
                                const Color(0xFFdc3545),
                              ),
                              _buildPriorityCard(
                                'MEDIUM',
                                priorityCounts['MEDIUM']!,
                                const Color(0xFFffc107),
                              ),
                              _buildPriorityCard(
                                'LOW',
                                priorityCounts['LOW']!,
                                const Color(0xFF28a745),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // Filter and Actions
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: borderColor),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _priorityFilter,
                                  isExpanded: true,
                                  style: TextStyle(fontSize: 14, color: textColor),
                                  dropdownColor: cardBg,
                                  items: const [
                                    DropdownMenuItem(value: 'All Priorities', child: Text('All Priorities')),
                                    DropdownMenuItem(value: 'HIGH', child: Text('HIGH')),
                                    DropdownMenuItem(value: 'MEDIUM', child: Text('MEDIUM')),
                                    DropdownMenuItem(value: 'LOW', child: Text('LOW')),
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
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: _markAllAsRead,
                              icon: const Icon(Icons.done_all, size: 18),
                              label: const Text('Mark all as read'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0d6efd),
                                side: const BorderSide(color: Color(0xFF0d6efd)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // Notifications List
                  if (filteredNotifications.isEmpty)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(48),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF242424) : const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.notifications_off,
                              size: 60,
                              color: isDark ? Colors.grey[700] : Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Notifications',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: subtitleColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _notifications.isEmpty
                                  ? "You're all caught up! No notifications at this time."
                                  : 'No notifications match this filter',
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
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final notification = filteredNotifications[index];
                            return _buildNotificationCard(notification);
                          },
                          childCount: filteredNotifications.length,
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              ),
            ),
    );
  }

  Widget _buildPriorityCard(String label, int count, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF242424) : Colors.white;
    final subtitleColor = isDark ? const Color(0xFFADB5BD) : const Color(0xFF6c757d);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: subtitleColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(dynamic notification) {
    final isRead = notification['is_read'] == true;
    final priority = notification['priority'] as String?;
    final color = _getPriorityColor(priority);
    final icon = _getPriorityIcon(priority);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? (isRead ? const Color(0xFF242424) : const Color(0xFF1E293B))
        : (isRead ? Colors.white : const Color(0xFF0d6efd).withValues(alpha: 0.03));
    final textColor = isDark ? const Color(0xFFF8F9FA) : const Color(0xFF212529);
    final subtitleColor = isDark ? const Color(0xFFADB5BD) : const Color(0xFF6C757D);
    final borderColor = isDark ? const Color(0xFF404040) : const Color(0xFFDEE2E6);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          // Priority Bar
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
          ),
          
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
                                fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
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
                        style: TextStyle(
                          fontSize: 14,
                          color: subtitleColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                  color: const Color(0xFF6c757d),
                                  onPressed: () => _markAsRead(notification['id']),
                                  tooltip: 'Mark as read',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                color: const Color(0xFF6c757d),
                                onPressed: () => _deleteNotification(notification['id']),
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
