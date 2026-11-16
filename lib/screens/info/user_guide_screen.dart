import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import 'support_screen.dart';

class UserGuideScreen extends StatelessWidget {
  const UserGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;
    final subtitleColor = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.lightTextSecondary;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.darkBgPrimary
          : AppTheme.lightBgSecondary,
      appBar: AppBar(
        title: const Text('User Guide', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: isDark ? AppTheme.darkBgCard : AppTheme.lightBgCard,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'User Guide',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Learn how to use PassportVault',
            style: TextStyle(
              fontSize: 14,
              color: subtitleColor,
            ),
          ),
          const SizedBox(height: 24),

          _buildGuideSection(
            context,
            '🚀 Getting Started',
            [
              'Create your account with email and password',
              'Verify your email address',
              'Set up biometric authentication (optional)',
              'Enable notifications to track expiry dates',
            ],
          ),

          _buildGuideSection(
            context,
            '👤 Managing Profiles',
            [
              'Add profiles for yourself and family members',
              'Upload profile photos',
              'Store passport, visa, ID card details',
              'Track document expiry dates',
              'Edit or delete profiles anytime',
            ],
          ),

          _buildGuideSection(
            context,
            '📄 Managing Documents',
            [
              'Upload documents (PDF, images)',
              'Attach documents to profiles',
              'Add issue and expiry dates',
              'Search and filter documents',
              'View, download, or share documents',
              'Export all documents as JSON',
            ],
          ),

          _buildGuideSection(
            context,
            '📅 Calendar & Reminders',
            [
              'View all expiry dates in calendar',
              'Get notified before documents expire',
              'See expired and expiring soon documents',
              'Filter by time period (30, 90 days, later)',
            ],
          ),

          _buildGuideSection(
            context,
            '🔔 Notifications',
            [
              'Enable push notifications in Settings',
              'Get alerts for expiring documents',
              'View notification history',
              'Mark notifications as read',
              'Filter by priority (HIGH, MEDIUM, LOW)',
            ],
          ),

          _buildGuideSection(
            context,
            '🔗 Secure Sharing',
            [
              'Create secure share links for documents',
              'Set password protection',
              'Set expiration date and view limits',
              'Share via WhatsApp, Email, Telegram',
              'Revoke access anytime',
              'Track view count',
            ],
          ),

          _buildGuideSection(
            context,
            '💾 Backup & Storage',
            [
              'Review the automatic-backup preference on the Backup & Restore screen',
              'Use Back Up Now to create a backup manually',
              'Check the latest backup time and contents before restoring',
              'Restore replaces current data after confirmation',
            ],
          ),

          _buildGuideSection(
            context,
            '🔐 Security Tips',
            [
              'Use a strong password',
              'Enable biometric authentication',
              'Never share your password',
              'Keep your email secure',
              'Regularly backup your data',
              'Use secure share links with passwords',
            ],
          ),

          _buildGuideSection(
            context,
            '❓ FAQs',
            [
              'Q: Is my data secure?\nA: Review the Privacy Policy and Security settings for information about how the app handles your data.',
              '',
              'Q: Can I use this on multiple devices?\nA: Yes, login with your account on any device.',
              '',
              'Q: How do I recover my password?\nA: Use "Forgot Password" on login screen.',
              '',
              'Q: What file formats are supported?\nA: PDF, JPG, PNG, and most image formats.',
              '',
              'Q: Can I export my data?\nA: Check the available export actions on the Documents screen.',
            ],
          ),

          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Icon(Icons.headset, color: Colors.white, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Need More Help?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Contact our support team',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SupportScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.email),
                  label: const Text('Contact Support'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildGuideSection(BuildContext context, String title, List<String> items) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map((item) {
            if (item.isEmpty) {
              return const SizedBox(height: 8);
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!item.startsWith('Q:'))
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(
                        Icons.check_circle,
                        size: 16,
                        color: AppTheme.successColor,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 14,
                        color: item.startsWith('Q:') ? textColor : subtitleColor,
                        fontWeight: item.startsWith('Q:') || item.startsWith('A:')
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
