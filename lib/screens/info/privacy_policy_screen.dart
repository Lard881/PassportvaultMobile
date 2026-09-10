import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF8F9FA) : const Color(0xFF212529);
    final subtitleColor = isDark ? const Color(0xFFADB5BD) : const Color(0xFF6C757D);
    final bodyColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF333333);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(localeProvider.tr('privacy_policy'), style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF0d6efd),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            localeProvider.tr('privacy_policy'),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Last updated: January 2025',
            style: TextStyle(color: subtitleColor),
          ),
          const SizedBox(height: 24),
          
          Text(
            '1. Information We Collect',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
          ),
          const SizedBox(height: 12),
          Text(
            'We collect information you provide directly to us, including your name, email address, and the documents you choose to store in PassportVault.',
            style: TextStyle(height: 1.5, color: bodyColor),
          ),
          const SizedBox(height: 20),
          
          Text(
            '2. How We Use Your Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
          ),
          const SizedBox(height: 12),
          Text(
            'We use the information we collect to provide, maintain, and improve our services, send you notifications about expiring documents, and communicate with you about our service.',
            style: TextStyle(height: 1.5, color: bodyColor),
          ),
          const SizedBox(height: 20),
          
          Text(
            '3. Data Security',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
          ),
          const SizedBox(height: 12),
          Text(
            'We use industry-standard encryption and security measures to protect your data. All documents are encrypted both in transit and at rest.',
            style: TextStyle(height: 1.5, color: bodyColor),
          ),
          const SizedBox(height: 20),
          
          Text(
            '4. Data Sharing',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
          ),
          const SizedBox(height: 12),
          Text(
            'We do not sell, trade, or rent your personal information to third parties. We may share your information only when required by law or to protect our rights.',
            style: TextStyle(height: 1.5, color: bodyColor),
          ),
          const SizedBox(height: 20),
          
          Text(
            '5. Your Rights',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
          ),
          const SizedBox(height: 12),
          Text(
            'You have the right to access, update, or delete your personal information at any time. Contact us at support@passportvault.com for assistance.',
            style: TextStyle(height: 1.5, color: bodyColor),
          ),
          const SizedBox(height: 20),
          
          Text(
            '6. Changes to This Policy',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
          ),
          const SizedBox(height: 12),
          Text(
            'We may update this privacy policy from time to time. We will notify you of any changes by posting the new policy on this page.',
            style: TextStyle(height: 1.5, color: bodyColor),
          ),
          const SizedBox(height: 20),
          
          Text(
            'Contact Us',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
          ),
          const SizedBox(height: 12),
          Text(
            'If you have questions about this Privacy Policy, please contact us at support@passportvault.com.',
            style: TextStyle(height: 1.5, color: bodyColor),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
