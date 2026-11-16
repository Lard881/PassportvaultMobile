import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../services/api_service.dart';

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
    try {
      final response = await ApiService.getDocumentSignedUrl(document['id']);
      final signedUrl = response['data']?['signedUrl'];
      if (signedUrl is! String || signedUrl.isEmpty) {
        throw Exception('Could not create a secure document link');
      }

      final uri = Uri.parse(signedUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('No app is available to open this document');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open document: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = document['status'] ?? 'Valid';
    final documentType = document['document_type'] ?? 'Document';
    final expiryDate = (document['expiry_date'] ?? document['date_of_expiry'])
        ?.toString();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subtitleColor = isDark
        ? const Color(0xFFADB5BD)
        : const Color(0xFF6C757D);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(0),
      child: Container(
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: dialogBg,
          borderRadius: BorderRadius.zero,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Header
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: subtitleColor),
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        color: AppTheme.primaryColor,
                      ),
                      tooltip: 'Edit document',
                      onPressed: () {
                        Navigator.of(context).pop();
                        onEdit();
                      },
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'More document actions',
                      icon: Icon(Icons.more_vert, color: subtitleColor),
                      onSelected: (action) {
                        if (action == 'delete') {
                          Navigator.of(context).pop();
                          onDelete();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete document'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Document Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getDocumentIcon(documentType),
                            size: 28,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                document['document_name'] ?? 'Unnamed Document',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _buildDetailBadge(
                                    documentType,
                                    AppTheme.primaryColor,
                                  ),
                                  _buildDetailBadge(
                                    status,
                                    _getStatusColor(status),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (expiryDate != null && expiryDate.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            status,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 18,
                              color: _getStatusColor(status),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${status == 'Expired' ? 'Expired' : 'Expires'} ${_formatDate(expiryDate)}',
                                style: TextStyle(
                                  color: _getStatusColor(status),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const Divider(height: 40),

                    // Document Information
                    if (document['document_number'] != null &&
                        document['document_number'].toString().isNotEmpty)
                      _buildInfoField(
                        'Document Number',
                        document['document_number'],
                        isMonospace: true,
                        textColor: textColor,
                      ),

                    if (document['profile_name'] != null &&
                        document['profile_name'].toString().isNotEmpty)
                      _buildInfoField(
                        'Profile',
                        document['profile_name'],
                        textColor: textColor,
                      ),

                    if ((document['issue_date'] ?? document['date_of_issue']) !=
                            null &&
                        (document['issue_date'] ?? document['date_of_issue'])
                            .toString()
                            .isNotEmpty)
                      _buildInfoField(
                        'Issue Date',
                        _formatDate(
                          (document['issue_date'] ?? document['date_of_issue'])
                              .toString(),
                        ),
                        textColor: textColor,
                      ),

                    if ((document['expiry_date'] ??
                                document['date_of_expiry']) !=
                            null &&
                        (document['expiry_date'] ?? document['date_of_expiry'])
                            .toString()
                            .isNotEmpty)
                      _buildInfoField(
                        'Expiry Date',
                        _formatDate(
                          (document['expiry_date'] ??
                                  document['date_of_expiry'])
                              .toString(),
                        ),
                        textColor: textColor,
                      ),

                    if ((document['file_type'] ?? document['mime_type']) !=
                            null &&
                        (document['file_type'] ?? document['mime_type'])
                            .toString()
                            .isNotEmpty)
                      _buildInfoField(
                        'File Type',
                        (document['file_type'] ?? document['mime_type'])
                                ?.toString()
                                .toUpperCase() ??
                            'N/A',
                        textColor: textColor,
                      ),

                    if (document['file_size'] != null)
                      _buildInfoField(
                        'File Size',
                        _formatFileSize(document['file_size']),
                        textColor: textColor,
                      ),

                    if ((document['notes'] ?? document['description']) !=
                            null &&
                        (document['notes'] ?? document['description'])
                            .toString()
                            .isNotEmpty)
                      _buildInfoField(
                        'Notes',
                        (document['notes'] ?? document['description'])
                            .toString(),
                        isLongText: true,
                        textColor: textColor,
                      ),

                    const SizedBox(height: 24),

                    // Additional Actions
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
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: dialogBg,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? const Color(0xFF404040)
                          : const Color(0xFFDEE2E6),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onDownload();
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('Download'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: const BorderSide(color: AppTheme.primaryColor),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onShare();
                        },
                        icon: const Icon(Icons.share),
                        label: const Text('Share'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoField(
    String label,
    String value, {
    bool isMonospace = false,
    bool isLongText = false,
    Color? textColor,
  }) {
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
          color: isDanger ? const Color(0xFFdc3545) : AppTheme.primaryColor,
        ),
        foregroundColor: isDanger
            ? const Color(0xFFdc3545)
            : AppTheme.primaryColor,
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
