import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = true;
  Map<String, dynamic>? _user;
  String? _errorMessage;
  Timer? _tokenRefreshTimer;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get user => _user;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    ApiService.onUnauthorized = () {
      logout();
    };
    _checkAuth();
  }

  @override
  void dispose() {
    _tokenRefreshTimer?.cancel();
    super.dispose();
  }

  // 🚀 AUTO TOKEN REFRESH - Keep user logged in forever (like WhatsApp)
  void _startTokenRefresh() {
    // Cancel any existing timer
    _tokenRefreshTimer?.cancel();

    // Initial refresh after 1 minute (to verify session)
    Future.delayed(const Duration(minutes: 1), _refreshToken);

    // Refresh token every 30 minutes to keep session alive
    _tokenRefreshTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _refreshToken(),
    );
  }

  void _stopTokenRefresh() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
  }

  Future<void> _refreshToken() async {
    if (!_isAuthenticated) return;

    try {
      final token = await ApiService.getToken();
      if (token == null) return;

      print('[Auth] Auto-refreshing token...');

      // Verify token is still valid (this keeps session alive)
      final response = await ApiService.getCurrentUser();

      if (response['success'] == true) {
        print('[Auth] Token refresh successful');
        // Token is still valid, update user data if changed
        _user = response['data'];
        await _saveUserToStorage(_user!);
        notifyListeners();
      } else {
        print('[Auth] Token refresh failed, logging out');
        // Token invalid, logout user
        await logout();
      }
    } catch (e) {
      print('[Auth] Token refresh error: $e');
      // Don't logout on network errors, token might still be valid
    }
  }

  // Check if user is already logged in
  Future<void> _checkAuth() async {
    try {
      final token = await ApiService.getToken();
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('pv_user');

      if (token != null && userJson != null) {
        // User is logged in, load from storage
        _user = {'name': userJson.split(',')[0], 'email': userJson.split(',')[1]};
        _isAuthenticated = true;
        
        // Start auto token refresh
        _startTokenRefresh();
        
        // Verify token in background (don't block app)
        try {
          final response = await ApiService.getCurrentUser();
          if (response['success'] == true) {
            _user = response['data'];
            await _saveUserToStorage(_user!);
          } else if (response['status'] == 401) {
            await logout();
          }
        } catch (e) {
          // Network error - keep user logged in with cached data
        }
      }
    } catch (e) {
      // Auth check error - ignore
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Login
  // Note: Users ALWAYS stay logged in until manual logout (WhatsApp-style)
  // rememberMe parameter ONLY controls credential auto-fill, not login persistence
  Future<Map<String, dynamic>> login(String email, String password, {bool rememberMe = true}) async {
    try {
      _errorMessage = null;
      notifyListeners();

      final response = await ApiService.login(email, password);

      if (response['success'] == true) {
        final token = response['data']['token'];
        final userData = response['data']['user'];

        // 🚀 ALWAYS save token (stay logged in forever like WhatsApp)
        await ApiService.saveToken(token);
        await _saveUserToStorage(userData);

        // Remember Me ONLY controls credential auto-fill (saved separately)
        final prefs = await SharedPreferences.getInstance();
        if (rememberMe) {
          await prefs.setString('pv_saved_email', email);
          await prefs.setString('pv_saved_password', password); // In production, consider not saving password
        } else {
          // Clear saved credentials when Remember Me is unchecked
          await prefs.remove('pv_saved_email');
          await prefs.remove('pv_saved_password');
        }

        _user = userData;
        _isAuthenticated = true;
        _errorMessage = null;
        
        // Start auto token refresh
        _startTokenRefresh();
        
        notifyListeners();
        
        return {'success': true};
      } else {
        _errorMessage = response['message'] ?? 'Login failed';
        notifyListeners();
        return {'success': false, 'message': _errorMessage};
      }
    } catch (e) {
      _errorMessage = 'Network error: $e';
      notifyListeners();
      return {'success': false, 'message': _errorMessage};
    }
  }

  // Signup
  Future<Map<String, dynamic>> signup(String fullName, String email, String password) async {
    try {
      _errorMessage = null;
      notifyListeners();

      final response = await ApiService.signup(fullName, email, password);

      if (response['success'] == true) {
        final token = response['data']['token'];
        final userData = response['data']['user'];

        await ApiService.saveToken(token);
        await _saveUserToStorage(userData);

        _user = userData;
        _isAuthenticated = true;
        _errorMessage = null;
        
        // Start auto token refresh
        _startTokenRefresh();
        
        notifyListeners();
        return {'success': true};
      } else {
        _errorMessage = response['message'] ?? 'Signup failed';
        notifyListeners();
        return {'success': false, 'message': _errorMessage};
      }
    } catch (e) {
      _errorMessage = 'Network error: $e';
      notifyListeners();
      return {'success': false, 'message': _errorMessage};
    }
  }

  // Logout
  Future<void> logout() async {
    // Stop token refresh
    _stopTokenRefresh();
    
    await ApiService.deleteToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pv_user');

    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  // Save user to storage
  Future<void> _saveUserToStorage(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    final userString = '${userData['full_name'] ?? userData['email']},${userData['email']}';
    await prefs.setString('pv_user', userString);
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
