import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/modals/privacy_modal.dart';
import '../../widgets/modals/terms_modal.dart';
import '../info/support_screen.dart';
import '../info/user_guide_screen.dart';
import '../settings/fcm_notification_settings_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  void _handleLogout(BuildContext context) async {
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
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFdc3545),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ApiService.logout();
      } catch (_) {}
      
      if (context.mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.logout();
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const PrivacyModal(),
    );
  }

  void _showTermsAndConditions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const TermsModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF18181B) : const Color(0xFFF8F9FA);
    final cardBg = isDark ? const Color(0xFF242427) : Colors.white;
    final textColor = isDark ? const Color(0xFFF4F4F5) : const Color(0xFF212529);
    final subtitleColor = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF6C757D);
    final borderColor = isDark ? const Color(0xFF3F3F46) : const Color(0xFFDEE2E6);

    String getInitials() {
      if (user?['name'] != null && user!['name'].toString().trim().isNotEmpty) {
        final name = user['name'].toString().trim();
        return name[0].toUpperCase();
      } else if (user?['email'] != null && user!['email'].toString().trim().isNotEmpty) {
        final email = user['email'].toString().trim();
        return email[0].toUpperCase();
      }
      return 'U';
    }
    
    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: cardBg,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'More',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Additional features and settings',
                    style: TextStyle(
                      fontSize: 14,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // User Info Card
                if (user != null) ...[
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0d6efd),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              getInitials(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // User Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user['name']?.toString() ?? user['email']?.toString() ?? 'User',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user['email']?.toString() ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                
                // Menu Items
                _buildMenuItem(
                  context,
                  'Calendar',
                  'View expiry dates',
                  Icons.calendar_today,
                  const Color(0xFF0d6efd),
                  isDark ? const Color(0xFF1E3A5F) : const Color(0xFFe3f2fd),
                  '/calendar',
                  cardBg,
                  textColor,
                  subtitleColor,
                  borderColor,
                ),
                const SizedBox(height: 12),
                _buildMenuItem(
                  context,
                  'Notification Settings',
                  'Manage notification times and reminders',
                  Icons.notifications_outlined,
                  const Color(0xFFff9800),
                  isDark ? const Color(0xFF4A2C0F) : const Color(0xFFfff3e0),
                  '/notification-settings',
                  cardBg,
                  textColor,
                  subtitleColor,
                  borderColor,
                ),
                const SizedBox(height: 12),
                _buildMenuItem(
                  context,
                  'Secure Sharing',
                  'Share documents securely',
                  Icons.shield_outlined,
                  const Color(0xFF198754),
                  isDark ? const Color(0xFF14532D) : const Color(0xFFe8f5e9),
                  '/secure-sharing',
                  cardBg,
                  textColor,
                  subtitleColor,
                  borderColor,
                ),
                const SizedBox(height: 12),
                _buildMenuItem(
                  context,
                  'Backup & Restore',
                  'Manage your backups',
                  Icons.cloud_download_outlined,
                  const Color(0xFF0dcaf0),
                  isDark ? const Color(0xFF164E63) : const Color(0xFFe0f7fa),
                  '/backup-restore',
                  cardBg,
                  textColor,
                  subtitleColor,
                  borderColor,
                ),
                const SizedBox(height: 12),
                _buildMenuItem(
                  context,
                  'Settings',
                  'App preferences and configuration',
                  Icons.settings_outlined,
                  const Color(0xFF6c757d),
                  isDark ? const Color(0xFF27272A) : const Color(0xFFf8f9fa),
                  '/settings',
                  cardBg,
                  textColor,
                  subtitleColor,
                  borderColor,
                ),
                const SizedBox(height: 24),
                
                // Help & Support Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Help & Support',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildHelpButton(
                        context,
                        'User Guide',
                        Icons.help_outline,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UserGuideScreen(),
                            ),
                          );
                        },
                        textColor,
                        borderColor,
                      ),
                      const SizedBox(height: 12),
                      _buildHelpButton(
                        context,
                        'Contact Support',
                        Icons.mail_outline,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SupportScreen(),
                            ),
                          );
                        },
                        textColor,
                        borderColor,
                      ),
                      const SizedBox(height: 12),
                      _buildHelpButton(
                        context,
                        'Terms & Conditions',
                        Icons.description_outlined,
                        () => _showTermsAndConditions(context),
                        textColor,
                        borderColor,
                      ),
                      const SizedBox(height: 12),
                      _buildHelpButton(
                        context,
                        'Privacy Policy',
                        Icons.privacy_tip_outlined,
                        () => _showPrivacyPolicy(context),
                        textColor,
                        borderColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Version Info
                Center(
                  child: Column(
                    children: [
                      Text(
                        'PassportVault v1.0.0',
                        style: TextStyle(
                          fontSize: 14,
                          color: subtitleColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '© 2026 All rights reserved',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF71717A) : const Color(0xFF9ca3af),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Logout Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => _handleLogout(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFdc3545)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout, color: Color(0xFFdc3545)),
                        SizedBox(width: 8),
                        Text(
                          'Logout',
                          style: TextStyle(
                            color: Color(0xFFdc3545),
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color iconColor,
    Color iconBg,
    String route,
    Color cardBg,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
  ) {
    return InkWell(
      onTap: () {
        if (route == '/notification-settings') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const FCMNotificationSettingsScreen(),
            ),
          );
        } else {
          Navigator.pushNamed(context, route);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9ca3af), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpButton(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
    Color textColor,
    Color borderColor,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF0d6efd)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
