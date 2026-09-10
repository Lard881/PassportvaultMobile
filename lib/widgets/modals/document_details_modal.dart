import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentDetailsModal extends StatelessWidget {
  final Map<String, dynamic> document;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onDownload;

  const DocumentDetailsModal({
    super.key,
    required this.document,
    required this.onEdit,
    required this.onDelete,
    required this.onShare,
    required this.onDownload,
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
      case 'Valid':
        return const Color(0xFF28a745);
      case 'Expiring Soon':
        return const Color(0xFFffc107);
      case 'Expired':
        return const Color(0xFFdc3545);
      default:
        return const Color(0xFF6c757d);
    }
  }

  IconData _getDocumentIcon(String? type) {
    switch (type) {
      case 'Passport':
        return Icons.airport_shuttle;
      case 'Visa':
        return Icons.assignment;
      case 'National ID':
        return Icons.badge;
      case 'Driver\'s License':
        return Icons.drive_eta;
      case 'Birth Certificate':
        return Icons.child_care;
      case 'Marriage Certificate':
        return Icons.favorite;
      default:
        return Icons.description;
    }
  }

  Future<void> _openDocument(BuildContext context) async {
    final fileUrl = document['file_url'];
    if (fileUrl != null && fileUrl.toString().isNotEmpty) {
      try {
        final uri = Uri.parse(fileUrl.toString());
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open document: $e')),
          );
        }
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No file URL available for this document')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = document['status'] ?? 'Valid';
    final documentType = document['document_type'] ?? 'Document';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subtitleColor = isDark ? const Color(0xFFADB5BD) : const Color(0xFF6C757D);

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
                color: isDark ? Colors.grey[700] : Colors.grey[300],
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
                    'Document Details',
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
                    // Document Header
                    Column(
                      children: [
                        // Icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0d6efd).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getDocumentIcon(documentType),
                            size: 40,
                            color: const Color(0xFF0d6efd),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Name
                        Text(
                          document['document_name'] ?? 'Unnamed Document',
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
                                documentType,
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
                    
                    // Document Information
                    if (document['document_number'] != null && document['document_number'].toString().isNotEmpty)
                      _buildInfoField('Document Number', document['document_number'], isMonospace: true, textColor: textColor),
                    
                    if (document['profile_name'] != null && document['profile_name'].toString().isNotEmpty)
                      _buildInfoField('Profile', document['profile_name'], textColor: textColor),
                    
                    if ((document['issue_date'] ?? document['date_of_issue']) != null && (document['issue_date'] ?? document['date_of_issue']).toString().isNotEmpty)
                      _buildInfoField('Issue Date', _formatDate((document['issue_date'] ?? document['date_of_issue']).toString()), textColor: textColor),
                    
                    if ((document['expiry_date'] ?? document['date_of_expiry']) != null && (document['expiry_date'] ?? document['date_of_expiry']).toString().isNotEmpty)
                      _buildInfoField('Expiry Date', _formatDate((document['expiry_date'] ?? document['date_of_expiry']).toString()), textColor: textColor),
                    
                    if ((document['file_type'] ?? document['mime_type']) != null && (document['file_type'] ?? document['mime_type']).toString().isNotEmpty)
                      _buildInfoField('File Type', (document['file_type'] ?? document['mime_type'])?.toString().toUpperCase() ?? 'N/A', textColor: textColor),
                    
                    if (document['file_size'] != null)
                      _buildInfoField('File Size', _formatFileSize(document['file_size']), textColor: textColor),
                    
                    if ((document['notes'] ?? document['description']) != null && (document['notes'] ?? document['description']).toString().isNotEmpty)
                      _buildInfoField('Notes', (document['notes'] ?? document['description']).toString(), isLongText: true, textColor: textColor),
                    
                    const SizedBox(height: 24),
                    
                    // Quick Actions
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.visibility,
                            label: 'View',
                            onPressed: () => _openDocument(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.download,
                            label: 'Download',
                            onPressed: () {
                              Navigator.of(context).pop();
                              onDownload();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.share,
                            label: 'Share',
                            onPressed: () {
                              Navigator.of(context).pop();
                              onShare();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.edit,
                            label: 'Edit',
                            onPressed: () {
                              Navigator.of(context).pop();
                              onEdit();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: _buildActionButton(
                        icon: Icons.delete,
                        label: 'Delete Document',
                        onPressed: () {
                          Navigator.of(context).pop();
                          onDelete();
                        },
                        isDanger: true,
                      ),
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isDanger = false,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(
          color: isDanger ? const Color(0xFFdc3545) : const Color(0xFF0d6efd),
        ),
        foregroundColor: isDanger ? const Color(0xFFdc3545) : const Color(0xFF0d6efd),
      ),
    );
  }

  String _formatFileSize(dynamic size) {
    if (size == null) return 'N/A';
    final bytes = size is int ? size : int.tryParse(size.toString()) ?? 0;
    
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
