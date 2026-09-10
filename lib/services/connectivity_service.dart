import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service to monitor and check internet connectivity status
class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();
  static StreamController<bool>? _connectionChangeController;

  /// Stream that notifies listeners of connectivity changes
  static Stream<bool> get onConnectivityChanged {
    _connectionChangeController ??= StreamController<bool>.broadcast();
    
    _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      final isConnected = result != ConnectivityResult.none;
      _connectionChangeController?.add(isConnected);
      debugPrint('🌐 Connectivity changed: ${isConnected ? "ONLINE" : "OFFLINE"}');
    });
    
    return _connectionChangeController!.stream;
  }

  /// Check current connectivity status (basic check)
  static Future<bool> hasConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      debugPrint('❌ Error checking connectivity: $e');
      return false;
    }
  }

  /// Check if device has actual internet connection (more reliable)
  /// This makes an actual network request to verify internet access
  static Future<bool> hasInternetConnection() async {
    try {
      // First check basic connectivity
      final hasBasicConnectivity = await hasConnectivity();
      if (!hasBasicConnectivity) {
        return false;
      }

      // Then verify actual internet access
      final result = await InternetAddress.lookup('google.com').timeout(
        const Duration(seconds: 5),
      );
      
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        debugPrint('✅ Internet connection verified');
        return true;
      }
      
      return false;
    } on SocketException catch (_) {
      debugPrint('❌ No internet connection (SocketException)');
      return false;
    } on TimeoutException catch (_) {
      debugPrint('❌ Internet connection timeout');
      return false;
    } catch (e) {
      debugPrint('❌ Error verifying internet: $e');
      return false;
    }
  }

  /// Get current connectivity result
  static Future<ConnectivityResult> getCurrentConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result;
    } catch (e) {
      debugPrint('❌ Error getting connectivity result: $e');
      return ConnectivityResult.none;
    }
  }

  /// Get human-readable connection type
  static Future<String> getConnectionType() async {
    final result = await getCurrentConnectivity();
    switch (result) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Mobile Data';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.none:
        return 'Offline';
      default:
        return 'Unknown';
    }
  }

  /// Dispose of resources
  static void dispose() {
    _connectionChangeController?.close();
    _connectionChangeController = null;
  }
}
