import 'package:flutter/material.dart';
import '../services/biometric_auth_service.dart';

/// AppLock Widget
/// Shows device unlock prompt (Fingerprint, Face ID, or Phone PIN)
class AppLock extends StatefulWidget {
  final VoidCallback onUnlock;
  final String? userName;

  const AppLock({
    super.key,
    required this.onUnlock,
    this.userName,
  });

  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> {
  final BiometricAuthService _biometricAuth = biometricAuthService;
  bool _isLoading = false;
  String? _errorMessage;
  bool _authAttempted = false;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    final isLockEnabled = await _biometricAuth.isAppLockEnabled();
    if (!isLockEnabled) {
      widget.onUnlock();
      return;
    }

    if (!_authAttempted) {
      _authAttempted = true;
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        await _handleUnlock();
      }
    }
  }

  Future<void> _handleUnlock() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _biometricAuth.authenticateBiometric();

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unlocked successfully'),
              backgroundColor: Color(0xFF198754),
              duration: Duration(seconds: 1),
            ),
          );
        }
        widget.onUnlock();
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Authentication failed';
        });
      }
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF18181B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subtitleColor = isDark ? const Color(0xFFADB5BD) : const Color(0xFF6C757D);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Lock Icon
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0d6efd).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    size: 44,
                    color: Color(0xFF0d6efd),
                  ),
                ),
                const SizedBox(height: 24),

                // App Name
                Text(
                  'PassportVault',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),

                // Welcome Message
                Text(
                  'Welcome back${widget.userName != null ? ', ${widget.userName}' : ''}',
                  style: TextStyle(
                    fontSize: 16,
                    color: subtitleColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Authentication Status Box
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFdc3545).withValues(alpha: 0.1),
                      border: Border.all(color: const Color(0xFFdc3545).withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Color(0xFFdc3545)),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Unlock Action Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleUnlock,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.security),
                    label: Text(
                      _isLoading ? 'Authenticating...' : 'Unlock with Phone Lock',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0d6efd),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
