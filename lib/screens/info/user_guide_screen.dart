import 'package:flutter/material.dart';

class UserGuideScreen extends StatelessWidget {
  const UserGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF4F4F5) : const Color(0xFF212529);
    final subtitleColor = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF6C757D);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('User Guide', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF0d6efd),
        foregroundColor: Colors.white,
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
              'Enable auto-backup in Settings',
              'Manual backup anytime',
              'Monitor storage usage',
              'Restore from backup',
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
              'Q: Is my data secure?\nA: Yes! All data is encrypted and stored securely.',
              '',
              'Q: Can I use this on multiple devices?\nA: Yes, login with your account on any device.',
              '',
              'Q: How do I recover my password?\nA: Use "Forgot Password" on login screen.',
              '',
              'Q: What file formats are supported?\nA: PDF, JPG, PNG, and most image formats.',
              '',
              'Q: Can I export my data?\nA: Yes, use the Export button in Documents screen.',
            ],
          ),

          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0d6efd), Color(0xFF0b5ed7)],
              ),
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
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.email),
                  label: const Text('Contact Support'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0d6efd),
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
    final cardBg = isDark ? const Color(0xFF1E1E22) : Colors.white;
    final textColor = isDark ? const Color(0xFFF4F4F5) : const Color(0xFF212529);
    final subtitleColor = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF6C757D);
    final borderColor = isDark ? const Color(0xFF3F3F46) : const Color(0xFFDEE2E6);

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
                        color: Color(0xFF198754),
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
