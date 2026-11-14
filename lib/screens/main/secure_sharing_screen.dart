import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../widgets/skeleton_loader.dart';

class SecureSharingScreen extends StatefulWidget {
  final String? initialDocumentId;

  const SecureSharingScreen({super.key, this.initialDocumentId});

  @override
  State<SecureSharingScreen> createState() => _SecureSharingScreenState();
}

class _SecureSharingScreenState extends State<SecureSharingScreen> {
  bool _isLoading = true;
  bool _initialShareHandled = false;
  List<dynamic> _documents = [];
  List<dynamic> _shares = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        ApiService.getDocuments(),
        ApiService.getAllShares(),
      ]);

      if (results[0]['success'] == true) {
        _documents = results[0]['data'] ?? [];
      }

      if (results[1]['success'] == true) {
        _shares = results[1]['data'] ?? [];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data: $e'),
            backgroundColor: const Color(0xFFdc3545),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        final initialDocumentId = widget.initialDocumentId;
        if (!_initialShareHandled && initialDocumentId != null) {
          _initialShareHandled = true;
          final matchingDocuments = _documents
              .where(
                (document) => document['id']?.toString() == initialDocumentId,
              )
              .toList();
          if (matchingDocuments.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showShareModal(matchingDocuments.first);
              }
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('The selected document could not be found'),
              ),
            );
          }
        }
      }
    }
  }

  List<dynamic> get _activeShares {
    return _shares
        .where((s) => s['is_active'] == true && s['is_expired'] != true)
        .toList();
  }

  Future<void> _showShareModal(dynamic document) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _ShareModal(document: document, onShareCreated: _fetchData),
    );
  }

  Future<void> _revokeShare(dynamic share) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Share Link?'),
        content: Text(
          'Are you sure you want to revoke this share link for "${share['document_name']}"? The link will no longer work.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFdc3545),
            ),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final shareId = share['id']?.toString();
      if (shareId == null || shareId.isEmpty) {
        throw Exception('Invalid share ID');
      }

      final response = await ApiService.revokeShare(shareId);

      if (response['success'] == true) {
        // Optimistically update local list
        setState(() {
          for (var s in _shares) {
            if (s['id']?.toString() == shareId) {
              s['is_active'] = false;
            }
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Share link revoked successfully'),
              backgroundColor: Color(0xFF198754),
            ),
          );
        }
        _fetchData();
      } else {
        throw Exception(response['message'] ?? 'Failed to revoke share');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFdc3545),
          ),
        );
      }
    }
  }

  void _copyLink(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link copied to clipboard!')));
  }

  void _shareNative(dynamic share) {
    final url = share['share_url'];
    final text = 'Check out this shared document: ${share['document_name']}';
    Share.share('$text\n$url');
  }

  void _shareWhatsApp(dynamic share) async {
    final url = share['share_url'];
    final text = 'Check out this shared document: ${share['document_name']}';
    final whatsappUrl = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent('$text $url')}',
    );

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    }
  }

  void _shareEmail(dynamic share) async {
    final url = share['share_url'];
    final subject = 'Shared Document: ${share['document_name']}';
    final body =
        'I\'m sharing a document with you:\n\n${share['document_name']}\n${share['document_type']}\n\nAccess it here: $url';
    final emailUrl = Uri.parse(
      'mailto:?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );

    if (await canLaunchUrl(emailUrl)) {
      await launchUrl(emailUrl);
    }
  }

  void _shareTelegram(dynamic share) async {
    final url = share['share_url'];
    final text = 'Check out this shared document: ${share['document_name']}';
    final telegramUrl = Uri.parse(
      'https://t.me/share/url?url=${Uri.encodeComponent(url)}&text=${Uri.encodeComponent(text)}',
    );

    if (await canLaunchUrl(telegramUrl)) {
      await launchUrl(telegramUrl, mode: LaunchMode.externalApplication);
    }
  }

  String _formatDateTime(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final appBarBg = isDark ? const Color(0xFF242424) : Colors.white;
    final textColor = isDark
        ? const Color(0xFFF8F9FA)
        : const Color(0xFF212529);
    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Secure Sharing',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? SkeletonLoader.cardList()
          : RefreshIndicator(
              onRefresh: _fetchData,
              color: const Color(0xFF0d6efd),
              child: CustomScrollView(
                slivers: [
                  // Info description (removed duplicate header since AppBar has it)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: const Text(
                        'Share documents securely with password protection and expiration',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6c757d),
                        ),
                      ),
                    ),
                  ),

                  // Info Card
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF198754), Color(0xFF146c43)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.verified_user,
                            color: Colors.white,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Secure Document Sharing',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Share documents with password protection, expiration dates, and view limits',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Active Shares Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Active Shares (${_activeShares.length})',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFF8F9FA)
                              : const Color(0xFF212529),
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // Active Shares List
                  if (_activeShares.isEmpty)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF242424)
                              : const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.share,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No active shares',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFFF8F9FA)
                                    : const Color(0xFF6c757d),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Create a share link to see it here',
                              style: TextStyle(
                                fontSize: 14,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFFADB5BD)
                                    : const Color(0xFF6c757d),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final share = _activeShares[index];
                          return _buildShareCard(share);
                        }, childCount: _activeShares.length),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),

                  // Share a Document Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Share a Document',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFF8F9FA)
                              : const Color(0xFF212529),
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // Documents List
                  if (_documents.isEmpty)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF242424)
                              : const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.description,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No documents to share',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFFF8F9FA)
                                    : const Color(0xFF6c757d),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Upload documents first to share them',
                              style: TextStyle(
                                fontSize: 14,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFFADB5BD)
                                    : const Color(0xFF6c757d),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final doc = _documents[index];
                          return _buildDocumentCard(doc);
                        }, childCount: _documents.length),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              ),
            ),
    );
  }

  Widget _buildShareCard(dynamic share) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF242424) : Colors.white;
    final innerBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F9FA);
    final textColor = isDark
        ? const Color(0xFFF8F9FA)
        : const Color(0xFF212529);
    final subtitleColor = isDark
        ? const Color(0xFFADB5BD)
        : const Color(0xFF6C757D);
    final borderColor = isDark
        ? const Color(0xFF404040)
        : const Color(0xFFDEE2E6);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      share['document_name'] ?? 'Unnamed',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      share['document_type'] ?? 'Document',
                      style: TextStyle(fontSize: 14, color: subtitleColor),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF198754).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(
                    color: Color(0xFF198754),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Share Details
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: innerBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _buildDetailRow(
                  icon: Icons.visibility,
                  label: 'Views:',
                  value:
                      '${share['view_count']}${share['max_views'] != null ? ' / ${share['max_views']}' : ' (unlimited)'}',
                ),
                if (share['expires_at'] != null) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    icon: Icons.schedule,
                    label: 'Expires:',
                    value: _formatDateTime(share['expires_at']),
                  ),
                ],
                if (share['views_remaining'] != null) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    icon: Icons.hourglass_empty,
                    label: 'Remaining:',
                    value: '${share['views_remaining']} views',
                    valueColor: (share['views_remaining'] as int) < 3
                        ? const Color(0xFFdc3545)
                        : null,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Share URL
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              share['share_url'] ?? '',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: subtitleColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copyLink(share['share_url']),
                  icon: const Icon(Icons.content_copy, size: 16),
                  label: const Text('Copy Link'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0d6efd),
                    side: const BorderSide(color: Color(0xFF0d6efd)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _revokeShare(share),
                  icon: const Icon(Icons.cancel, size: 16),
                  label: const Text('Revoke'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFdc3545),
                    side: const BorderSide(color: Color(0xFFdc3545)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Share Options
          Divider(color: borderColor),
          const SizedBox(height: 8),
          Text(
            'Share via:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: subtitleColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildShareButton(
                icon: Icons.share,
                label: 'Share',
                color: const Color(0xFF0d6efd),
                onPressed: () => _shareNative(share),
              ),
              _buildShareButton(
                icon: Icons.chat_bubble_outline,
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
                onPressed: () => _shareWhatsApp(share),
              ),
              _buildShareButton(
                icon: Icons.email_outlined,
                label: 'Email',
                color: subtitleColor,
                onPressed: () => _shareEmail(share),
              ),
              _buildShareButton(
                icon: Icons.send_outlined,
                label: 'Telegram',
                color: const Color(0xFF0088cc),
                onPressed: () => _shareTelegram(share),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(dynamic document) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF242424) : Colors.white;
    final textColor = isDark
        ? const Color(0xFFF8F9FA)
        : const Color(0xFF212529);
    final subtitleColor = isDark
        ? const Color(0xFFADB5BD)
        : const Color(0xFF6C757D);
    final borderColor = isDark
        ? const Color(0xFF404040)
        : const Color(0xFFDEE2E6);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF0d6efd).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.description, color: Color(0xFF0d6efd)),
        ),
        title: Text(
          document['document_name'] ?? 'Unnamed Document',
          style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
        ),
        subtitle: Text(
          document['document_type'] ?? 'Document',
          style: TextStyle(color: subtitleColor),
        ),
        trailing: ElevatedButton.icon(
          onPressed: () => _showShareModal(document),
          icon: const Icon(Icons.share, size: 16),
          label: const Text('Share'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0d6efd),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark
        ? const Color(0xFFADB5BD)
        : const Color(0xFF6C757D);
    final textColor = isDark
        ? const Color(0xFFF8F9FA)
        : const Color(0xFF212529);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: labelColor),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 13, color: labelColor)),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: valueColor ?? textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildShareButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Icon(icon, size: 24, color: color ?? const Color(0xFF6c757d)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color ?? const Color(0xFF6c757d),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Share Modal Widget
class _ShareModal extends StatefulWidget {
  final Map<String, dynamic> document;
  final VoidCallback onShareCreated;

  const _ShareModal({required this.document, required this.onShareCreated});

  @override
  State<_ShareModal> createState() => _ShareModalState();
}

class _ShareModalState extends State<_ShareModal> {
  final _passwordController = TextEditingController();
  final _maxViewsController = TextEditingController();
  DateTime? _expiresAt;
  bool _requirePassword = false;
  bool _setExpiration = false;
  bool _limitViews = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _maxViewsController.dispose();
    super.dispose();
  }

  Future<void> _createShare() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final shareData = {
        'document_id': widget.document['id'],
        'expires_at': _setExpiration && _expiresAt != null
            ? _expiresAt!.toIso8601String()
            : null,
        'max_views': _limitViews && _maxViewsController.text.isNotEmpty
            ? int.tryParse(_maxViewsController.text)
            : null,
        'password': _requirePassword && _passwordController.text.isNotEmpty
            ? _passwordController.text
            : null,
      };

      final response = await ApiService.createShare(shareData);

      if (response['success'] == true) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Share link created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onShareCreated();
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to create share');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectExpirationDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null && mounted) {
        setState(() {
          _expiresAt = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final modalBg = isDark ? const Color(0xFF242424) : Colors.white;
    final textColor = isDark
        ? const Color(0xFFF8F9FA)
        : const Color(0xFF212529);
    final subtitleColor = isDark
        ? const Color(0xFFADB5BD)
        : const Color(0xFF6C757D);

    return Container(
      decoration: BoxDecoration(
        color: modalBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create Share Link',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.document['document_name'] ?? 'Document',
                        style: TextStyle(fontSize: 14, color: subtitleColor),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: textColor),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Password Protection
            SwitchListTile(
              title: Text(
                'Password Protection',
                style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Require a password to access',
                style: TextStyle(color: subtitleColor),
              ),
              value: _requirePassword,
              onChanged: (value) {
                setState(() {
                  _requirePassword = value;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            if (_requirePassword) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: subtitleColor),
                  hintText: 'Enter password',
                  hintStyle: TextStyle(color: subtitleColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.lock_outline, color: subtitleColor),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Expiration Date
            SwitchListTile(
              title: Text(
                'Set Expiration',
                style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Link expires after date',
                style: TextStyle(color: subtitleColor),
              ),
              value: _setExpiration,
              onChanged: (value) {
                setState(() {
                  _setExpiration = value;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            if (_setExpiration) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _selectExpirationDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  _expiresAt == null
                      ? 'Select Date & Time'
                      : '${_expiresAt!.month}/${_expiresAt!.day}/${_expiresAt!.year} ${_expiresAt!.hour}:${_expiresAt!.minute.toString().padLeft(2, '0')}',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // View Limit
            SwitchListTile(
              title: Text(
                'Limit Views',
                style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Maximum number of views',
                style: TextStyle(color: subtitleColor),
              ),
              value: _limitViews,
              onChanged: (value) {
                setState(() {
                  _limitViews = value;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            if (_limitViews) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _maxViewsController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Maximum Views',
                  labelStyle: TextStyle(color: subtitleColor),
                  hintText: 'e.g., 10',
                  hintStyle: TextStyle(color: subtitleColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.visibility, color: subtitleColor),
                ),
              ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 24),

            // Create Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createShare,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0d6efd),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Create Share Link',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
