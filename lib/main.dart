import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/connectivity_provider.dart';
import 'services/local_notification_service.dart';
import 'services/fcm_notification_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/main/main_screen.dart';
import 'screens/main/calendar_screen.dart';
import 'screens/main/alerts_screen.dart';
import 'screens/main/activity_log_screen.dart';
import 'screens/main/backup_restore_screen.dart';
import 'screens/main/secure_sharing_screen.dart';
import 'screens/main/settings_screen.dart';
import 'screens/main/public_share_screen.dart';
import 'screens/settings/fcm_notification_settings_screen.dart';
import 'screens/info/support_screen.dart';
import 'screens/info/privacy_policy_screen.dart';
import 'screens/info/terms_conditions_screen.dart';
import 'screens/info/user_guide_screen.dart';
import 'widgets/app_lock.dart';
import 'services/biometric_auth_service.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize timezone database
  tz.initializeTimeZones();
  
  // Set local timezone to Africa/Accra (Ghana)
  try {
    tz.setLocalLocation(tz.getLocation('Africa/Accra'));
  } catch (e) {
    debugPrint('[Timezone] Failed to set Africa/Accra: $e');
  }
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Initialize local notifications
  await LocalNotificationService.initialize();
  
  // Initialize FCM (Firebase Cloud Messaging)
  await fcmNotificationService.initialize();
  
  // Initialize FCM background handler
  await initializeFCMBackgroundHandler();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
      ],
      child: Consumer2<ThemeProvider, LocaleProvider>(
        builder: (context, themeProvider, localeProvider, _) {
          return MaterialApp(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            locale: localeProvider.locale,
            routes: {
              '/': (context) => const AppWrapper(),
              '/login': (context) => const LoginScreen(),
              '/signup': (context) => const SignupScreen(),
              '/forgot-password': (context) => const ForgotPasswordScreen(),
              '/reset-password': (context) {
                final args = ModalRoute.of(context)?.settings.arguments as Map?;
                return ResetPasswordScreen(token: args?['token']);
              },
              '/calendar': (context) => const CalendarScreen(),
              '/alerts': (context) => const AlertsScreen(),
              '/activity-log': (context) => const ActivityLogScreen(),
              '/backup-restore': (context) => const BackupRestoreScreen(),
              '/secure-sharing': (context) => const SecureSharingScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/notification-settings': (context) => const FCMNotificationSettingsScreen(),
              '/support': (context) => const SupportScreen(),
              '/privacy-policy': (context) => const PrivacyPolicyScreen(),
              '/terms-conditions': (context) => const TermsConditionsScreen(),
              '/user-guide': (context) => const UserGuideScreen(),
            },
            onGenerateRoute: (settings) {
              // Handle public share route with token parameter
              if (settings.name?.startsWith('/share/') == true) {
                final token = settings.name!.substring(7);
                return MaterialPageRoute(
                  builder: (context) => PublicShareScreen(token: token),
                );
              }
              return null;
            },
            initialRoute: '/',
          );
        },
      ),
    );
  }
}

/// AppWrapper handles authentication state and app lock
class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> with WidgetsBindingObserver {
  bool _shouldShowLock = false;
  bool _hasCheckedLock = false;
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    // Only set inactivity timer if unlocked and authenticated
    if (!_shouldShowLock) {
      _inactivityTimer = Timer(const Duration(minutes: 10), () async {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.isAuthenticated) {
          final isLockEnabled = await biometricAuthService.isAppLockEnabled();
          if (isLockEnabled && mounted) {
            setState(() {
              _shouldShowLock = true;
            });
          }
        }
      });
    }
  }

  Future<void> _lockIfEnabled() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isAuthenticated) {
      final isLockEnabled = await biometricAuthService.isAppLockEnabled();
      if (isLockEnabled && mounted) {
        setState(() {
          _shouldShowLock = true;
        });
      }
    }
  }

  bool _wasAppPaused = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (BiometricAuthService.isAuthenticating) {
      return;
    }
    if (state == AppLifecycleState.paused) {
      _wasAppPaused = true;
      _inactivityTimer?.cancel();
      _lockIfEnabled();
    } else if (state == AppLifecycleState.resumed) {
      if (_wasAppPaused) {
        _wasAppPaused = false;
        _checkAppLock();
      }
    }
  }

  Future<void> _checkAppLock() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoading) return;
    
    // Only check lock if user is authenticated
    if (authProvider.isAuthenticated) {
      final isLockEnabled = await biometricAuthService.isAppLockEnabled();
      if (mounted) {
        setState(() {
          _shouldShowLock = isLockEnabled;
          _hasCheckedLock = true;
        });
        if (!isLockEnabled) {
          _resetInactivityTimer();
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _shouldShowLock = false;
          _hasCheckedLock = true;
        });
      }
    }
  }

  void _handleUnlock() {
    setState(() {
      _shouldShowLock = false;
      _wasAppPaused = false;
    });
    _resetInactivityTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Show loading while checking auth
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Not authenticated - show login
        if (!authProvider.isAuthenticated) {
          return const LoginScreen();
        }

        // Authenticated: check lock if not checked yet
        if (!_hasCheckedLock) {
          _checkAppLock();
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Authenticated but locked - show app lock
        if (_shouldShowLock) {
          return AppLock(
            onUnlock: _handleUnlock,
            userName: authProvider.user?['name'],
          );
        }

        // Authenticated and unlocked - show main screen with inactivity detection
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _resetInactivityTimer(),
          onPointerMove: (_) => _resetInactivityTimer(),
          child: const MainScreen(),
        );
      },
    );
  }
}
