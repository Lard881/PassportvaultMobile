import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../services/biometric_auth_service.dart';
import '../../widgets/modals/change_password_modal.dart';
import '../../widgets/modals/biometric_setup_modal.dart';
import '../../widgets/modals/privacy_modal.dart';
import '../../widgets/modals/terms_modal.dart';
import '../info/user_guide_screen.dart';
import '../info/support_screen.dart';
import '../../utils/responsive.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final BiometricAuthService biometricAuthService = BiometricAuthService();

  bool _isLoading = true;
  bool _biometricEnabled = false;
  String _authMethod = 'none';
  String _language = 'English';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();

      final response = await ApiService.getSettings();
      
      if (response['success'] == true && response['data'] != null) {
        final settings = response['data'];
        setState(() {
          
          final backendLang = settings['language']?.toString() ?? 'English';
          final validLanguages = ['English', 'Spanish', 'French', 'German', 'Chinese', 'Arabic', 'Korean'];
          _language = validLanguages.contains(backendLang) ? backendLang : 'English';
        });
      }

      // App-lock enrollment belongs to this device, not the user account.
      final localMethod = await biometricAuthService.getAuthMethod();
      if (mounted) {
        setState(() {
          _biometricEnabled = localMethod != 'none';
          _authMethod = localMethod;
        });
      }
    } catch (error) {
      debugPrint('[SettingsScreen] Failed to load settings: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    if (key != 'language') return;

    try {
      await ApiService.updateSettings({'language': value});
    } catch (error) {
      debugPrint('[SettingsScreen] Failed to sync setting to backend: $error');
    }
  }

  String _getAuthMethodLabel() {
    if (_authMethod == 'biometric' || _authMethod == 'true') {
      return 'Device unlock on this device';
    } else if (_authMethod == 'pin') {
      return 'PIN Authentication';
    }
    return 'Not Set';
  }

  Future<void> _handleBiometricToggle(bool value) async {
    if (value) {
      final res = await biometricAuthService.enableBiometric();
      if (res['success'] == true) {
        setState(() {
          _biometricEnabled = true;
          _authMethod = 'biometric';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Device unlock enabled on this device'),
              backgroundColor: Color(0xFF198754),
            ),
          );
        }
      } else {
        setState(() {
          _biometricEnabled = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Failed to enable device authentication'),
              backgroundColor: const Color(0xFFdc3545),
            ),
          );
        }
      }
    } else {
      await _removeAuthentication();
    }
  }

  Future<void> _removeAuthentication() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Authentication?'),
        content: Text(
          'Are you sure you want to remove ${_getAuthMethodLabel()}?\n\nYou will no longer be asked to unlock the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (_authMethod == 'biometric') {
        await biometricAuthService.removeBiometric();
      } else if (_authMethod == 'pin') {
        await biometricAuthService.removePIN();
      }
      
      setState(() {
        _biometricEnabled = false;
        _authMethod = 'none';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication removed'),
          ),
        );
      }
    }
  }

  void _showBiometricSetupModal() {
    showDialog(
      context: context,
      builder: (context) => BiometricSetupModal(
        onSubmit: _handleBiometricSetup,
      ),
    );
  }

  Future<void> _handleBiometricSetup(String method, {String? pin}) async {
    try {
      if (method == 'biometric') {
        final result = await biometricAuthService.enableBiometric();
        if (result['success'] != true) {
          throw Exception(result['message'] ?? 'Failed to enable biometric');
        }
        setState(() {
          _biometricEnabled = true;
          _authMethod = 'biometric';
        });
      } else if (method == 'pin') {
        if (pin == null || pin.isEmpty) {
          throw Exception('PIN was not provided');
        }
        final result = await biometricAuthService.setupPIN(pin);
        if (result['success'] != true) {
          throw Exception(result['message'] ?? 'Failed to set up PIN');
        }
        setState(() {
          _biometricEnabled = true;
          _authMethod = 'pin';
        });
      }
      
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${method == 'pin' ? 'App PIN' : 'Device unlock'} enabled on this device.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to setup authentication: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showChangePasswordModal() {
    showDialog(
      context: context,
      builder: (context) => ChangePasswordModal(
        onSubmit: _handleChangePassword,
      ),
    );
  }

  Future<String?> _handleChangePassword(String currentPassword, String newPassword) async {
    try {
      final response = await ApiService.changePassword(currentPassword, newPassword);
      
      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password changed successfully! Please login again.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          Future.delayed(const Duration(milliseconds: 1200), () async {
            if (mounted) {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.logout();
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            }
          });
        }
        return null;
      } else {
        return response['message'] ?? 'Failed to change password';
      }
    } catch (error) {
      return error.toString().replaceFirst('Exception: ', '');
    }
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => const PrivacyModal(),
    );
  }

  void _showTermsAndConditions() {
    showDialog(
      context: context,
      builder: (context) => const TermsModal(),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFdc3545)),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ApiService.logout();
      } catch (_) {}
      
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.logout();
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account', style: TextStyle(color: Color(0xFFdc3545), fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to permanently delete your account and all stored documents? This action CANNOT be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFdc3545),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ApiService.deleteAccount();
      } catch (_) {}

      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.logout();
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your account has been deleted.'),
            backgroundColor: Color(0xFFdc3545),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final isDark = themeProvider.isDark;

    final bgColor = isDark ? const Color(0xFF18181B) : const Color(0xFFF8F9FA);
    final cardBg = isDark ? const Color(0xFF242427) : Colors.white;
    final textColor = isDark ? const Color(0xFFF4F4F5) : const Color(0xFF212529);
    final subtitleColor = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF6C757D);
    final borderColor = isDark ? const Color(0xFF3F3F46) : const Color(0xFFDEE2E6);
    final tileBg = isDark ? const Color(0xFF2D2D30) : const Color(0xFFE3F2FD);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: Text(localeProvider.tr('settings'), style: const TextStyle(fontWeight: FontWeight.w700)),
          backgroundColor: const Color(0xFF0d6efd),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(localeProvider.tr('settings'), style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF0d6efd),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Page Title
          Text(
            localeProvider.tr('settings'),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            localeProvider.tr('manage_preferences'),
            style: TextStyle(
              fontSize: 14,
              color: subtitleColor,
            ),
          ),
          const SizedBox(height: 24),

          // Appearance Card
          _buildCard(
            title: localeProvider.tr('appearance'),
            icon: Icons.palette,
            cardBg: cardBg,
            textColor: textColor,
            borderColor: borderColor,
            children: [
              _buildCardSwitchTile(
                localeProvider.tr('dark_mode'),
                localeProvider.tr('dark_mode_desc'),
                themeProvider.isDark,
                (value) async {
                  await themeProvider.toggleTheme();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(themeProvider.isDark ? 'Dark mode enabled' : 'Light mode enabled'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
                textColor,
                subtitleColor,
              ),
            ],
          ),

          const SizedBox(height: 16),

          const SizedBox(height: 16),

          // Security Card
          _buildCard(
            title: localeProvider.tr('security'),
            icon: Icons.verified_user,
            cardBg: cardBg,
            textColor: textColor,
            borderColor: borderColor,
            children: [
              _buildNavigationTile(
                'Push Notifications',
                'Configure expiry reminder notifications',
                Icons.notifications_active,
                () => Navigator.pushNamed(context, '/notification-settings'),
                textColor,
                subtitleColor,
                borderColor,
                tileBg,
              ),
              const SizedBox(height: 12),
              _buildCardSwitchTile(
                'App lock',
                _biometricEnabled
                    ? _getAuthMethodLabel()
                    : 'Choose device unlock or an app PIN. This setting stays on this device.',
                _biometricEnabled,
                _handleBiometricToggle,
                textColor,
                subtitleColor,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showChangePasswordModal,
                  icon: const Icon(Icons.key),
                  label: Text(localeProvider.tr('change_password')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0d6efd),
                    side: const BorderSide(color: Color(0xFF0d6efd)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (_biometricEnabled) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showBiometricSetupModal,
                    icon: const Icon(Icons.settings),
                    label: Text(localeProvider.tr('change_auth_method')),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _removeAuthentication,
                    icon: const Icon(Icons.delete),
                    label: Text(localeProvider.tr('remove_auth')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFdc3545),
                      side: const BorderSide(color: Color(0xFFdc3545)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCFE2FF),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFF9EC5FE)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, size: 16, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF084298)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${localeProvider.tr('current_method')}: ${_getAuthMethodLabel()}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF084298),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),



          const SizedBox(height: 16),

          // Language Card
          _buildCard(
            title: localeProvider.tr('language_region'),
            icon: Icons.language,
            cardBg: cardBg,
            textColor: textColor,
            borderColor: borderColor,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: ['English', 'Spanish', 'French', 'German', 'Chinese', 'Arabic', 'Korean'].contains(_language)
                        ? _language
                        : localeProvider.currentLanguageName,
                    dropdownColor: cardBg,
                    isExpanded: true,
                    style: TextStyle(color: textColor, fontSize: 14),
                    items: const [
                      DropdownMenuItem(value: 'English', child: Text('🇺🇸 English')),
                      DropdownMenuItem(value: 'Spanish', child: Text('🇪🇸 Español (Spanish)')),
                      DropdownMenuItem(value: 'French', child: Text('🇫🇷 Français (French)')),
                      DropdownMenuItem(value: 'German', child: Text('🇩🇪 Deutsch (German)')),
                      DropdownMenuItem(value: 'Chinese', child: Text('🇨🇳 中文 (Chinese)')),
                      DropdownMenuItem(value: 'Arabic', child: Text('🇸🇦 العربية (Arabic)')),
                      DropdownMenuItem(value: 'Korean', child: Text('🇰🇷 한국어 (Korean)')),
                    ],
                    onChanged: (value) async {
                      if (value != null) {
                        setState(() => _language = value);
                        await localeProvider.setLocale(value);
                        _updateSetting('language', value);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Need Help Card
          _buildCard(
            title: localeProvider.tr('need_help'),
            icon: Icons.help_outline,
            cardBg: cardBg,
            textColor: textColor,
            borderColor: borderColor,
            children: [
              _buildNavigationTile(
                localeProvider.tr('user_guide'),
                localeProvider.tr('user_guide_desc'),
                Icons.book,
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserGuideScreen())),
                textColor,
                subtitleColor,
                borderColor,
                tileBg,
              ),
              const SizedBox(height: 8),
              _buildNavigationTile(
                localeProvider.tr('contact_support'),
                localeProvider.tr('contact_support_desc'),
                Icons.headset,
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen())),
                textColor,
                subtitleColor,
                borderColor,
                tileBg,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // About Card
          _buildCard(
            title: localeProvider.tr('about'),
            icon: Icons.info_outline,
            cardBg: cardBg,
            textColor: textColor,
            borderColor: borderColor,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(localeProvider.tr('version'), style: TextStyle(fontSize: 13, color: subtitleColor)),
                    const SizedBox(height: 4),
                    Text('1.0.0', style: TextStyle(fontWeight: FontWeight.w500, color: textColor)),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showPrivacyPolicy,
                  icon: const Icon(Icons.shield),
                  label: Text(localeProvider.tr('privacy_policy')),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showTermsAndConditions,
                  icon: const Icon(Icons.description),
                  label: Text(localeProvider.tr('terms_of_service')),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Logout Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout),
              label: Text(localeProvider.tr('logout'), style: const TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFdc3545),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Delete Account Button (Mandatory for App Store & Play Store Policy)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _handleDeleteAccount,
              icon: const Icon(Icons.delete_forever, color: Color(0xFFdc3545)),
              label: const Text(
                'Delete Account',
                style: TextStyle(
                  color: Color(0xFFdc3545),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFdc3545)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required Color cardBg,
    required Color textColor,
    required Color borderColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF0d6efd)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildCardSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    Color textColor,
    Color subtitleColor,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: subtitleColor,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: const Color(0xFF0d6efd),
        ),
      ],
    );
  }

  Widget _buildNavigationTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color tileBg,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tileBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF0d6efd)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: subtitleColor),
          ],
        ),
      ),
    );
  }
}
