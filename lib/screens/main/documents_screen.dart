import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../services/file_download_service.dart';
import '../../services/cache_service.dart';
import '../../services/local_notification_service.dart';
import '../../widgets/modals/add_document_modal.dart';
import '../../widgets/modals/document_details_modal.dart';
import '../../widgets/modals/edit_document_modal.dart';
import '../../widgets/confirm_dialog.dart';
import '../../screens/main/secure_sharing_screen.dart';
import '../../services/notification_service.dart';
import '../../utils/type_helpers.dart';
import '../../utils/responsive.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/skeleton_loader.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  List<dynamic> _documents = [];
  List<dynamic> _profiles = [];
  List<dynamic> _filteredDocuments = [];
  String _searchTerm = '';
  String _filterType = 'All Types';
  String _filterProfileId = 'All Profiles';
  String _sortBy = 'name-asc'; // New: Sort option
  final TextEditingController _searchController = TextEditingController();
  DateTime? _lastRefresh;

  @override
  bool get wantKeepAlive => true;

  final List<String> _documentTypes = [
    'All Types',
    'Passport',
    'Visa',
    'National ID',
    'Driver\'s License',
    'Birth Certificate',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadCachedDataAndRefresh();
    _lastRefresh = DateTime.now();
  }

  @override
  void didUpdateWidget(DocumentsScreen oldWidget) {
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
    final cachedDocs = await CacheService.getDocumentsCache();
    final cachedProfiles = await CacheService.getProfilesCache();

    if (mounted && (cachedDocs.isNotEmpty || cachedProfiles.isNotEmpty)) {
      setState(() {
        _documents = cachedDocs;
        _profiles = cachedProfiles;
        _isLoading = false;
        _filterAndSortDocuments();
      });
    }

    // Step 2: Check if cache is stale
    final isDocsStale = await CacheService.isDocumentsCacheStale();
    final isProfilesStale = await CacheService.isProfilesCacheStale();

    // Step 3: If stale, fetch fresh data in background
    if (isDocsStale ||
        isProfilesStale ||
        cachedDocs.isEmpty ||
        cachedProfiles.isEmpty) {
      _fetchDocuments();
    }
  }

  Future<void> _fetchDocuments() async {
    // Don't show loading spinner if we have cached data
    if (_documents.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      // Fetch both documents and profiles
      final results = await Future.wait([
        ApiService.getDocuments(),
        ApiService.getProfiles(),
      ]);

      final documentsResponse = results[0];
      final profilesResponse = results[1];

      if (documentsResponse['success'] == true) {
        final documents = (documentsResponse['data'] as List? ?? []).map((doc) {
          return {
            ...doc,
            'status': _getDocumentStatus(doc['expiry_date']),
            'addedDate':
                doc['uploaded_at'] ??
                doc['created_at'] ??
                DateTime.now().toIso8601String(),
          };
        }).toList();

        await CacheService.saveDocumentsCache(documents);
        if (profilesResponse['success'] == true) {
          await CacheService.saveProfilesCache(
            profilesResponse['data'] as List? ?? [],
          );
        }

        _scheduleDocumentExpiryReminders(documents);

        if (mounted) {
          setState(() {
            _documents = documents;
            _profiles = profilesResponse['data'] as List? ?? [];
            _filterAndSortDocuments();
          });
        }
      }
    } catch (error) {
      // Don't show error if we have cached data
      if (mounted && _documents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load documents: $error'),
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

  void _scheduleDocumentExpiryReminders(List<dynamic> docs) {
    for (var doc in docs) {
      try {
        final id = doc['id'] is int
            ? doc['id']
            : int.tryParse(doc['id']?.toString() ?? '0') ?? 0;
        final expiryStr = doc['expiry_date']?.toString();
        if (id > 0 && expiryStr != null && expiryStr.isNotEmpty) {
          final expiryDate = DateTime.parse(expiryStr);
          NotificationService().scheduleExpiryNotification(
            documentId: id,
            documentName: doc['document_name'] ?? doc['title'] ?? 'Document',
            documentType: doc['document_type'] ?? 'ID',
            expiryDate: expiryDate,
          );
        }
      } catch (_) {}
    }
  }

  String _getDocumentStatus(dynamic expiryDate) {
    if (expiryDate == null || expiryDate.toString().isEmpty) return 'No expiry';

    final daysUntil = DateFormatter.daysUntilExpiry(expiryDate);
    if (daysUntil == null) return 'No expiry';

    if (daysUntil < 0) return 'Expired';
    if (daysUntil <= 30) return 'Expiring Soon';
    return 'Valid';
  }

  IconData _getDocumentIcon(String? type) {
    switch (type) {
      case 'Passport':
        return Icons.book;
      case 'Visa':
        return Icons.flight;
      case 'National ID':
        return Icons.badge;
      case 'Driver\'s License':
        return Icons.directions_car;
      case 'Birth Certificate':
        return Icons.child_care;
      default:
        return Icons.description;
    }
  }

  Color _getDocumentIconColor(String? type) {
    switch (type) {
      case 'Passport':
        return const Color(0xFF6366f1);
      case 'Visa':
        return const Color(0xFF10b981);
      case 'National ID':
        return const Color(0xFF8b5cf6);
      case 'Driver\'s License':
        return const Color(0xFFf59e0b);
      case 'Birth Certificate':
        return const Color(0xFFec4899);
      default:
        return const Color(0xFF6c757d);
    }
  }

  void _filterAndSortDocuments() {
    // Filter
    var filtered = _documents.where((doc) {
      String profileName =
          (doc['profile_name'] ?? doc['profile']?['full_name'] ?? '')
              .toString();
      String profileType =
          (doc['profile_type'] ?? doc['profile']?['profile_type'] ?? '')
              .toString();
      if (profileName.isEmpty && doc['profile_id'] != null) {
        final matchingProfile = _profiles.firstWhere(
          (p) => p['id']?.toString() == doc['profile_id']?.toString(),
          orElse: () => {},
        );
        profileName =
            (matchingProfile['full_name'] ?? matchingProfile['name'] ?? '')
                .toString();
        profileType = (matchingProfile['profile_type'] ?? '').toString();
      }

      final searchLower = _searchTerm.toLowerCase();
      final matchesSearch =
          _searchTerm.isEmpty ||
          (doc['document_name'] ?? '').toString().toLowerCase().contains(
            searchLower,
          ) ||
          (doc['document_number'] ?? '').toString().toLowerCase().contains(
            searchLower,
          ) ||
          (doc['document_type'] ?? '').toString().toLowerCase().contains(
            searchLower,
          ) ||
          profileName.toLowerCase().contains(searchLower) ||
          profileType.toLowerCase().contains(searchLower);

      final matchesType =
          _filterType == 'All Types' || doc['document_type'] == _filterType;
      final matchesProfile =
          _filterProfileId == 'All Profiles' ||
          doc['profile_id']?.toString() == _filterProfileId;

      return matchesSearch && matchesType && matchesProfile;
    }).toList();

    // Sort
    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'name-asc':
          return (a['document_name'] ?? '').toString().compareTo(
            (b['document_name'] ?? '').toString(),
          );
        case 'name-desc':
          return (b['document_name'] ?? '').toString().compareTo(
            (a['document_name'] ?? '').toString(),
          );
        case 'date-new':
          final dateA =
              DateTime.tryParse(a['addedDate'] ?? '') ?? DateTime(1970);
          final dateB =
              DateTime.tryParse(b['addedDate'] ?? '') ?? DateTime(1970);
          return dateB.compareTo(dateA);
        case 'date-old':
          final dateA =
              DateTime.tryParse(a['addedDate'] ?? '') ?? DateTime(1970);
          final dateB =
              DateTime.tryParse(b['addedDate'] ?? '') ?? DateTime(1970);
          return dateA.compareTo(dateB);
        case 'status':
          return (a['status'] ?? '').toString().compareTo(
            (b['status'] ?? '').toString(),
          );
        default:
          return 0;
      }
    });

    setState(() {
      _filteredDocuments = filtered;
    });
  }

  String _formatDate(dynamic date) {
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

  Future<void> _handleAddDocument(Map<String, dynamic> documentData) async {
    try {
      final file =
          documentData['documentFile']; // Dynamic - works for both File (mobile) and bytes (web)
      final response = await ApiService.uploadDocument(documentData, file);

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document uploaded successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        // Force immediate refresh - bypass cache
        setState(() => _isLoading = true);
        await _fetchDocuments();

        // Schedule notifications if document has expiry date
        if (documentData['expiryDate'] != null && response['data'] != null) {
          await LocalNotificationService.scheduleDocumentExpiryNotifications(
            documentId: response['data']['id'].toString(),
            documentName: documentData['documentName'],
            expiryDate: DateTime.parse(documentData['expiryDate']),
          );
        }
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
        document: document,
        onEdit: () => _showEditDocumentModal(document),
        onDelete: () => _confirmDeleteDocument(document),
        onShare: () => _shareDocument(document),
        onDownload: () => _downloadDocument(document),
      ),
    );
  }

  void _showEditDocumentModal(Map<String, dynamic> document) {
    showDialog(
      context: context,
      builder: (context) => EditDocumentModal(
        document: document,
        profiles: _profiles.cast<Map<String, dynamic>>(),
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

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        // Force immediate refresh - bypass cache
        setState(() => _isLoading = true);
        await _fetchDocuments();

        // Reschedule notifications if document has expiry date
        if (documentData['expiryDate'] != null) {
          await LocalNotificationService.scheduleDocumentExpiryNotifications(
            documentId: documentId.toString(),
            documentName: documentData['documentName'],
            expiryDate: DateTime.parse(documentData['expiryDate']),
          );
        } else {
          // If expiry date removed, cancel notifications
          await LocalNotificationService.cancelDocumentNotifications(
            documentId.toString(),
          );
        }
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
        onConfirm: () => _handleDeleteDocument(document['id']),
      ),
    );
  }

  Future<void> _handleDeleteDocument(dynamic documentId) async {
    // Store original document for rollback
    final originalDocument = _documents.firstWhere(
      (d) => d['id']?.toString() == documentId?.toString(),
      orElse: () => {},
    );

    // 1. Optimistic Local Delete (0ms instant removal off screen)
    setState(() {
      _documents.removeWhere(
        (d) => d['id']?.toString() == documentId?.toString(),
      );
      _filterAndSortDocuments();
    });
    await CacheService.removeDocumentFromCache(documentId);

    // Cancel notifications for this document
    await LocalNotificationService.cancelDocumentNotifications(
      documentId.toString(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document deleted successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }

    // 2. Background server call
    try {
      await ApiService.deleteDocument(documentId);
    } catch (error) {
      // Rollback: Restore document if server delete fails
      if (mounted && originalDocument.isNotEmpty) {
        setState(() {
          _documents.add(originalDocument);
          _filterAndSortDocuments();
        });
        await CacheService.saveDocumentsCache(_documents);

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

  Future<void> _downloadDocument(Map<String, dynamic> document) async {
    try {
      final bytes = await ApiService.downloadDocument(document['id']);
      final fileName = document['document_name'] ?? 'document';
      final fileExtension = document['file_type'] ?? 'pdf';
      final fullFileName = '$fileName.$fileExtension';
      final mimeType = _getMimeType(fileExtension);

      // Save to device storage
      final filePath = await FileDownloadService.downloadFile(
        bytes: bytes,
        fileName: fullFileName,
        mimeType: mimeType,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document saved to $filePath'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: () {
                Share.shareXFiles([XFile(filePath)]);
              },
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

  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
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

  void _shareDocument(Map<String, dynamic> document) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SecureSharingScreen(
          initialDocumentId: document['id']?.toString(),
        ),
      ),
    );
  }

  Future<void> _exportAllDocuments() async {
    try {
      // Create JSON export matching web version
      final exportData = {
        'exportDate': DateTime.now().toIso8601String(),
        'totalDocuments': _documents.length,
        'documents': _documents
            .map(
              (doc) => {
                'name': doc['document_name'],
                'category': doc['document_type'],
                'fileName': doc['file_name'],
                'profileName': doc['profile_name'],
                'documentNumber': doc['document_number'],
                'issueDate': doc['issue_date'],
                'expiryDate': doc['expiry_date'],
                'status': doc['status'],
                'notes': doc['notes'],
              },
            )
            .toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      final timestamp = DateTime.now().toIso8601String().split('T')[0];
      final fileName = 'passportvault-documents-$timestamp.json';
      final bytes = utf8.encode(jsonString);

      // Save to device storage
      final filePath = await FileDownloadService.downloadFile(
        bytes: bytes,
        fileName: fileName,
        mimeType: 'application/json',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to $filePath'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: () {
                Share.shareXFiles([
                  XFile(filePath),
                ], text: 'PassportVault Documents Export');
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export documents: $error'),
            backgroundColor: Colors.red,
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

    final safeFilterType = _documentTypes.contains(_filterType)
        ? _filterType
        : 'All Types';
    final validProfileIds = _profiles
        .map((profile) => profile['id']?.toString())
        .whereType<String>()
        .toSet();
    final safeFilterProfileId = validProfileIds.contains(_filterProfileId)
        ? _filterProfileId
        : 'All Profiles';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? SkeletonLoader.documentList()
          : RefreshIndicator(
              onRefresh: _fetchDocuments,
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
                            'Documents',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_documents.length} ${_documents.length == 1 ? 'document' : 'documents'} stored securely',
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
                                  hintText: 'Search documents...',
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
                                            setState(() => _searchTerm = '');
                                            _filterAndSortDocuments();
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
                                  _filterAndSortDocuments();
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
                                  items: _documentTypes.map((type) {
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
                                      _filterAndSortDocuments();
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

                  // Filter by person
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: safeFilterProfileId,
                            dropdownColor: cardBg,
                            isExpanded: true,
                            style: TextStyle(fontSize: 14, color: textColor),
                            items: [
                              DropdownMenuItem(
                                value: 'All Profiles',
                                child: Text(
                                  'All people',
                                  style: TextStyle(color: textColor),
                                ),
                              ),
                              ..._profiles.map((profile) {
                                final profileId = profile['id']?.toString();
                                return DropdownMenuItem(
                                  value: profileId,
                                  child: Text(
                                    profile['full_name']?.toString() ??
                                        profile['name']?.toString() ??
                                        'Unnamed profile',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: textColor),
                                  ),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _filterProfileId = value);
                                _filterAndSortDocuments();
                              }
                            },
                          ),
                        ),
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
                                value: 'date-new',
                                child: Text(
                                  'Newest First',
                                  style: TextStyle(color: textColor),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'date-old',
                                child: Text(
                                  'Oldest First',
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
                                _filterAndSortDocuments();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Add Document Button
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _showAddDocumentModal,
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          label: const Text(
                            'Add Document',
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

                  // Export Button
                  if (_documents.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _exportAllDocuments,
                            icon: const Icon(Icons.download, size: 18),
                            label: Text(
                              'Export All Documents (${_documents.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0d6efd),
                              side: const BorderSide(color: Color(0xFF0d6efd)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // Documents List
                  _filteredDocuments.isEmpty
                      ? SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.description_outlined,
                                  size: 80,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _documents.isEmpty
                                      ? 'No documents yet'
                                      : 'No documents found',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF212529),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _documents.isEmpty
                                      ? 'Upload your first document to get started'
                                      : 'Try adjusting your search or filter',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF6c757d),
                                  ),
                                ),
                                if (_documents.isEmpty) ...[
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _showAddDocumentModal,
                                    icon: const Icon(Icons.add_circle_outline),
                                    label: const Text('Add First Document'),
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
                                            ? 3.0
                                            : 2.5,
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
                                    final doc = _filteredDocuments[index];
                                    return _buildDocumentCard(doc);
                                  }, childCount: _filteredDocuments.length),
                                )
                              : SliverList(
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    final doc = _filteredDocuments[index];
                                    return _buildDocumentCard(doc);
                                  }, childCount: _filteredDocuments.length),
                                ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildDocumentCard(dynamic doc) {
    final docType = doc['document_type'] as String?;
    final iconColor = _getDocumentIconColor(docType);
    final status = _getDocumentStatus(doc['expiry_date']);
    final isExpired = status == 'Expired';
    final isExpiringSoon = status == 'Expiring Soon';
    final isValid = status == 'Valid';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF242424) : Colors.white;
    final textColor = isDark
        ? const Color(0xFFF8F9FA)
        : const Color(0xFF212529);
    final subtitleColor = isDark
        ? const Color(0xFFADB5BD)
        : const Color(0xFF6C757D);

    // Color coding based on status
    Color statusColor;
    Color statusBgTint;
    String? statusBadge;

    if (isExpired) {
      statusColor = const Color(0xFFdc3545); // Red
      statusBgTint = isDark ? const Color(0xFF2d1f1f) : const Color(0xFFfff5f5);
      statusBadge = 'EXPIRED';
    } else if (isExpiringSoon) {
      statusColor = const Color(0xFFffc107); // Yellow/Amber
      statusBgTint = isDark ? const Color(0xFF2d2a1f) : const Color(0xFffffef5);
      statusBadge = 'EXPIRING SOON';
    } else if (isValid) {
      statusColor = const Color(0xFF28a745); // Green
      statusBgTint = isDark ? const Color(0xFF1f2d1f) : const Color(0xFFf5fff5);
      statusBadge = null; // No badge for valid docs
    } else {
      statusColor = isDark ? const Color(0xFF404040) : const Color(0xFFDEE2E6);
      statusBgTint = cardBg;
      statusBadge = null;
    }

    // Border styling
    final borderColor = (isExpired || isExpiringSoon || isValid)
        ? statusColor
        : (isDark ? const Color(0xFF404040) : const Color(0xFFDEE2E6));
    final borderWidth = (isExpired || isExpiringSoon) ? 2.0 : 1.5;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: statusBgTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Stack(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (isExpired || isExpiringSoon || isValid)
                      ? statusColor.withValues(alpha: 0.1)
                      : iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getDocumentIcon(docType),
                  color: (isExpired || isExpiringSoon || isValid)
                      ? statusColor
                      : iconColor,
                  size: 24,
                ),
              ),
              // Status dot badge
              if (isExpired || isExpiringSoon || isValid)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: statusBgTint, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                doc['document_name'] ?? 'Unnamed Document',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                doc['file_name'] ?? doc['document_type'] ?? 'Unknown',
                style: TextStyle(fontSize: 14, color: subtitleColor),
              ),
              if ((doc['profile_name'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  doc['profile_name'].toString(),
                  style: TextStyle(fontSize: 12, color: subtitleColor),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  if (doc['issue_date'] != null) ...[
                    Icon(Icons.calendar_today, size: 11, color: subtitleColor),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Issued: ${_formatDate(doc['issue_date'])}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: subtitleColor),
                      ),
                    ),
                    Text(' • ', style: TextStyle(color: subtitleColor)),
                  ],
                  if (doc['expiry_date'] != null) ...[
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (statusBadge != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                statusBadge,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: isExpiringSoon
                                      ? Colors.black87
                                      : Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              (isExpired || isExpiringSoon)
                                  ? _formatDate(doc['expiry_date'])
                                  : 'Expires: ${_formatDate(doc['expiry_date'])}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: (isExpired || isExpiringSoon || isValid)
                                    ? statusColor
                                    : subtitleColor,
                                fontWeight: (isExpired || isExpiringSoon)
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Flexible(
                      child: Text(
                        'No expiry',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: subtitleColor),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          trailing: Icon(Icons.more_vert, color: subtitleColor, size: 20),
          onTap: () => _showDocumentDetails(TypeHelpers.toMap(doc)),
        ),
      ),
    );
  }
}
