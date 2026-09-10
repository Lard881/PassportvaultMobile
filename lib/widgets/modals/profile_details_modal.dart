import 'package:flutter/material.dart';

class ProfileDetailsModal extends StatelessWidget {
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> documents;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ProfileDetailsModal({
    super.key,
    required this.profile,
    required this.documents,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(date);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Active':
        return const Color(0xFF28a745);
      case 'Expiring Soon':
        return const Color(0xFFffc107);
      case 'Expired':
        return const Color(0xFFdc3545);
      default:
        return const Color(0xFF6c757d);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileDocs = documents.where((doc) => doc['profile_id'] == profile['id']).toList();
    final status = profile['status'] ?? 'Active';
    final profileType = profile['profile_type'] ?? 'Self';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subtitleColor = isDark ? const Color(0xFFADB5BD) : const Color(0xFF6C757D);
    final cardBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8F9FA);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(0),
      child: Container(
        margin: const EdgeInsets.only(top: 80),
        decoration: BoxDecoration(
          color: dialogBg,
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
                  Text(
                    'Profile Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: subtitleColor),
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
                  children: [
                    // Profile Header
                    Column(
                      children: [
                        // Avatar
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: profile['bgColor'] ?? const Color(0xFFBAE1FF),
                            shape: BoxShape.circle,
                          ),
                          child: profile['photo_url'] != null
                              ? ClipOval(
                                  child: Image.network(
                                    profile['photo_url'],
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(
                                        child: Text(
                                          profile['initials'] ?? '??',
                                          style: const TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1a1a1a),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    profile['initials'] ?? '??',
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1a1a1a),
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Name
                        Text(
                          profile['full_name'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        
                        // Badges
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0d6efd).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                profileType,
                                style: const TextStyle(
                                  color: Color(0xFF0d6efd),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: _getStatusColor(status),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const Divider(height: 40),
                    
                    // Profile Information
                    if (profile['nationality'] != null && profile['nationality'].toString().isNotEmpty)
                      _buildInfoField('Nationality', profile['nationality'], textColor: textColor),
                    
                    if (profile['date_of_birth'] != null && profile['date_of_birth'].toString().isNotEmpty)
                      _buildInfoField('Date of Birth', _formatDate(profile['date_of_birth']), textColor: textColor),
                    
                    if (profile['gender'] != null && profile['gender'].toString().isNotEmpty)
                      _buildInfoField('Gender', profile['gender'], textColor: textColor),
                    
                    if (profile['document_number'] != null && profile['document_number'].toString().isNotEmpty)
                      _buildInfoField('Document Number', profile['document_number'], isMonospace: true, textColor: textColor),
                    
                    if (profile['country'] != null && profile['country'].toString().isNotEmpty)
                      _buildInfoField('Country', profile['country'], textColor: textColor),
                    
                    if (profile['issue_date'] != null && profile['issue_date'].toString().isNotEmpty)
                      _buildInfoField('Issue Date', _formatDate(profile['issue_date']), textColor: textColor),
                    
                    if (profile['expiry_date'] != null && profile['expiry_date'].toString().isNotEmpty)
                      _buildInfoField('Expiry Date', _formatDate(profile['expiry_date']), textColor: textColor),
                    
                    if (profile['place_of_birth'] != null && profile['place_of_birth'].toString().isNotEmpty)
                      _buildInfoField('Place of Birth', profile['place_of_birth'], textColor: textColor),
                    
                    if (profile['notes'] != null && profile['notes'].toString().isNotEmpty)
                      _buildInfoField('Notes', profile['notes'], isLongText: true, textColor: textColor),
                    
                    const SizedBox(height: 24),
                    
                    // Associated Documents
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Documents (${profileDocs.length})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6c757d),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    if (profileDocs.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'No documents for this profile yet',
                            style: TextStyle(
                              fontSize: 14,
                              color: subtitleColor,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                    else
                      ...profileDocs.map((doc) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc['document_name'] ?? 'Unnamed Document',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${doc['document_type'] ?? 'Document'} • ${doc['status'] ?? 'Unknown'}',
                              style: TextStyle(
                                fontSize: 13,
                                color: subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      )),
                    
                    const SizedBox(height: 24),
                    
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              onEdit();
                            },
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Edit'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFF0d6efd)),
                              foregroundColor: const Color(0xFF0d6efd),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              onDelete();
                            },
                            icon: const Icon(Icons.delete, size: 18),
                            label: const Text('Delete'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFFdc3545)),
                              foregroundColor: const Color(0xFFdc3545),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
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

  Widget _buildInfoField(String label, String value, {bool isMonospace = false, bool isLongText = false, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6c757d),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: textColor ?? const Color(0xFF1a1a1a),
              fontFamily: isMonospace ? 'monospace' : null,
              height: isLongText ? 1.5 : 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
