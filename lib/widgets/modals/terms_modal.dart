import 'package:flutter/material.dart';

class TermsModal extends StatelessWidget {
  const TermsModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(0),
      child: Container(
        margin: const EdgeInsets.only(top: 80),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                color: Colors.grey[300],
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
                    'Terms of Service',
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
                    const Text(
                      'Last updated: January 2024',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6c757d),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    _buildSection(
                      '1. Acceptance of Terms',
                      'By accessing and using PassportVault, you accept and agree to be bound by '
                      'the terms and provision of this agreement. If you do not agree to these terms, '
                      'please do not use our service.',
                    ),
                    
                    _buildSection(
                      '2. Service Description',
                      'PassportVault provides:\n\n'
                      '• Secure storage for travel documents\n'
                      '• Document expiry tracking and notifications\n'
                      '• Encrypted cloud backup\n'
                      '• Document sharing capabilities\n'
                      '• Mobile and web access to your documents',
                    ),
                    
                    _buildSection(
                      '3. User Responsibilities',
                      'You are responsible for:\n\n'
                      '• Maintaining the confidentiality of your account\n'
                      '• All activities that occur under your account\n'
                      '• Ensuring accuracy of information provided\n'
                      '• Complying with all applicable laws\n'
                      '• Not sharing your login credentials\n'
                      '• Reporting any security breaches immediately',
                    ),
                    
                    _buildSection(
                      '4. Prohibited Activities',
                      'You may not:\n\n'
                      '• Use the service for illegal purposes\n'
                      '• Upload malicious content or viruses\n'
                      '• Attempt to breach our security measures\n'
                      '• Share false or fraudulent documents\n'
                      '• Harass or harm other users\n'
                      '• Use bots or automated systems without permission\n'
                      '• Reverse engineer or copy our software',
                    ),
                    
                    _buildSection(
                      '5. Intellectual Property',
                      'All content, features, and functionality of PassportVault are owned by us '
                      'and are protected by international copyright, trademark, and other intellectual '
                      'property laws. Your documents remain your property.',
                    ),
                    
                    _buildSection(
                      '6. Service Availability',
                      'We strive to maintain 99.9% uptime but cannot guarantee uninterrupted service. '
                      'We may temporarily suspend service for maintenance, updates, or emergencies. '
                      'We are not liable for any downtime or service interruptions.',
                    ),
                    
                    _buildSection(
                      '7. Payment and Subscriptions',
                      'Some features may require payment. By subscribing, you agree to:\n\n'
                      '• Provide accurate billing information\n'
                      '• Pay all fees when due\n'
                      '• Automatic renewal unless cancelled\n'
                      '• No refunds for partial months\n\n'
                      'We reserve the right to change pricing with 30 days notice.',
                    ),
                    
                    _buildSection(
                      '8. Termination',
                      'We may terminate or suspend your account immediately if you:\n\n'
                      '• Violate these terms\n'
                      '• Engage in fraudulent activity\n'
                      '• Fail to pay fees\n'
                      '• Cause security risks\n\n'
                      'You may terminate your account at any time from Settings.',
                    ),
                    
                    _buildSection(
                      '9. Disclaimer of Warranties',
                      'THE SERVICE IS PROVIDED "AS IS" WITHOUT WARRANTIES OF ANY KIND. '
                      'We do not warrant that the service will be error-free, secure, or uninterrupted. '
                      'Use at your own risk.',
                    ),
                    
                    _buildSection(
                      '10. Limitation of Liability',
                      'We are not liable for any indirect, incidental, special, consequential, '
                      'or punitive damages resulting from your use of the service. Our total liability '
                      'shall not exceed the amount you paid us in the last 12 months.',
                    ),
                    
                    _buildSection(
                      '11. Indemnification',
                      'You agree to indemnify and hold us harmless from any claims, damages, or expenses '
                      'arising from your use of the service, violation of these terms, or violation of '
                      'any rights of another.',
                    ),
                    
                    _buildSection(
                      '12. Changes to Terms',
                      'We may modify these terms at any time. We will notify you of material changes '
                      'via email or in-app notification. Continued use after changes constitutes acceptance. '
                      'If you disagree with changes, you must stop using the service.',
                    ),
                    
                    _buildSection(
                      '13. Governing Law',
                      'These terms are governed by the laws of the jurisdiction in which we operate, '
                      'without regard to conflict of law principles. Any disputes shall be resolved '
                      'in the courts of that jurisdiction.',
                    ),
                    
                    _buildSection(
                      '14. Contact Information',
                      'For questions about these Terms of Service, contact us at:\n\n'
                      'Email: legal@passportvault.com\n'
                      'Website: www.passportvault.com/contact\n'
                      'Address: [Company Address]',
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Close Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0d6efd),
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
              color: Color(0xFF1a1a1a),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF495057),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
