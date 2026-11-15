import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Device-local app lock using the operating system's authentication prompt.
class BiometricAuthService {
  static const String _storageKey = 'pv_biometric_enabled';
  static const String _pinKey = 'pv_pin_hash';
  static const String _appLockEnabledKey = 'pv_app_lock_enabled';

  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if biometric authentication is available on this device
  Future<Map<String, dynamic>> isAvailable() async {
    try {
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!isDeviceSupported) {
        return {
          'available': false,
          'reason': 'This device does not support system authentication.',
          'fallback': 'pin'
        };
      }

      final List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();

      String deviceUnlockType = 'device passcode';
      if (availableBiometrics.contains(BiometricType.face)) {
        deviceUnlockType = 'Face ID or device passcode';
      } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
        deviceUnlockType = 'fingerprint or device passcode';
      } else if (availableBiometrics.contains(BiometricType.iris)) {
        deviceUnlockType = 'biometric or device passcode';
      }

      return {
        'available': true,
        'type': 'device',
        'biometricType': deviceUnlockType,
        'message': 'Use $deviceUnlockType to unlock PassportVault.'
      };
    } catch (e) {
      return {
        'available': false,
        'reason': 'Could not check device authentication support: $e',
        'fallback': 'pin'
      };
    }
  }

  static bool isAuthenticating = false;

  /// Register/Enable biometric authentication
  Future<Map<String, dynamic>> enableBiometric() async {
    try {
      isAuthenticating = true;
      final availability = await isAvailable();

      if (availability['available'] != true) {
        return {
          'success': false,
          'message': availability['reason'] ?? 'Device authentication not available'
        };
      }

      final bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Confirm your device unlock to protect PassportVault',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (authenticated) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_storageKey, 'biometric');
        await prefs.setBool(_appLockEnabledKey, true);

        return {
          'success': true,
          'message': 'Device unlock enabled for this device.'
        };
      } else {
        return {
          'success': false,
          'message': 'Setup was cancelled. You can try again or use an app PIN.'
        };
      }
    } on PlatformException catch (e) {
      if (e.code == 'NotAvailable') {
        return {
          'success': false,
          'message': 'Device authentication not available'
        };
      } else if (e.code == 'NotEnrolled') {
        return {
          'success': false,
          'message':
              'Set up Face ID, fingerprint, or a device passcode in system settings first.'
        };
      } else if (e.code == 'LockedOut') {
        return {
          'success': false,
          'message':
              'Too many failed attempts. Please try again later.'
        };
      }
      return {'success': false, 'message': 'Error: ${e.message}'};
    } catch (e) {
      return {'success': false, 'message': 'Unexpected error: $e'};
    } finally {
      isAuthenticating = false;
    }
  }

  /// Authenticate using the operating system's biometric or device-credential prompt.
  Future<Map<String, dynamic>> authenticateBiometric() async {
    try {
      isAuthenticating = true;
      final bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock PassportVault',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (authenticated) {
        return {
          'success': true,
          'message': 'Device unlock successful.',
          'authenticated': true
        };
      } else {
        return {
          'success': false,
          'message': 'Unlock was cancelled. Try again or use your device passcode.'
        };
      }
    } on PlatformException catch (e) {
      if (e.code == 'NotAvailable') {
        return {
          'success': false,
          'message': 'Device authentication not available'
        };
      } else if (e.code == 'NotEnrolled') {
        return {
          'success': false,
          'message': 'Set up a device passcode or biometric method in system settings.'
        };
      } else if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
        return {
          'success': false,
          'message': 'Too many failed attempts. Please try again later.'
        };
      }
      return {'success': false, 'message': e.message ?? 'Authentication failed'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    } finally {
      isAuthenticating = false;
    }
  }

  /// Remove biometric authentication
  Future<Map<String, dynamic>> removeBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, 'none');
    await prefs.setBool(_appLockEnabledKey, false);
    return {'success': true, 'message': 'Biometric authentication removed'};
  }

  /// Check if biometric is currently enabled
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final method = prefs.getString(_storageKey);
    return method == 'biometric';
  }

  /// Check if app lock is enabled (biometric or PIN)
  Future<bool> isAppLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final isExplicitlyEnabled = prefs.getBool(_appLockEnabledKey);
    if (isExplicitlyEnabled == false) return false;
    final method = prefs.getString(_storageKey) ?? 'none';
    return isExplicitlyEnabled == true || method != 'none';
  }

  // ========== PIN AUTHENTICATION (FALLBACK) ==========

  /// Set up PIN authentication
  Future<Map<String, dynamic>> setupPIN(String pin) async {
    if (pin.length < 4 || pin.length > 8) {
      return {
        'success': false,
        'message': 'PIN must be between 4 and 8 digits'
      };
    }

    if (!RegExp(r'^\d+$').hasMatch(pin)) {
      return {'success': false, 'message': 'PIN must contain only numbers'};
    }

    final hash = _hashPIN(pin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, hash);
    await prefs.setString(_storageKey, 'pin');
    await prefs.setBool(_appLockEnabledKey, true);

    return {'success': true, 'message': 'PIN authentication set up successfully'};
  }

  /// Verify PIN
  Future<Map<String, dynamic>> verifyPIN(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_pinKey);

    if (storedHash == null) {
      return {
        'success': false,
        'message': 'No PIN set up. Please set up PIN first.'
      };
    }

    final hash = _hashPIN(pin);

    if (hash == storedHash) {
      return {
        'success': true,
        'message': 'PIN verified successfully',
        'authenticated': true
      };
    } else {
      return {'success': false, 'message': 'Incorrect PIN'};
    }
  }

  /// Change PIN
  Future<Map<String, dynamic>> changePIN(String oldPin, String newPin) async {
    final verifyResult = await verifyPIN(oldPin);

    if (verifyResult['success'] != true) {
      return {'success': false, 'message': 'Current PIN is incorrect'};
    }

    return await setupPIN(newPin);
  }

  /// Remove PIN authentication
  Future<Map<String, dynamic>> removePIN() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    await prefs.setString(_storageKey, 'none');
    await prefs.setBool(_appLockEnabledKey, false);
    return {'success': true, 'message': 'PIN authentication removed'};
  }

  /// Check if PIN is set up
  Future<bool> hasPIN() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_pinKey);
  }

  /// Get current authentication method
  Future<String> getAuthMethod() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_storageKey) ?? 'none';
  }

  /// Clear all authentication data
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await prefs.remove(_pinKey);
    await prefs.remove(_appLockEnabledKey);
  }

  // ========== HELPER METHODS ==========

  /// Simple PIN hash using SHA-256
  String _hashPIN(String pin) {
    const salt = 'passportvault_salt';
    final bytes = utf8.encode(pin + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Stop authentication (cancel biometric prompt)
  Future<void> stopAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } catch (e) {
      // Ignore errors
    }
  }
}

// Export singleton instance
final biometricAuthService = BiometricAuthService();
