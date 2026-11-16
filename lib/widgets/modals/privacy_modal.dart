import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

class PrivacyModal extends StatelessWidget {
  const PrivacyModal({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
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
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Privacy Policy',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
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
                      'Effective date: To be confirmed',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    _buildSection(
                      '1. Information We Collect',
                      'PassportVault collects and stores your personal information including:\n\n'
                      '• Personal identity information (name, date of birth, nationality)\n'
                      '• Travel documents (passports, visas, IDs)\n'
                      '• Document images and scans\n'
                      '• Account information (email, password)\n'
                      '• Usage data and preferences',
                    ),
                    
                    _buildSection(
                      '2. How We Use Your Information',
                      'We use your information to:\n\n'
                      '• Provide secure storage for your documents\n'
                      '• Send expiry notifications and reminders\n'
                      '• Improve our services and user experience\n'
                      '• Provide customer support\n'
                      '• Maintain security and prevent fraud',
                    ),
                    
                    _buildSection(
                      '3. Data Security',
                      'We take your security seriously:\n\n'
                      '• All data is encrypted in transit and at rest\n'
                      '• We use industry-standard security measures\n'
                      '• Regular security audits and updates\n'
                      '• Biometric authentication options\n'
                      '• Secure cloud storage with backup',
                    ),
                    
                    _buildSection(
                      '4. Data Sharing',
                      'We do not sell your personal information. We may share data with:\n\n'
                      '• Service providers who assist our operations\n'
                      '• Law enforcement when legally required\n'
                      '• Users you explicitly choose to share with\n\n'
                      'All third parties are bound by strict confidentiality agreements.',
                    ),
                    
                    _buildSection(
                      '5. Your Rights',
                      'You have the right to:\n\n'
                      '• Access your personal data\n'
                      '• Correct inaccurate information\n'
                      '• Delete your account and data\n'
                      '• Export your data\n'
                      '• Opt-out of notifications\n'
                      '• Withdraw consent at any time',
                    ),
                    
                    _buildSection(
                      '6. Data Retention',
                      'We retain your data for as long as your account is active. '
                      'When you delete your account, all data is permanently removed '
                      'within 30 days, except where retention is required by law.',
                    ),
                    
                    _buildSection(
                      '7. Children\'s Privacy',
                      'Our service is not intended for children under 13. '
                      'We do not knowingly collect information from children under 13. '
                      'If you believe we have collected such information, please contact us.',
                    ),
                    
                    _buildSection(
                      '8. Changes to This Policy',
                      'We may update this policy from time to time. '
                      'We will notify you of any material changes via email or app notification. '
                      'Continued use of the service after changes constitutes acceptance.',
                    ),
                    
                    _buildSection(
                      '9. Contact Us',
                      'If you have questions about this Privacy Policy, please contact us at:\n\n'
                      'Email: privacy@passportvault.com\n'
                      'Website: www.passportvault.com/contact',
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Close Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
