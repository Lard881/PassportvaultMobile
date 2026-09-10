import 'package:flutter/material.dart';

class BiometricSetupModal extends StatefulWidget {
  final Function(String method, {String? pin}) onSubmit;

  const BiometricSetupModal({
    super.key,
    required this.onSubmit,
  });

  @override
  State<BiometricSetupModal> createState() => _BiometricSetupModalState();
}

class _BiometricSetupModalState extends State<BiometricSetupModal> {
  String? _selectedMethod;
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  String? _pinError;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (_selectedMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an authentication method')),
      );
      return;
    }

    if (_selectedMethod == 'pin') {
      final pin = _pinController.text.trim();
      final confirmPin = _confirmPinController.text.trim();

      if (pin.length < 4 || pin.length > 8) {
        setState(() => _pinError = 'PIN must be between 4 and 8 digits');
        return;
      }
      if (!RegExp(r'^\d+$').hasMatch(pin)) {
        setState(() => _pinError = 'PIN must contain only numbers');
        return;
      }
      if (pin != confirmPin) {
        setState(() => _pinError = 'PINs do not match');
        return;
      }

      setState(() => _pinError = null);
      widget.onSubmit('pin', pin: pin);
      Navigator.of(context).pop();
    } else {
      widget.onSubmit('biometric');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF242424) : Colors.white;
    final textColor = isDark ? const Color(0xFFF8F9FA) : const Color(0xFF212529);
    final subtitleColor = isDark ? const Color(0xFFADB5BD) : const Color(0xFF6C757D);
    final cardBg = isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF8F9FA);
    final borderColor = isDark ? const Color(0xFF404040) : const Color(0xFFE0E0E0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(0),
      child: Container(
        margin: const EdgeInsets.only(top: 80),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Modal Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Setup App Lock',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: textColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose your preferred security method to protect your app:',
                      style: TextStyle(
                        fontSize: 15,
                        color: subtitleColor,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Biometric Option (Fingerprint / Face ID / Recognition)
                    _buildSecurityOption(
                      icon: Icons.fingerprint,
                      title: 'Biometric Authentication',
                      description: 'Fingerprint, Face ID, or Face Recognition unlock',
                      value: 'biometric',
                      isSelected: _selectedMethod == 'biometric',
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textColor: textColor,
                      subtitleColor: subtitleColor,
                      onTap: () {
                        setState(() {
                          _selectedMethod = 'biometric';
                          _pinError = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // PIN Option
                    _buildSecurityOption(
                      icon: Icons.pin,
                      title: 'PIN Code',
                      description: 'Set a 4 to 8 digit secure numeric PIN',
                      value: 'pin',
                      isSelected: _selectedMethod == 'pin',
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textColor: textColor,
                      subtitleColor: subtitleColor,
                      onTap: () {
                        setState(() {
                          _selectedMethod = 'pin';
                          _pinError = null;
                        });
                      },
                    ),

                    // If PIN is selected, show entry fields
                    if (_selectedMethod == 'pin') ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF0d6efd).withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create your PIN',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _pinController,
                              keyboardType: TextInputType.number,
                              obscureText: _obscurePin,
                              maxLength: 8,
                              style: TextStyle(color: textColor, letterSpacing: 4),
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: 'Enter 4-8 digit PIN',
                                hintStyle: TextStyle(color: subtitleColor),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePin ? Icons.visibility : Icons.visibility_off),
                                  onPressed: () => setState(() => _obscurePin = !_obscurePin),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Confirm PIN',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _confirmPinController,
                              keyboardType: TextInputType.number,
                              obscureText: _obscureConfirmPin,
                              maxLength: 8,
                              style: TextStyle(color: textColor, letterSpacing: 4),
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: 'Re-enter PIN to confirm',
                                hintStyle: TextStyle(color: subtitleColor),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                prefixIcon: const Icon(Icons.lock_reset),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscureConfirmPin ? Icons.visibility : Icons.visibility_off),
                                  onPressed: () => setState(() => _obscureConfirmPin = !_obscureConfirmPin),
                                ),
                              ),
                            ),
                            if (_pinError != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _pinError!,
                                style: const TextStyle(color: Color(0xFFdc3545), fontSize: 13),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 20),
                    
                    // Info Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF332B00) : const Color(0xFFfff3cd),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFffc107).withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Color(0xFFffc107),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You can switch or remove your authentication method anytime in Settings.',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFFFFE082) : const Color(0xFF856404),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0d6efd),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 48),
                            ),
                            child: const Text('Enable'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityOption({
    required IconData icon,
    required String title,
    required String description,
    required String value,
    required bool isSelected,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subtitleColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0d6efd).withValues(alpha: 0.15)
              : cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0d6efd)
                : borderColor,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF0d6efd)
                    : (isDark ? const Color(0xFF404040) : const Color(0xFF6c757d)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFF0d6efd)
                          : textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF0d6efd),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
