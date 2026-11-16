import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/file_download_service.dart';
import '../../services/cache_service.dart';
import '../../services/document_cache_service.dart';
import '../../services/local_notification_service.dart';
import '../../providers/connectivity_provider.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/modals/add_document_modal.dart';
import '../../widgets/modals/add_profile_modal.dart';
import '../../widgets/modals/document_details_modal.dart';
import '../../widgets/modals/edit_document_modal.dart';
import '../../widgets/modals/edit_profile_modal.dart';
import '../../utils/responsive.dart';
import '../../widgets/modals/profile_details_modal.dart';
import '../../utils/type_helpers.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/skeleton_loader.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'main_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  List<dynamic> _profiles = [];
  List<dynamic> _documents = [];
  List<dynamic> _notifications = [];
  DateTime? _lastRefresh;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadCachedDataAndRefresh();
    _lastRefresh = DateTime.now();
  }

  @override
  void didUpdateWidget(DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh if it's been more than 2 seconds since last refresh
    final now = DateTime.now();
    if (_lastRefresh == null || now.difference(_lastRefresh!).inSeconds > 2) {
      _loadCachedDataAndRefresh();
      _lastRefresh = now;
    }
  }

  /// Stale-while-revalidate pattern: Show cache instantly, fetch fresh in background
  Future<void> _loadCachedDataAndRefresh() async {
    // Step 1: Load cached data instantly (0ms)
    final cachedProfiles = await CacheService.getProfilesCache();
    final cachedDocs = await CacheService.getDocumentsCache();

    if (mounted && (cachedProfiles.isNotEmpty || cachedDocs.isNotEmpty)) {
      setState(() {
        _profiles = cachedProfiles;
        _documents = cachedDocs;
        _isLoading = false;
      });
    }

    // Step 2: Check if cache is stale
    final isProfilesStale = await CacheService.isProfilesCacheStale();
    final isDocsStale = await CacheService.isDocumentsCacheStale();

    // Step 3: If stale, fetch fresh data in background
    if (isProfilesStale ||
        isDocsStale ||
        cachedProfiles.isEmpty ||
        cachedDocs.isEmpty) {
      _fetchDashboardData();
    }
  }

  Future<void> _fetchDashboardData() async {
    // Don't show loading spinner if we have cached data
    if (_profiles.isEmpty && _documents.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      // Fetch all data in parallel
      final results = await Future.wait([
        ApiService.getProfiles(),
        ApiService.getDocuments(),
        ApiService.getNotifications(),
        ApiService.getUnreadNotificationsCount(),
      ]);

      // Process profiles
      if (results[0]['success'] == true) {
        _profiles = results[0]['data'] ?? [];
        await CacheService.saveProfilesCache(_profiles);
      }

      // Process documents
      if (results[1]['success'] == true) {
        _documents = results[1]['data'] ?? [];
        await CacheService.saveDocumentsCache(_documents);
      }

      // Process notifications
      if (results[2]['success'] == true) {
        _notifications = results[2]['data'] ?? [];
      }

      // Update UI with fresh data
      if (mounted) {
        setState(() {});
      }

      // Note: Unread count is in results[3] if needed for badge
    } catch (error) {
      // Don't show error if we have cached data
      if (mounted && _profiles.isEmpty && _documents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load dashboard: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String _getDocumentStatus(String? expiryDate) {
    if (expiryDate == null || expiryDate.isEmpty) return 'No expiry';

    final daysUntil = DateFormatter.daysUntilExpiry(expiryDate);
    if (daysUntil == null) return 'No expiry';

    if (daysUntil < 0) return 'Expired';
    if (daysUntil <= 30) return 'Expiring Soon';
    return 'Valid';
  }

  int _calculateDaysToExpiry(String expiryDate) {
    return DateFormatter.daysUntilExpiry(expiryDate) ?? 0;
  }

  String _formatDate(String date) {
    return DateFormatter.formatShortDate(date);
  }

  void _showAddDocumentModal() {
    if (_profiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please create a profile first before adding documents',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AddDocumentModal(
        profiles: _profiles.cast<Map<String, dynamic>>(),
        onSubmit: _handleAddDocument,
      ),
    );
  }

  void _showAddProfileModal() {
    showDialog(
      context: context,
      builder: (context) => AddProfileModal(
        onSubmit: (profileData, photo) => _handleAddProfile(profileData, photo),
      ),
    );
  }

  Future<void> _handleAddProfile(
    Map<String, dynamic> profileData,
    File? photoFile,
  ) async {
    try {
      final response = await ApiService.uploadProfile(profileData, photoFile);

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _fetchDashboardData();
      } else {
        throw Exception(response['message'] ?? 'Failed to add profile');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add profile: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleAddDocument(Map<String, dynamic> documentData) async {
    try {
      final file = documentData['documentFile'];
      final response = await ApiService.uploadDocument(documentData, file);

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _fetchDashboardData();

        // Schedule notifications if document has expiry date
        if (documentData['expiryDate'] != null && response['data'] != null) {
          await LocalNotificationService.scheduleDocumentExpiryNotifications(
            documentId: response['data']['id'].toString(),
            documentName: documentData['documentName'],
            expiryDate: DateTime.parse(documentData['expiryDate']),
          );
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to add document');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload document: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDocumentDetails(Map<String, dynamic> document) {
    showDialog(
      context: context,
      builder: (context) => DocumentDetailsModal(
        document: TypeHelpers.toMap(document),
        onEdit: () {
          _showEditDocumentModal(TypeHelpers.toMap(document));
        },
        onDelete: () {
          _confirmDeleteDocument(TypeHelpers.toMap(document));
        },
        onShare: () {
          MainScreenNavigator.goToDocuments(context);
        },
        onDownload: () {
          _downloadDocument(TypeHelpers.toMap(document));
        },
      ),
    );
  }

  void _showEditDocumentModal(Map<String, dynamic> document) {
    showDialog(
      context: context,
      builder: (context) => EditDocumentModal(
        document: document,
        profiles: _profiles.cast<Map<String, dynamic>>(),
        onSubmit: (data) async {
          try {
            final res = await ApiService.updateDocument(document['id'], data);
            if (res['success'] == true && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Document updated successfully'),
                  backgroundColor: Colors.green,
                ),
              );
              await _fetchDashboardData();
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to update document: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _confirmDeleteDocument(Map<String, dynamic> document) {
    showDialog(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Delete Document',
        message:
            'Are you sure you want to delete "${document['document_name']}"? This action cannot be undone.',
        confirmText: 'Delete',
        type: 'danger',
        onConfirm: () async {
          try {
            final res = await ApiService.deleteDocument(document['id']);
            if (res['success'] == true && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Document deleted successfully'),
                  backgroundColor: Colors.green,
                ),
              );
              await _fetchDashboardData();
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to delete document: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _downloadDocument(Map<String, dynamic> document) async {
    try {
      // Check if document is already cached
      final documentId = document['id'];
      final isCached = await DocumentCacheService.isDocumentCached(documentId);

      List<int> bytes;

      if (isCached) {
        // Use cached version
        final cachedBytes = await DocumentCacheService.getCachedDocumentBytes(
          documentId,
        );
        if (cachedBytes != null) {
          bytes = cachedBytes;
          debugPrint('📱 Using cached document: $documentId');
        } else {
          // Cache is corrupted, download fresh
          bytes = await ApiService.downloadDocument(documentId);
          // Cache for future use
          final fileName = document['document_name'] ?? 'document';
          final fileExtension = document['file_type'] ?? 'pdf';
          await DocumentCacheService.cacheDocument(
            documentId: documentId,
            bytes: bytes,
            fileName: '$fileName.$fileExtension',
          );
        }
      } else {
        // Download from server
        bytes = await ApiService.downloadDocument(documentId);
        // Cache for offline access
        final fileName = document['document_name'] ?? 'document';
        final fileExtension = document['file_type'] ?? 'pdf';
        await DocumentCacheService.cacheDocument(
          documentId: documentId,
          bytes: bytes,
          fileName: '$fileName.$fileExtension',
        );
        debugPrint('💾 Document cached for offline access');
      }

      final fileName = document['document_name'] ?? 'document';
      final fileExtension = document['file_type'] ?? 'pdf';
      final fullFileName = '$fileName.$fileExtension';
      final mimeType = _getMimeType(fileExtension);

      final filePath = await FileDownloadService.downloadFile(
        bytes: bytes,
        fileName: fullFileName,
        mimeType: mimeType,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCached
                  ? '📱 Downloaded from cache: $filePath'
                  : '✅ Downloaded and cached: $filePath',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  void _showProfileDetails(Map<String, dynamic> profile) {
    showDialog(
      context: context,
      builder: (context) => ProfileDetailsModal(
        profile: TypeHelpers.toMap(profile),
        documents: _documents.map((d) => TypeHelpers.toMap(d)).toList(),
        onEdit: () {
          _showEditProfileModal(TypeHelpers.toMap(profile));
        },
        onDelete: () {
          _confirmDeleteProfile(TypeHelpers.toMap(profile));
        },
        onAddDocument: _showAddDocumentModal,
        onOpenDocument: _showDocumentDetails,
      ),
    );
  }

  void _showEditProfileModal(Map<String, dynamic> profile) {
    showDialog(
      context: context,
      builder: (context) => EditProfileModal(
        profile: profile,
        onSubmit: (data, photoFile) async {
          try {
            final res = await ApiService.updateProfileWithPhoto(
              profile['id'],
              data,
              photoFile,
            );
            if (res['success'] == true && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile updated successfully'),
                  backgroundColor: Colors.green,
                ),
              );
              await _fetchDashboardData();
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to update profile: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _confirmDeleteProfile(Map<String, dynamic> profile) {
    showDialog(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Delete Profile',
        message:
            'Are you sure you want to delete "${profile['full_name']}"? All associated documents will also be deleted.',
        confirmText: 'Delete',
        type: 'danger',
        onConfirm: () async {
          final profileId = profile['id'];
          setState(() {
            _profiles.removeWhere(
              (p) => p['id']?.toString() == profileId?.toString(),
            );
          });
          await CacheService.removeProfileFromCache(profileId);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile deleted successfully'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }

          try {
            await ApiService.deleteProfile(profileId);
          } catch (e) {
            _fetchDashboardData();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to delete on server: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // Calculate stats from real data
    final totalProfiles = _profiles.length;

    final totalDocuments = _documents.length;
    final expiringSoon = _documents
        .where((d) => _getDocumentStatus(d['expiry_date']) == 'Expiring Soon')
        .length;

    // Calculate expired documents (split into recently expired and older)
    final now = DateTime.now();
    final recentlyExpired = _documents.where((d) {
      final status = _getDocumentStatus(d['expiry_date']);
      if (status != 'Expired') return false;
      try {
        final expiry = DateTime.parse(d['expiry_date']);
        return now.difference(expiry).inDays <= 7;
      } catch (e) {
        return false;
      }
    }).length;

    final olderExpired = _documents.where((d) {
      final status = _getDocumentStatus(d['expiry_date']);
      if (status != 'Expired') return false;
      try {
        final expiry = DateTime.parse(d['expiry_date']);
        return now.difference(expiry).inDays > 7;
      } catch (e) {
        return false;
      }
    }).length;

    final totalExpired = recentlyExpired + olderExpired;
    final totalAttention = totalExpired + expiringSoon;

    // Get upcoming expiries (next 90 days)
    final upcomingExpiries =
        _documents
            .where((d) {
              if (d['expiry_date'] == null ||
                  d['expiry_date'].toString().isEmpty) {
                return false;
              }
              try {
                final days = _calculateDaysToExpiry(d['expiry_date']);
                return days >= 0 && days <= 90;
              } catch (e) {
                return false;
              }
            })
            .map(
              (d) => {
                ...d,
                'daysToExpiry': _calculateDaysToExpiry(d['expiry_date']),
              },
            )
            .toList()
          ..sort(
            (a, b) =>
                (a['daysToExpiry'] as int).compareTo(b['daysToExpiry'] as int),
          );

    final topExpiries = upcomingExpiries.take(4).toList();
    final attentionDocuments =
        _documents
            .where((document) {
              final expiryDate = document['expiry_date']?.toString();
              if (expiryDate == null || expiryDate.isEmpty) return false;
              final daysUntil = DateFormatter.daysUntilExpiry(expiryDate);
              return daysUntil != null && daysUntil <= 30;
            })
            .map(
              (document) => {
                ...TypeHelpers.toMap(document),
                'daysToExpiry': DateFormatter.daysUntilExpiry(
                  document['expiry_date']?.toString(),
                ),
              },
            )
            .toList()
          ..sort(
            (a, b) =>
                (a['daysToExpiry'] as int).compareTo(b['daysToExpiry'] as int),
          );
    final topAttentionDocuments = attentionDocuments.take(3).toList();
    final name = Provider.of<AuthProvider>(
      context,
    ).user?['name']?.toString().trim();
    final firstName = name == null || name.isEmpty
        ? 'there'
        : name.split(RegExp(r'\s+')).first;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? SkeletonLoader.dashboard()
          : RefreshIndicator(
              onRefresh: _fetchDashboardData,
              color: AppTheme.primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cached Data Indicator (shown when offline)
                    Consumer<ConnectivityProvider>(
                      builder: (context, connectivity, child) {
                        if (connectivity.isOnline) {
                          return const SizedBox.shrink();
                        }
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFfff3cd),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(
                                0xFFffc107,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Color(0xFFffc107),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Viewing cached data - Connect to see latest updates',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? const Color(0xFF856404)
                                        : const Color(0xFF856404),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    // Dashboard introduction
                    Container(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_getGreeting()}, $firstName',
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Here's your vault at a glance.",
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Summary cards
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: Responsive.getSpacing(context, 8),
                      mainAxisSpacing: Responsive.getSpacing(context, 8),
                      childAspectRatio: 0.9,
                      children: [
                        _buildSummaryCard(
                          icon: Icons.people_outline,
                          iconColor: AppTheme.primaryColor,
                          iconBg: Colors.transparent,
                          value: totalProfiles.toString(),
                          label: 'People',
                          onTap: () =>
                              MainScreenNavigator.goToProfiles(context),
                        ),
                        _buildSummaryCard(
                          icon: Icons.description_outlined,
                          iconColor: const Color(0xFF1F3B70),
                          iconBg: Colors.transparent,
                          value: totalDocuments.toString(),
                          label: 'Documents',
                          onTap: () =>
                              MainScreenNavigator.goToDocuments(context),
                        ),
                        _buildSummaryCard(
                          icon: Icons.warning_amber_rounded,
                          iconColor: const Color(0xFFB96800),
                          iconBg: Colors.transparent,
                          value: totalAttention.toString(),
                          valueColor: const Color(0xFF8A4B00),
                          label: 'Attention',
                          cardColor: const Color(0xFFFFF5E3),
                          cardBorderColor: const Color(0xFFFFD68A),
                          onTap: () => Navigator.pushNamed(context, '/alerts'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Needs attention
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Needs attention',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/alerts'),
                          child: const Text('See all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (topAttentionDocuments.isEmpty)
                      _buildEmptyState(
                        icon: Icons.check_circle_outline,
                        title: 'You’re all caught up',
                        subtitle: 'No documents need attention right now.',
                      )
                    else
                      _buildAttentionList(topAttentionDocuments),
                    const SizedBox(height: 20),

                    // People
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'People',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              MainScreenNavigator.goToProfiles(context),
                          child: const Text('See all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_profiles.isEmpty)
                      _buildEmptyState(
                        icon: Icons.people_outline,
                        title: 'No people yet',
                        subtitle:
                            'Add a profile to start organizing documents.',
                        action: TextButton.icon(
                          onPressed: _showAddProfileModal,
                          icon: const Icon(Icons.person_add_alt_1, size: 18),
                          label: const Text('Add profile'),
                        ),
                      )
                    else
                      _buildPeopleRow(),
                    const SizedBox(height: 24),

                    // Upcoming Expiries Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Upcoming expiries',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/calendar');
                          },
                          icon: const Icon(Icons.calendar_today, size: 14),
                          label: const Text('View Calendar'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Upcoming Expiries List
                    if (topExpiries.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: const Color(0xFFf8f9fa),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 48,
                                color: Color(0xFFDEE2E6),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No upcoming expiries',
                                style: TextStyle(
                                  color: Color(0xFF6c757d),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Documents with expiry dates will appear here',
                                style: TextStyle(
                                  color: Color(0xFF6c757d),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          ...topExpiries.map((doc) {
                            final daysToExpiry = doc['daysToExpiry'] as int;
                            final profileInitials =
                                (doc['profile_name'] ?? 'UK')
                                    .split(' ')
                                    .take(2)
                                    .map((n) => n.isNotEmpty ? n[0] : '')
                                    .join()
                                    .toUpperCase();

                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;
                            final cardBg = isDark
                                ? const Color(0xFF242424)
                                : Colors.white;
                            final borderColor = isDark
                                ? const Color(0xFF404040)
                                : const Color(0xFFDEE2E6);
                            final textColor = isDark
                                ? const Color(0xFFF8F9FA)
                                : const Color(0xFF212529);
                            final subtitleColor = isDark
                                ? const Color(0xFFADB5BD)
                                : const Color(0xFF6C757D);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: GestureDetector(
                                    onTap: () {
                                      final docMap = TypeHelpers.toMap(doc);
                                      final profile = _profiles.firstWhere(
                                        (p) =>
                                            p['id']?.toString() ==
                                                docMap['profile_id']
                                                    ?.toString() ||
                                            p['full_name'] ==
                                                docMap['profile_name'],
                                        orElse: () => <String, dynamic>{
                                          'full_name':
                                              docMap['profile_name'] ??
                                              'Unknown Profile',
                                          'initials': profileInitials,
                                          'status': 'Active',
                                        },
                                      );
                                      _showProfileDetails(
                                        TypeHelpers.toMap(profile),
                                      );
                                    },
                                    child: CircleAvatar(
                                      backgroundColor: const Color(
                                        0xFF6366f1,
                                      ).withValues(alpha: 0.1),
                                      child: Text(
                                        profileInitials,
                                        style: const TextStyle(
                                          color: Color(0xFF6366f1),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${doc['profile_name'] ?? 'Unknown'} - ${doc['document_type'] ?? 'Document'}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: textColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatDate(doc['expiry_date']),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: daysToExpiry <= 30
                                                  ? const Color(0xFFffc107)
                                                  : AppTheme.primaryColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Expires in $daysToExpiry days',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: subtitleColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Icon(
                                    Icons.chevron_right,
                                    color: subtitleColor,
                                  ),
                                  onTap: () => _showDocumentDetails(
                                    TypeHelpers.toMap(doc),
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, '/calendar');
                            },
                            icon: const Icon(Icons.arrow_forward, size: 16),
                            label: const Text('View all upcoming'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 32),

                    // Recent Notifications Section
                    if (_notifications.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Recent Notifications',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF212529),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              MainScreenNavigator.goToTab(
                                context,
                                3,
                              ); // Notifications tab
                            },
                            icon: const Icon(Icons.notifications, size: 14),
                            label: Text('View All (${_notifications.length})'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...(_notifications.take(3).map((notification) {
                        final isUnread = notification['is_read'] == false;
                        final priority =
                            notification['priority']
                                ?.toString()
                                .toUpperCase() ??
                            'LOW';
                        Color priorityColor;
                        switch (priority) {
                          case 'HIGH':
                            priorityColor = const Color(0xFFdc3545);
                            break;
                          case 'MEDIUM':
                            priorityColor = const Color(0xFFffc107);
                            break;
                          default:
                            priorityColor = const Color(0xFF28a745);
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isUnread
                                ? const Color(0xFFE3F2FD)
                                : Colors.white,
                            border: Border.all(
                              color: isUnread
                                  ? AppTheme.primaryColor
                                  : const Color(0xFFDEE2E6),
                              width: isUnread ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: priorityColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  priority == 'HIGH'
                                      ? Icons.error
                                      : priority == 'MEDIUM'
                                      ? Icons.warning
                                      : Icons.info,
                                  color: priorityColor,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                notification['title'] ?? 'Notification',
                                style: TextStyle(
                                  fontWeight: isUnread
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  fontSize: 14,
                                  color: const Color(0xFF212529),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                notification['message'] ?? '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6c757d),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (isUnread)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.primaryColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              onTap: () {
                                MainScreenNavigator.goToTab(
                                  context,
                                  3,
                                ); // Go to notifications
                              },
                            ),
                          ),
                        );
                      }).toList()),
                      const SizedBox(height: 32),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
      floatingActionButton: Consumer<ConnectivityProvider>(
        builder: (context, connectivity, child) {
          final isOffline = connectivity.isOffline;
          return FloatingActionButton.extended(
            onPressed: isOffline ? null : _showAddDocumentModal,
            backgroundColor: isOffline
                ? Colors.grey[300]
                : AppTheme.primaryColor,
            foregroundColor: isOffline ? Colors.grey[600] : Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            icon: const Icon(Icons.add, size: 20),
            label: Text(isOffline ? 'Connect to add' : 'Add document'),
            tooltip: isOffline ? 'Connect to add a document' : 'Add document',
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF404040) : const Color(0xFFDEE2E6),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: AppTheme.primaryColor),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 8), action],
        ],
      ),
    );
  }

  Widget _buildAttentionList(List<Map<String, dynamic>> documents) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? const Color(0xFF404040)
        : const Color(0xFFDEE2E6);
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subtitleColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          for (var index = 0; index < documents.length; index++) ...[
            _buildAttentionDocumentRow(
              documents[index],
              textColor: textColor,
              subtitleColor: subtitleColor,
            ),
            if (index < documents.length - 1)
              Divider(height: 1, color: borderColor),
          ],
        ],
      ),
    );
  }

  Widget _buildAttentionDocumentRow(
    Map<String, dynamic> document, {
    required Color? textColor,
    required Color? subtitleColor,
  }) {
    final daysUntilExpiry = document['daysToExpiry'] as int;
    final isExpired = daysUntilExpiry < 0;
    final statusColor = isExpired
        ? AppTheme.dangerColor
        : const Color(0xFFB96800);
    final statusLabel = isExpired ? 'Expired' : 'Expiring soon';
    final name =
        document['document_name']?.toString() ??
        document['title']?.toString() ??
        'Document';
    final profileName =
        document['profile_name']?.toString() ?? 'Unknown person';
    final documentType = document['document_type']?.toString() ?? 'Document';
    final expiryDate = document['expiry_date']?.toString();

    return InkWell(
      onTap: () => _showDocumentDetails(document),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.description_outlined,
                size: 19,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$profileName · $documentType',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: subtitleColor),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (expiryDate != null && expiryDate.isNotEmpty)
                        Text(
                          'Exp. ${_formatDate(expiryDate)}',
                          style: TextStyle(fontSize: 11, color: subtitleColor),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: subtitleColor),
          ],
        ),
      ),
    );
  }

  Widget _buildPeopleRow() {
    const avatarColors = [
      Color(0xFFC9F0FF),
      Color(0xFFC8F2E2),
      Color(0xFFFFDCD6),
      Color(0xFFE0E2FF),
      Color(0xFFF9D9F0),
      Color(0xFFFFE6C7),
    ];

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _profiles.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final profile = TypeHelpers.toMap(_profiles[index]);
          final fullName = (profile['full_name'] ?? profile['name'] ?? 'Person')
              .toString();
          final initials = fullName
              .trim()
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .take(2)
              .map((part) => part[0].toUpperCase())
              .join();

          return SizedBox(
            width: 64,
            child: InkWell(
              onTap: () => _showProfileDetails(profile),
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: avatarColors[index % avatarColors.length],
                    child: Text(
                      initials.isEmpty ? '?' : initials,
                      style: const TextStyle(
                        color: Color(0xFF1F3B70),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    fullName.split(RegExp(r'\s+')).first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String value,
    Color? valueColor,
    required String label,
    String? subtitle,
    Widget? breakdown,
    String? actionLabel,
    Color? actionColor,
    Color? cardColor,
    Color? cardBorderColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final borderColor = isDark
        ? const Color(0xFF404040)
        : const Color(0xFFDEE2E6);
    final cardTextColor = isDark ? Colors.white : const Color(0xFF212529);
    final cardSubtitleColor = isDark
        ? const Color(0xFFADB5BD)
        : const Color(0xFF6C757D);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? cardBg : (cardColor ?? cardBg),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? borderColor : (cardBorderColor ?? borderColor),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w700,
                color: valueColor ?? cardTextColor,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: cardSubtitleColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: cardSubtitleColor),
              ),
            ],
            if (breakdown != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1E1E)
                      : const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: breakdown,
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    actionLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: actionColor ?? AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: actionColor ?? AppTheme.primaryColor,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
