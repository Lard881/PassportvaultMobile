import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/connectivity_service.dart';

/// Provider to manage app-wide connectivity state
class ConnectivityProvider with ChangeNotifier {
  bool _isOnline = true;
  bool _wasOffline = false;
  String _connectionType = 'Unknown';
  StreamSubscription<bool>? _connectivitySubscription;

  ConnectivityProvider() {
    _initConnectivity();
    _listenToConnectivityChanges();
  }

  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;
  bool get wasOffline => _wasOffline;
  String get connectionType => _connectionType;

  /// Initialize connectivity state
  Future<void> _initConnectivity() async {
    try {
      _isOnline = await ConnectivityService.hasInternetConnection();
      _connectionType = await ConnectivityService.getConnectionType();
      debugPrint('🌐 Initial connectivity: ${_isOnline ? "ONLINE" : "OFFLINE"} ($_connectionType)');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error initializing connectivity: $e');
    }
  }

  /// Listen to connectivity changes
  void _listenToConnectivityChanges() {
    _connectivitySubscription = ConnectivityService.onConnectivityChanged.listen(
      (bool isConnected) async {
        final previousState = _isOnline;
        
        // Verify actual internet connection
        _isOnline = await ConnectivityService.hasInternetConnection();
        _connectionType = await ConnectivityService.getConnectionType();
        
        // Track if we were offline (to show "back online" message)
        if (!previousState && _isOnline) {
          _wasOffline = true;
          debugPrint('✅ Back ONLINE - Triggering sync...');
          // Reset flag after a delay
          Future.delayed(const Duration(seconds: 5), () {
            _wasOffline = false;
            notifyListeners();
          });
        } else if (previousState && !_isOnline) {
          debugPrint('⚠️ Now OFFLINE - Using cached data');
        }
        
        notifyListeners();
      },
    );
  }

  /// Manually refresh connectivity status
  Future<void> checkConnectivity() async {
    _isOnline = await ConnectivityService.hasInternetConnection();
    _connectionType = await ConnectivityService.getConnectionType();
    debugPrint('🔄 Manual connectivity check: ${_isOnline ? "ONLINE" : "OFFLINE"}');
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    ConnectivityService.dispose();
    super.dispose();
  }
}
