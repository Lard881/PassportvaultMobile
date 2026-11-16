import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dashboard_screen.dart';
import 'profiles_screen.dart';
import 'documents_screen.dart';
import 'notifications_screen.dart';
import 'more_screen.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../services/sync_service.dart';
import '../../services/backup_restore_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/offline_banner.dart';
import '../../providers/theme_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../config/app_theme.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  
  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  int _unreadCount = 0;
  Timer? _notificationPollTimer;


  int _lastNotifiedCount = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _initNotifications();
    _fetchUnreadCount();
    _startNotificationPolling();
    
    // WhatsApp-style: Check for backup and offer restore on first launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        BackupRestoreService.checkAndOfferRestore(context);
      }
    });
    
    NotificationService.onNotificationTapCallback = (payload) {
      if (mounted) {
        if (payload != null && payload.contains('document')) {
          _navigateToTab(2); // Go to Documents tab
        } else {
          _navigateToTab(3); // Go to Notifications tab
        }
      }
    };
  }

  Future<void> _initNotifications() async {
    await notificationService.initialize();
    await notificationService.requestPermissions();
  }

  @override
  void dispose() {
    _notificationPollTimer?.cancel();
    super.dispose();
  }

  void _startNotificationPolling() {
    // Poll every 60 seconds like web app
    _notificationPollTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      _fetchUnreadCount();
    });
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final response = await ApiService.getUnreadNotificationsCount();
      if (response['success'] == true && mounted) {
        final newCount = (response['data']?['count'] ?? 0) as int;
        if (newCount > _lastNotifiedCount && newCount > 0) {
          _lastNotifiedCount = newCount;
          // Trigger local push notification banner on device status bar
          notificationService.showNotification(
            id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            title: 'PassportVault Alert 🔔',
            body: 'You have $newCount unread notification${newCount > 1 ? 's' : ''} in your vault.',
            priority: 'high',
          );
        }
        setState(() {
          _unreadCount = newCount;
        });
      }
    } catch (e) {
      // Silent fail
    }
  }

  final List<Widget> _screens = [
    const DashboardScreen(),
    const ProfilesScreen(),
    const DocumentsScreen(),
    const NotificationsScreen(),
    const MoreScreen(),
  ];

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
    
    // Refresh dashboard when navigating to it (index 0)
    if (index == 0 && _screens.isNotEmpty) {
      final dashboardScreen = _screens[0];
      if (dashboardScreen is DashboardScreen) {
        // Trigger refresh by calling a method if available
        // For now, we'll use a different approach - see dashboard_screen changes
      }
    }
    
    // Refresh unread count when leaving notifications tab
    if (index != 3) {
      _fetchUnreadCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, connectivity, child) {
        // Auto-sync when back online
        if (connectivity.wasOffline && connectivity.isOnline) {
          Future.delayed(const Duration(milliseconds: 500), () async {
            final result = await SyncService.processSyncQueue();
            if (mounted && result['synced'] != null && result['synced'] > 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ ${result['synced']} change(s) synced!'),
                  backgroundColor: const Color(0xFF198754),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          });
        }

        return Scaffold(
          appBar: AppHeader(
            unreadCount: _unreadCount,
            onNotificationTap: () => _navigateToTab(3),
            onLogoTap: () => _navigateToTab(0),
          ),
          body: Column(
            children: [
              // Offline/Online Banner
              OfflineBanner(
                isOnline: connectivity.isOnline,
                showOnlineMessage: connectivity.wasOffline,
              ),
              // Main Content
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: _screens,
                ),
              ),
            ],
          ),
          bottomNavigationBar: Consumer2<ThemeProvider, LocaleProvider>(
            builder: (context, themeProvider, localeProvider, child) {
              final isDark = themeProvider.isDark;
              return BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: _navigateToTab,
                type: BottomNavigationBarType.fixed,
                backgroundColor: isDark ? const Color(0xFF242424) : Colors.white,
                selectedItemColor: AppTheme.primaryColor,
                unselectedItemColor: isDark ? const Color(0xFFadb5bd) : const Color(0xFF6c757d),
                selectedFontSize: 12,
                unselectedFontSize: 12,
                items: [
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.home),
                    label: localeProvider.tr('dashboard'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.people),
                    label: localeProvider.tr('profiles'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.description),
                    label: localeProvider.tr('documents'),
                  ),
                  BottomNavigationBarItem(
                    icon: _unreadCount > 0
                        ? Badge(
                            label: Text(_unreadCount.toString()),
                            backgroundColor: const Color(0xFFdc3545),
                            textColor: Colors.white,
                            child: const Icon(Icons.notifications),
                          )
                        : const Icon(Icons.notifications),
                    label: localeProvider.tr('notifications'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.menu),
                    label: localeProvider.tr('more'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

// Helper to navigate to specific tab from anywhere
class MainScreenNavigator {
  static void goToTab(BuildContext context, int tabIndex) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => MainScreen(initialIndex: tabIndex)),
      (route) => false,
    );
  }
  
  static void goToDashboard(BuildContext context) => goToTab(context, 0);
  static void goToProfiles(BuildContext context) => goToTab(context, 1);
  static void goToDocuments(BuildContext context) => goToTab(context, 2);
  static void goToNotifications(BuildContext context) => goToTab(context, 3);
  static void goToMore(BuildContext context) => goToTab(context, 4);
}
