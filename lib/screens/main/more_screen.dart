import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../config/app_theme.dart';
import '../../utils/date_formatter.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  int _alertCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAlertCount();
  }

  Future<void> _loadAlertCount() async {
    try {
      final response = await ApiService.getDocuments();
      if (mounted && response['success'] == true) {
        final documents = response['data'] as List? ?? [];
        setState(() {
          _alertCount = documents.where((document) {
            final expiryDate = document['expiry_date']?.toString();
            if (expiryDate == null || expiryDate.isEmpty) return false;
            final daysUntilExpiry = DateFormatter.daysUntilExpiry(expiryDate);
            return daysUntilExpiry != null && daysUntilExpiry <= 90;
          }).length;
        });
      }
    } catch (error) {
      debugPrint('[MoreScreen] Failed to load alert count: $error');
    }
  }

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
            style: TextButton.styleFrom(foregroundColor: AppTheme.dangerColor),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final didLogout = await authProvider.logout(revokeSession: true);
      if (context.mounted) {
        if (didLogout) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/login', (route) => false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.errorMessage ?? 'Unable to log out.'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark
        ? AppTheme.darkBgSecondary
        : AppTheme.lightBgSecondary;
    final cardBg = isDark ? AppTheme.darkBgCard : AppTheme.lightBgCard;
    final textColor = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;
    final subtitleColor = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.lightTextSecondary;
    final borderColor = isDark
        ? AppTheme.darkBorderColor
        : AppTheme.lightBorderColor;

    String getInitials() {
      final name = user?['name']?.toString().trim() ?? '';
      if (name.isNotEmpty) {
        return name
            .split(RegExp(r'\s+'))
            .take(2)
            .map((part) => part[0].toUpperCase())
            .join();
      }
      final email = user?['email']?.toString().trim() ?? '';
      return email.isNotEmpty ? email[0].toUpperCase() : 'U';
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
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
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(
                              alpha: 0.12,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              getInitials(),
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user['name']?.toString() ??
                                    user['email']?.toString() ??
                                    'User',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user['email']?.toString() ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
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

                _buildSectionLabel('VAULT', subtitleColor),
                _buildGroup([
                  _buildMenuItem(
                    context,
                    'Expiry calendar',
                    Icons.calendar_today_outlined,
                    '/calendar',
                  ),
                  _buildMenuItem(
                    context,
                    'Alerts',
                    Icons.warning_amber_outlined,
                    '/alerts',
                    badgeCount: _alertCount,
                  ),
                  _buildMenuItem(
                    context,
                    'Secure sharing',
                    Icons.link,
                    '/secure-sharing',
                  ),
                  _buildMenuItem(
                    context,
                    'Activity log',
                    Icons.monitor_heart_outlined,
                    '/activity-log',
                  ),
                  _buildMenuItem(
                    context,
                    'Backup & Restore',
                    Icons.cloud_upload_outlined,
                    '/backup-restore',
                  ),
                ]),
                const SizedBox(height: 20),
                _buildSectionLabel('APP', subtitleColor),
                _buildGroup([
                  _buildMenuItem(
                    context,
                    'Settings',
                    Icons.settings_outlined,
                    '/settings',
                  ),
                  _buildMenuItem(
                    context,
                    'Help & support',
                    Icons.help_outline,
                    '/support',
                  ),
                ]),
                const SizedBox(height: 24),

                // Version Info
                Center(
                  child: Column(
                    children: [
                      Text(
                        'PassportVault v1.0.0',
                        style: TextStyle(fontSize: 14, color: subtitleColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '© 2026 All rights reserved',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFF71717A)
                              : const Color(0xFF9ca3af),
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

  Widget _buildSectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildGroup(List<Widget> rows) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkBgCard : AppTheme.lightBgCard;
    final borderColor = isDark
        ? AppTheme.darkBorderColor
        : AppTheme.lightBorderColor;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            rows[index],
            if (index < rows.length - 1)
              Divider(height: 1, thickness: 1, indent: 54, color: borderColor),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    String title,
    IconData icon,
    String route, {
    int? badgeCount,
  }) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subtitleColor = Theme.of(context).textTheme.bodyMedium?.color;

    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Icon(icon, color: subtitleColor, size: 19),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              Container(
                constraints: const BoxConstraints(minWidth: 24),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.dangerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.dangerColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Icon(Icons.chevron_right, color: subtitleColor, size: 20),
          ],
        ),
      ),
    );
  }
}
