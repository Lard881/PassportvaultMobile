import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../services/api_service.dart';
import '../../services/cache_service.dart';
import '../../services/file_download_service.dart';
import '../../services/local_notification_service.dart';
import '../../widgets/modals/add_profile_modal.dart';
import '../../widgets/modals/add_document_modal.dart';
import '../../widgets/modals/document_details_modal.dart';
import '../../widgets/modals/edit_document_modal.dart';
import '../../widgets/modals/profile_details_modal.dart';
import '../../widgets/modals/edit_profile_modal.dart';
import '../../widgets/confirm_dialog.dart';
import 'secure_sharing_screen.dart';
import '../../utils/type_helpers.dart';
import '../../utils/responsive.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/skeleton_loader.dart';

class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

String _getDocumentStatus(dynamic expiryDate) {
  if (expiryDate == null || expiryDate.toString().isEmpty) return 'No expiry';
  final daysUntil = DateFormatter.daysUntilExpiry(expiryDate);
  if (daysUntil == null) return 'No expiry';
  if (daysUntil < 0) return 'Expired';
  if (daysUntil <= 30) return 'Expiring Soon';
  return 'Valid';
}

class _ProfilesScreenState extends State<ProfilesScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  List<dynamic> _profiles = [];
  List<dynamic> _documents = [];
  List<dynamic> _filteredProfiles = [];
  String _searchTerm = '';
  String _filterType = 'All';
  String _sortBy = 'name-asc'; // New: Sort option
  final TextEditingController _searchController = TextEditingController();
  DateTime? _lastRefresh;

  @override
  bool get wantKeepAlive => true;

  final List<String> _profileTypes = [
    'All',
    'Self',
    'Spouse',
    'Child',
    'Parent',
    'Sibling',
    'Other',
  ];

  // Pastel colors matching web version
  final List<Color> _pastelColors = const [
    Color(0xFFFFB3BA), // Pastel Pink
    Color(0xFFBAFFC9), // Pastel Green
    Color(0xFFBAE1FF), // Pastel Blue
    Color(0xFFFFFFBA), // Pastel Yellow
    Color(0xFFFFDFBA), // Pastel Orange
    Color(0xFFE0BBE4), // Pastel Purple
    Color(0xFFFEC8D8), // Pastel Rose
    Color(0xFFD4F1F4), // Pastel Cyan
  ];

  @override
  void initState() {
    super.initState();
    _loadCachedDataAndRefresh();
    _lastRefresh = DateTime.now();
  }

  @override
  void didUpdateWidget(ProfilesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh if it's been more than 2 seconds since last refresh
    final now = DateTime.now();
    if (_lastRefresh == null || now.difference(_lastRefresh!).inSeconds > 2) {
      _loadCachedDataAndRefresh();
      _lastRefresh = now;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Stale-while-revalidate pattern: Show cache instantly, fetch fresh in background
  Future<void> _loadCachedDataAndRefresh() async {
    // Step 1: Load cached data instantly (0ms)
    await _loadCachedData();

    // Step 2: Check if cache is stale
    final isProfilesStale = await CacheService.isProfilesCacheStale();
    final isDocsStale = await CacheService.isDocumentsCacheStale();

    // Step 3: If stale, fetch fresh data in background
    if (isProfilesStale || isDocsStale || _profiles.isEmpty) {
      _fetchProfiles();
    }
  }

  Future<void> _loadCachedData() async {
    final cachedProfiles = await CacheService.getProfilesCache();
    final cachedDocs = await CacheService.getDocumentsCache();
    if (mounted && (cachedProfiles.isNotEmpty || cachedDocs.isNotEmpty)) {
      final profiles = cachedProfiles.asMap().entries.map((entry) {
        final index = entry.key;
        final profile = entry.value;
        return {
          ...profile,
          'initials': _getInitials(profile['full_name'] ?? ''),
          'status': _getProfileStatus(profile['expiry_date']),
          'bgColor': _pastelColors[index % _pastelColors.length],
        };
      }).toList();

      setState(() {
        _profiles = profiles;
        _documents = cachedDocs;
        _isLoading = false;
        _filterAndSortProfiles();
      });
    }
  }

  Future<void> _fetchProfiles() async {
    // Don't show loading spinner if we have cached data
    if (_profiles.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final results = await Future.wait([
        ApiService.getProfiles(),
        ApiService.getDocuments(),
      ]);

      final profilesResponse = results[0];
      final documentsResponse = results[1];

      if (profilesResponse['success'] == true) {
        final rawProfiles = profilesResponse['data'] as List? ?? [];
        await CacheService.saveProfilesCache(rawProfiles);
        final rawDocuments = documentsResponse['success'] == true
            ? documentsResponse['data'] as List? ?? []
            : <dynamic>[];
        final documents = rawDocuments.map((document) {
          final documentMap = TypeHelpers.toMap(document);
          return {
            ...documentMap,
            'status': _getDocumentStatus(documentMap['expiry_date']),
          };
        }).toList();
        if (documentsResponse['success'] == true) {
          await CacheService.saveDocumentsCache(documents);
        }

        final profiles = rawProfiles.asMap().entries.map((entry) {
          final index = entry.key;
          final profile = entry.value;
          return {
            ...profile,
            'initials': _getInitials(profile['full_name'] ?? ''),
            'status': _getProfileStatus(profile['expiry_date']),
            'bgColor': _pastelColors[index % _pastelColors.length],
          };
        }).toList();

        if (mounted) {
          setState(() {
            _profiles = profiles;
            _documents = documents;
            _filterAndSortProfiles();
          });
        }
      }
    } catch (error) {
      // Don't show error if we have cached data
      if (mounted && _profiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profiles: $error'),
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

  String _getInitials(String fullName) {
    final clean = fullName.trim();
    if (clean.isEmpty) return '?';
    final parts = clean
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String _getProfileStatus(dynamic expiryDate) {
    if (expiryDate == null || expiryDate.toString().isEmpty) return 'Active';

    final daysUntil = DateFormatter.daysUntilExpiry(expiryDate);
    if (daysUntil == null) return 'Active';

    if (daysUntil < 0) return 'Expired';
    if (daysUntil <= 30) return 'Expiring Soon';
    return 'Active';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Active':
        return const Color(0xFF198754);
      case 'Expiring Soon':
        return const Color(0xFFffc107);
      case 'Expired':
        return const Color(0xFFdc3545);
      default:
        return const Color(0xFF6c757d);
    }
  }

  void _filterAndSortProfiles() {
    // Filter
    var filtered = _profiles.where((profile) {
      final matchesSearch =
          _searchTerm.isEmpty ||
          (profile['full_name'] ?? '').toLowerCase().contains(
            _searchTerm.toLowerCase(),
          ) ||
          (profile['document_number'] ?? '').toLowerCase().contains(
            _searchTerm.toLowerCase(),
          );

      final matchesType =
          _filterType == 'All' || profile['profile_type'] == _filterType;

      return matchesSearch && matchesType;
    }).toList();

    // Sort
    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'name-asc':
          return (a['full_name'] ?? '').toString().compareTo(
            (b['full_name'] ?? '').toString(),
          );
        case 'name-desc':
          return (b['full_name'] ?? '').toString().compareTo(
            (a['full_name'] ?? '').toString(),
          );
        case 'type':
          return (a['profile_type'] ?? '').toString().compareTo(
            (b['profile_type'] ?? '').toString(),
          );
        case 'status':
          return (a['status'] ?? '').toString().compareTo(
            (b['status'] ?? '').toString(),
          );
        default:
          return 0;
      }
    });

    setState(() {
      _filteredProfiles = filtered;
    });
  }

  void _showAddProfileModal() {
    showDialog(
      context: context,
      builder: (context) => AddProfileModal(onSubmit: _handleAddProfile),
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
              content: Text('Profile added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        // Force immediate refresh - bypass cache
        setState(() => _isLoading = true);
        await _fetchProfiles();
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

  void _showProfileDetails(Map<String, dynamic> profile) {
    showDialog(
      context: context,
      builder: (context) => ProfileDetailsModal(
        profile: profile,
        documents: _documents.map((d) => TypeHelpers.toMap(d)).toList(),
        onEdit: () => _showEditProfileModal(profile),
        onDelete: () => _confirmDeleteProfile(profile),
        onAddDocument: () =>
            _showAddDocumentModal(initialProfileId: profile['id']?.toString()),
        onOpenDocument: (document) => _showDocumentDetails(document),
      ),
    );
  }

  void _showAddDocumentModal({String? initialProfileId}) {
    if (_profiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create a profile first')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AddDocumentModal(
        profiles: _profiles
            .map((profile) => TypeHelpers.toMap(profile))
            .toList(),
        initialProfileId: initialProfileId,
        onSubmit: _handleAddDocument,
      ),
    );
  }

  Future<void> _handleAddDocument(Map<String, dynamic> documentData) async {
    try {
      final file = documentData['documentFile'];
      if (file is! File) {
        throw Exception('Please select a document file');
      }

      final response = await ApiService.uploadDocument(documentData, file);
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Document upload failed');
      }

      await _fetchProfiles();
      final expiryDate = documentData['dateOfExpiry']?.toString();
      final uploadedDocumentId = response['data']?['id']?.toString();
      if (expiryDate != null &&
          expiryDate.isNotEmpty &&
          uploadedDocumentId != null) {
        await LocalNotificationService.scheduleDocumentExpiryNotifications(
          documentId: uploadedDocumentId,
          documentName: documentData['documentName']?.toString() ?? 'Document',
          expiryDate: DateTime.parse(expiryDate),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add document: $error'),
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
        document: document,
        onEdit: () => _showEditDocumentModal(document),
        onDelete: () => _confirmDeleteDocument(document),
        onShare: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SecureSharingScreen(
              initialDocumentId: document['id']?.toString(),
            ),
          ),
        ),
        onDownload: () => _downloadDocument(document),
      ),
    );
  }

  void _showEditDocumentModal(Map<String, dynamic> document) {
    showDialog(
      context: context,
      builder: (context) => EditDocumentModal(
        document: document,
        profiles: _profiles
            .map((profile) => TypeHelpers.toMap(profile))
            .toList(),
        onSubmit: (data) => _handleEditDocument(document['id'], data),
      ),
    );
  }

  Future<void> _handleEditDocument(
    dynamic documentId,
    Map<String, dynamic> documentData,
  ) async {
    try {
      final response = await ApiService.updateDocument(
        documentId,
        documentData,
      );
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Document update failed');
      }

      await _fetchProfiles();
      final expiryDate = documentData['expiryDate']?.toString();
      if (expiryDate != null && expiryDate.isNotEmpty) {
        await LocalNotificationService.scheduleDocumentExpiryNotifications(
          documentId: documentId.toString(),
          documentName: documentData['documentName']?.toString() ?? 'Document',
          expiryDate: DateTime.parse(expiryDate),
        );
      } else {
        await LocalNotificationService.cancelDocumentNotifications(
          documentId.toString(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update document: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
        onConfirm: () => _deleteProfileDocument(document['id']),
      ),
    );
  }

  Future<void> _deleteProfileDocument(dynamic documentId) async {
    try {
      final response = await ApiService.deleteDocument(documentId);
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Document deletion failed');
      }

      await LocalNotificationService.cancelDocumentNotifications(
        documentId.toString(),
      );
      await _fetchProfiles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete document: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadDocument(Map<String, dynamic> document) async {
    try {
      final bytes = await ApiService.downloadDocument(document['id']);
      final fileName =
          document['file_name'] ?? document['document_name'] ?? 'document';
      final path = await FileDownloadService.downloadFile(
        bytes: bytes,
        fileName: fileName.toString(),
        mimeType: _getDocumentMimeType(document['file_type']?.toString()),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document saved to $path'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: () => Share.shareXFiles([XFile(path)]),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download document: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getDocumentMimeType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  void _showEditProfileModal(Map<String, dynamic> profile) {
    showDialog(
      context: context,
      builder: (context) => EditProfileModal(
        profile: profile,
        onSubmit: (data, photoFile) =>
            _handleEditProfile(profile['id'], data, photoFile),
      ),
    );
  }

  Future<void> _handleEditProfile(
    dynamic profileId,
    Map<String, dynamic> profileData,
    File? photoFile,
  ) async {
    try {
      final response = await ApiService.updateProfileWithPhoto(
        profileId,
        profileData,
        photoFile,
      );

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        // Force immediate refresh - bypass cache
        setState(() => _isLoading = true);
        await _fetchProfiles();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmDeleteProfile(Map<String, dynamic> profile) {
    showDialog(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Delete Profile',
        message:
            'Are you sure you want to delete "${profile['full_name']}"? This action cannot be undone.',
        confirmText: 'Delete',
        type: 'danger',
        onConfirm: () => _handleDeleteProfile(profile['id']),
      ),
    );
  }

  Future<void> _handleDeleteProfile(dynamic profileId) async {
    // Store original profile for rollback
    final originalProfile = _profiles.firstWhere(
      (p) => p['id']?.toString() == profileId?.toString(),
      orElse: () => {},
    );

    // 1. Optimistic Local Delete (0ms instant removal off screen)
    setState(() {
      _profiles.removeWhere(
        (p) => p['id']?.toString() == profileId?.toString(),
      );
      _filterAndSortProfiles();
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

    // 2. Background server call
    try {
      await ApiService.deleteProfile(profileId);
    } catch (error) {
      // Rollback: Restore profile if server delete fails
      if (mounted && originalProfile.isNotEmpty) {
        setState(() {
          _profiles.add(originalProfile);
          _filterAndSortProfiles();
        });
        // Save back to cache (raw profile without UI properties)
        final rawProfiles = _profiles.map((p) {
          final copy = Map<String, dynamic>.from(p);
          copy.remove('initials');
          copy.remove('status');
          copy.remove('bgColor');
          return copy;
        }).toList();
        await CacheService.saveProfilesCache(rawProfiles);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $error'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF242424) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF212529);
    final subtextColor = isDark
        ? const Color(0xFFadb5bd)
        : const Color(0xFF6c757d);
    final borderColor = isDark
        ? const Color(0xFF404040)
        : const Color(0xFFDEE2E6);

    final safeFilterType = _profileTypes.contains(_filterType)
        ? _filterType
        : 'All';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? SkeletonLoader.profileList()
          : RefreshIndicator(
              onRefresh: _fetchProfiles,
              color: const Color(0xFF0d6efd),
              child: CustomScrollView(
                slivers: [
                  // Page Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profiles',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_profiles.length} ${_profiles.length == 1 ? 'person' : 'people'} managed',
                            style: TextStyle(fontSize: 14, color: subtextColor),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Search and Filter Row
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Container(
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: borderColor),
                              ),
                              child: TextField(
                                controller: _searchController,
                                style: TextStyle(color: textColor),
                                decoration: InputDecoration(
                                  hintText: 'Search profiles...',
                                  hintStyle: TextStyle(color: subtextColor),
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: subtextColor,
                                  ),
                                  suffixIcon: _searchTerm.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(
                                            Icons.close,
                                            size: 20,
                                            color: subtextColor,
                                          ),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {
                                              _searchTerm = '';
                                              _filterType = 'All';
                                            });
                                            _filterAndSortProfiles();
                                          },
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                                onChanged: (value) {
                                  setState(() => _searchTerm = value);
                                  _filterAndSortProfiles();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: borderColor),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: safeFilterType,
                                  dropdownColor: cardBg,
                                  isExpanded: true,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textColor,
                                  ),
                                  items: _profileTypes.map((type) {
                                    return DropdownMenuItem(
                                      value: type,
                                      child: Text(
                                        type,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: textColor,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _filterType = value);
                                      _filterAndSortProfiles();
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Sort Dropdown
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Container(
                        width: 200,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _sortBy,
                            dropdownColor: cardBg,
                            isExpanded: true,
                            style: TextStyle(fontSize: 14, color: textColor),
                            items: [
                              DropdownMenuItem(
                                value: 'name-asc',
                                child: Text(
                                  'Name (A-Z)',
                                  style: TextStyle(color: textColor),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'name-desc',
                                child: Text(
                                  'Name (Z-A)',
                                  style: TextStyle(color: textColor),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'type',
                                child: Text(
                                  'Profile Type',
                                  style: TextStyle(color: textColor),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'status',
                                child: Text(
                                  'Status',
                                  style: TextStyle(color: textColor),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _sortBy = value);
                                _filterAndSortProfiles();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Add Profile Button
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _showAddProfileModal,
                          icon: const Icon(Icons.person_add, size: 20),
                          label: const Text(
                            'Add New Profile',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0d6efd),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Profiles List
                  _filteredProfiles.isEmpty
                      ? SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 80,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _profiles.isEmpty
                                      ? 'No profiles yet'
                                      : 'No profiles found',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF212529),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _profiles.isEmpty
                                      ? 'Add your first profile to get started'
                                      : 'Try adjusting your search or filter',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF6c757d),
                                  ),
                                ),
                                if (_profiles.isEmpty) ...[
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _showAddProfileModal,
                                    icon: const Icon(Icons.person_add),
                                    label: const Text('Add First Profile'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0d6efd),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            Responsive.getPadding(context),
                            0,
                            Responsive.getPadding(context),
                            16,
                          ),
                          sliver:
                              Responsive.isTablet(context) ||
                                  Responsive.isLargeTablet(context)
                              ? SliverGrid(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount:
                                            Responsive.getCrossAxisCount(
                                              context,
                                              phonePortrait: 1,
                                              phoneLandscape: 2,
                                              tabletPortrait: 2,
                                              tabletLandscape: 3,
                                            ),
                                        childAspectRatio:
                                            Responsive.isLandscape(context)
                                            ? 2.5
                                            : 2.0,
                                        crossAxisSpacing: Responsive.getSpacing(
                                          context,
                                          12,
                                        ),
                                        mainAxisSpacing: Responsive.getSpacing(
                                          context,
                                          12,
                                        ),
                                      ),
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    final profile = _filteredProfiles[index];
                                    return _buildProfileCard(profile);
                                  }, childCount: _filteredProfiles.length),
                                )
                              : SliverList(
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    final profile = _filteredProfiles[index];
                                    return _buildProfileCard(profile);
                                  }, childCount: _filteredProfiles.length),
                                ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileCard(dynamic profile) {
    final status = profile['status'] as String;
    final bgColor = profile['bgColor'] as Color;
    final photoUrl = profile['photo_url'];
    final fullPhotoUrl = TypeHelpers.getFullImageUrl(photoUrl?.toString());

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

    // Count documents for this profile
    final profileId = profile['id'];
    final documentCount = _documents
        .where((doc) => doc['profile_id']?.toString() == profileId?.toString())
        .length;

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
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(28),
            ),
            child: fullPhotoUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.network(
                      fullPhotoUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Text(
                            profile['initials'] ?? '??',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : Center(
                    child: Text(
                      profile['initials'] ?? '??',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile['full_name'] ?? 'Unknown',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      profile['document_number'] != null &&
                              profile['document_number'].toString().isNotEmpty
                          ? profile['document_number'].toString()
                          : profile['nationality'] ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: subtitleColor),
                    ),
                  ),
                  if (documentCount > 0) ...[
                    Text(' • ', style: TextStyle(color: subtitleColor)),
                    Icon(Icons.description, size: 14, color: subtitleColor),
                    const SizedBox(width: 4),
                    Text(
                      '$documentCount doc${documentCount > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 13,
                        color: subtitleColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: subtitleColor),
            ],
          ),
          onTap: () => _showProfileDetails(TypeHelpers.toMap(profile)),
        ),
      ),
    );
  }
}
