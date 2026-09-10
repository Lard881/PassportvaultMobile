import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

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
        title: Text(localeProvider.tr('terms_of_service'), style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF0d6efd),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            localeProvider.tr('terms_of_service'),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Last updated: January 2025',
            style: TextStyle(color: subtitleColor),
          ),
          const SizedBox(height: 24),
          
          Text(
            '1. Acceptance of Terms',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
          ),
          const SizedBox(height: 12),
          Text(
            'By accessing and using PassportVault, you accept and agree to be bound by the terms and provisions of this agreement.',
            style: TextStyle(height: 1.5, color: bodyColor),
          ),
          const SizedBox(height: 20),
          
          Text(
            '2. Use License',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
          ),
          const SizedBox(height: 12),
          Text(
            'Permission is granted to temporarily use PassportVault for personal, non-commercial purposes. This is the grant of a license, not a transfer of title.',
            style: TextStyle(height: 1.5, color: bodyColor),
          ),
          const SizedBox(height: 20),
          
          Text(
            '3. User Responsibilities',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
          ),
          const SizedBox(height: 12),
          Text(
            'You are responsible for maintaining the confidentiality of your account and password. You agree to accept responsibility for all activities that occur under your account.',
            style: TextStyle(height: 1.5, color: bodyColor),
          ),
          const SizedBox(height: 20),
          
          Text(
            '4. Privacy',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
          ),
          const SizedBox(height: 12),
          Text(
            'Your use of PassportVault is also governed by our Privacy Policy. Please review our Privacy Policy to understand our practices.',
            style: TextStyle(height: 1.5, color: bodyColor),
          ),
          const SizedBox(height: 20),
          
          Text(
            '5. Disclaimer',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
          ),
          const SizedBox(height: 12),
          Text(
            'The service is provided "as is" without warranties of any kind, either express or implied. We do not warrant that the service will be uninterrupted or error-free.',
            style: TextStyle(height: 1.5, color: bodyColor),
          ),
          const SizedBox(height: 20),
          
          Text(
            '6. Limitation of Liability',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
          ),
          const SizedBox(height: 12),
          Text(
            'In no event shall PassportVault or its suppliers be liable for any damages arising out of the use or inability to use the service.',
            style: TextStyle(height: 1.5, color: bodyColor),
          ),
          const SizedBox(height: 20),
          
          Text(
            '7. Modifications',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
          ),
          const SizedBox(height: 12),
          Text(
            'We reserve the right to modify these terms at any time. Your continued use of the service following any modifications indicates your acceptance of the new terms.',
            style: TextStyle(height: 1.5, color: bodyColor),
          ),
          const SizedBox(height: 20),
          
          Text(
            'Contact Us',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
          ),
          const SizedBox(height: 12),
          Text(
            'If you have any questions about these Terms, please contact us at support@passportvault.com',
            style: TextStyle(height: 1.5, color: bodyColor),
          ),
        ],
      ),
    );
  }
}
