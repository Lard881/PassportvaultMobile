import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/biometric_auth_service.dart';

/// AppLock Widget
/// Shows the configured device-unlock prompt or app PIN.
class AppLock extends StatefulWidget {
  final VoidCallback onUnlock;
  final String? userName;

  const AppLock({super.key, required this.onUnlock, this.userName});

  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> {
  final BiometricAuthService _biometricAuth = biometricAuthService;
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePin = true;
  bool _showPasswordInput = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _authAttempted = false;
  String _authMethod = 'biometric';

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _initializeAuth() async {
    final isLockEnabled = await _biometricAuth.isAppLockEnabled();
    if (!isLockEnabled) {
      widget.onUnlock();
      return;
    }

    final authMethod = await _biometricAuth.getAuthMethod();
    if (!mounted) return;
    setState(() {
      _authMethod = authMethod;
    });

    if (authMethod == 'biometric' && !_authAttempted) {
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

  Future<void> _handlePinUnlock() async {
    if (_pinController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Enter your app PIN to unlock.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _biometricAuth.verifyPIN(_pinController.text);
      if (result['success'] == true) {
        widget.onUnlock();
      } else if (mounted) {
        setState(() {
          _errorMessage = result['message'] ?? 'The PIN was not accepted.';
          _pinController.clear();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not verify the PIN. Try again.';
          _pinController.clear();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handlePasswordUnlock() async {
    final email = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).user?['email']?.toString();
    final password = _passwordController.text;

    if (email == null || email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = password.isEmpty
            ? 'Enter your account password to unlock.'
            : 'Could not find the signed-in account. Sign in again.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.login(email, password);
      if (response['success'] == true) {
        final data = response['data'];
        final token = data is Map ? data['token'] : null;
        if (token is! String || token.isEmpty) {
          throw StateError(
            'The sign-in response did not include a session token.',
          );
        }
        await ApiService.saveToken(token);
        widget.onUnlock();
      } else if (mounted) {
        setState(() {
          _errorMessage =
              response['message'] ?? 'The password was not accepted.';
          _passwordController.clear();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.toString();
          _passwordController.clear();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showPasswordFallback() {
    setState(() {
      _showPasswordInput = true;
      _errorMessage = null;
      _passwordController.clear();
    });
  }

  void _showPrimaryUnlock() {
    setState(() {
      _showPasswordInput = false;
      _errorMessage = null;
      _passwordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF18181B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subtitleColor = isDark
        ? const Color(0xFFADB5BD)
        : const Color(0xFF6C757D);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
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
                    child: Icon(
                      _authMethod == 'pin' ? Icons.pin : Icons.fingerprint,
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
                    style: TextStyle(fontSize: 16, color: subtitleColor),
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
                        border: Border.all(
                          color: const Color(0xFFdc3545).withValues(alpha: 0.3),
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Color(0xFFdc3545)),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  if (_showPasswordInput) ...[
                    TextField(
                      controller: _passwordController,
                      keyboardType: TextInputType.text,
                      obscureText: !_obscurePassword,
                      autofocus: true,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _handlePasswordUnlock(),
                      decoration: InputDecoration(
                        labelText: 'Account password',
                        hintText: 'Enter your account password',
                        prefixIcon: const Icon(Icons.key),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else if (_authMethod == 'pin') ...[
                    TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      obscureText: _obscurePin,
                      maxLength: 8,
                      autofocus: true,
                      onSubmitted: (_) => _handlePinUnlock(),
                      decoration: InputDecoration(
                        labelText: 'App PIN',
                        hintText: 'Enter your 4-8 digit PIN',
                        counterText: '',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _obscurePin = !_obscurePin),
                          icon: Icon(
                            _obscurePin
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          tooltip: _obscurePin ? 'Show PIN' : 'Hide PIN',
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Text(
                      'Use Face ID, fingerprint, or your device passcode to unlock.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: subtitleColor, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                  ],

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : _showPasswordInput
                          ? _handlePasswordUnlock
                          : (_authMethod == 'pin'
                                ? _handlePinUnlock
                                : _handleUnlock),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Icon(
                              _showPasswordInput
                                  ? Icons.lock_open
                                  : (_authMethod == 'pin'
                                        ? Icons.lock_open
                                        : Icons.fingerprint),
                            ),
                      label: Text(
                        _isLoading
                            ? 'Authenticating...'
                            : _showPasswordInput || _authMethod == 'pin'
                            ? 'Unlock'
                            : 'Try Device Unlock Again',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
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
                  if (!_showPasswordInput) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _isLoading ? null : _showPasswordFallback,
                      icon: const Icon(Icons.key),
                      label: const Text('Use account password instead'),
                    ),
                  ],
                  if (_showPasswordInput && _authMethod != 'pin') ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isLoading ? null : _showPrimaryUnlock,
                      child: const Text('Back to device unlock'),
                    ),
                  ],
                  if (_authMethod == 'pin' && !_showPasswordInput) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _isLoading ? null : _handleUnlock,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Use device unlock instead'),
                    ),
                  ],
                  if (_authMethod == 'pin' && _showPasswordInput) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isLoading ? null : _showPrimaryUnlock,
                      child: const Text('Back to app PIN'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'App lock is local to this device. Your account password remains separate.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: subtitleColor),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
