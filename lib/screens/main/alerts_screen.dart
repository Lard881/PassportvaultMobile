import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/cache_service.dart';
import '../../widgets/modals/document_details_modal.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/skeleton_loader.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool _isLoading = true;
  List<dynamic> _documents = [];
  List<dynamic> _profiles = [];
  String _filterPriority = 'All';
  final Set<String> _dismissedAlerts = {};
  bool _expiryRemindersEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadCachedDataAndRefresh();
  }

  /// Stale-while-revalidate pattern
  Future<void> _loadCachedDataAndRefresh() async {
    await _loadCachedData();
    
    final isDocsStale = await CacheService.isDocumentsCacheStale();
    final isProfilesStale = await CacheService.isProfilesCacheStale();
    
    if (isDocsStale || isProfilesStale || _documents.isEmpty) {
      _fetchData();
    }
  }

  Future<void> _loadCachedData() async {
    final cachedDocs = await CacheService.getDocumentsCache();
    final cachedProfiles = await CacheService.getProfilesCache();
    if (mounted && (cachedDocs.isNotEmpty || cachedProfiles.isNotEmpty)) {
      setState(() {
        _documents = cachedDocs.where((doc) => doc['expiry_date'] != null).toList();
        _profiles = cachedProfiles;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSettings() async {
    try {
      final response = await ApiService.getSettings();
      if (response['success'] == true && response['data'] != null) {
        final settings = response['data'];
        setState(() {
          _expiryRemindersEnabled = settings['expiry_reminders'] ?? true;
        });
      }
    } catch (error) {
      debugPrint('[AlertsScreen] Failed to load settings: $error');
    }
  }

  Future<void> _fetchData() async {
    if (_documents.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      // Fetch documents
      final docsResponse = await ApiService.getDocuments();
      if (docsResponse['success'] == true) {
        final rawDocs = docsResponse['data'] as List? ?? [];
        await CacheService.saveDocumentsCache(rawDocs);

        _documents = rawDocs
            .where((doc) => doc['expiry_date'] != null)
            .toList();
      }

      // Fetch profiles
      final profilesResponse = await ApiService.getProfiles();
      if (profilesResponse['success'] == true) {
        final rawProfiles = profilesResponse['data'] as List? ?? [];
        await CacheService.saveProfilesCache(rawProfiles);
        _profiles = rawProfiles;
      }
    } catch (error) {
      if (mounted && _documents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load alerts: $error'),
            backgroundColor: const Color(0xFFdc3545),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int _calculateDaysToExpiry(String expiryDate) {
    try {
      final today = DateTime.now();
      final expiry = DateTime.parse(expiryDate);
      return expiry.difference(today).inDays;
    } catch (e) {
      return 0;
    }
  }

  Map<String, dynamic> _generateAlert(dynamic doc) {
    final daysToExpiry = _calculateDaysToExpiry(doc['expiry_date']);
    final docId = doc['id'].toString();
    
    if (_dismissedAlerts.contains(docId)) return {};
    
    if (daysToExpiry < 0) {
      return {
        'id': '$docId-expired',
        'type': 'error',
        'priority': 'high',
        'title': 'Document Expired',
        'message': '${doc['document_name']} has expired ${daysToExpiry.abs()} days ago',
        'document': doc,
        'daysToExpiry': daysToExpiry,
      };
    } else if (daysToExpiry <= 7) {
      return {
        'id': '$docId-critical',
        'type': 'warning',
        'priority': 'high',
        'title': 'Expires Very Soon',
        'message': '${doc['document_name']} expires in $daysToExpiry ${daysToExpiry == 1 ? 'day' : 'days'}',
        'document': doc,
        'daysToExpiry': daysToExpiry,
      };
    } else if (daysToExpiry <= 30) {
      return {
        'id': '$docId-warning',
        'type': 'warning',
        'priority': 'medium',
        'title': 'Expires Soon',
        'message': '${doc['document_name']} expires in $daysToExpiry days',
        'document': doc,
        'daysToExpiry': daysToExpiry,
      };
    } else if (daysToExpiry <= 90) {
      return {
        'id': '$docId-info',
        'type': 'info',
        'priority': 'low',
        'title': 'Upcoming Expiry',
        'message': '${doc['document_name']} expires in $daysToExpiry days',
        'document': doc,
        'daysToExpiry': daysToExpiry,
      };
    }
    
    return {};
  }

  List<Map<String, dynamic>> _getAlerts() {
    final alerts = <Map<String, dynamic>>[];
    
    for (var doc in _documents) {
      final alert = _generateAlert(doc);
      if (alert.isNotEmpty) {
        alerts.add(alert);
      }
    }
    
    // Sort by priority
    alerts.sort((a, b) {
      const priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
      final priorityA = priorityOrder[a['priority']] ?? 3;
      final priorityB = priorityOrder[b['priority']] ?? 3;
      if (priorityA != priorityB) return priorityA.compareTo(priorityB);
      // Secondary sort by days to expiry
      return (a['daysToExpiry'] as int).compareTo(b['daysToExpiry'] as int);
    });
    
    return alerts;
  }

  List<Map<String, dynamic>> _getFilteredAlerts() {
    final alerts = _getAlerts();
    if (_filterPriority == 'All') return alerts;
    return alerts.where((a) => a['priority'] == _filterPriority.toLowerCase()).toList();
  }

  Color _getAlertColor(String type) {
    switch (type) {
      case 'error':
        return const Color(0xFFdc3545);
      case 'warning':
        return const Color(0xFFffc107);
      case 'info':
        return const Color(0xFF0d6efd);
      default:
        return const Color(0xFF6c757d);
    }
  }

  IconData _getAlertIcon(String type) {
    switch (type) {
      case 'error':
        return Icons.error;
      case 'warning':
        return Icons.warning;
      case 'info':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  void _handleDismissAlert(String docId) {
    setState(() {
      _dismissedAlerts.add(docId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Alert dismissed'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleClearAll() {
    setState(() {
      for (var alert in _getAlerts()) {
        final docId = alert['document']['id'].toString();
        _dismissedAlerts.add(docId);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All alerts cleared'),
        backgroundColor: Color(0xFF198754),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allAlerts = _expiryRemindersEnabled ? _getAlerts() : [];
    final filteredAlerts = _expiryRemindersEnabled ? _getFilteredAlerts() : [];
    
    final priorityCounts = {
      'high': allAlerts.where((a) => a['priority'] == 'high').length,
      'medium': allAlerts.where((a) => a['priority'] == 'medium').length,
      'low': allAlerts.where((a) => a['priority'] == 'low').length,
    };

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? SkeletonLoader.alertList()
          : RefreshIndicator(
              onRefresh: () async {
                await _loadSettings();
                await _fetchData();
              },
              color: const Color(0xFF0d6efd),
              child: CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Alerts',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF212529),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _expiryRemindersEnabled
                                    ? '${allAlerts.length} active ${allAlerts.length == 1 ? 'notification' : 'notifications'}'
                                    : 'Expiry reminders are disabled',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6c757d),
                                ),
                              ),
                            ],
                          ),
                          if (allAlerts.isNotEmpty && _expiryRemindersEnabled)
                            OutlinedButton(
                              onPressed: _handleClearAll,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0d6efd),
                                side: const BorderSide(color: Color(0xFF0d6efd)),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                              child: const Text('Clear All'),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Show info when reminders are disabled
                  if (!_expiryRemindersEnabled)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCFE2FF),
                          border: Border.all(color: const Color(0xFF9EC5FE)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.notifications_off,
                              size: 48,
                              color: Color(0xFF084298),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Expiry Reminders Disabled',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF084298),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'You have disabled expiry reminders in your settings. Enable them to see document expiry alerts.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF084298),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(context, '/settings');
                              },
                              icon: const Icon(Icons.settings),
                              label: const Text('Go to Settings'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0d6efd),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Priority Summary Cards (only show if enabled)
                  if (_expiryRemindersEnabled)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.3,
                          children: [
                            _buildPriorityCard('HIGH', priorityCounts['high']!, const Color(0xFFdc3545), 'High'),
                            _buildPriorityCard('MEDIUM', priorityCounts['medium']!, const Color(0xFFffc107), 'Medium'),
                            _buildPriorityCard('LOW', priorityCounts['low']!, const Color(0xFF0d6efd), 'Low'),
                          ],
                        ),
                      ),
                    ),

                  if (_expiryRemindersEnabled) const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // Filter Dropdown (only show if enabled)
                  if (_expiryRemindersEnabled)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFDEE2E6)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _filterPriority,
                              isExpanded: true,
                              style: const TextStyle(fontSize: 14, color: Color(0xFF212529)),
                              items: const [
                                DropdownMenuItem(value: 'All', child: Text('All Priorities')),
                                DropdownMenuItem(value: 'High', child: Text('High Priority')),
                                DropdownMenuItem(value: 'Medium', child: Text('Medium Priority')),
                                DropdownMenuItem(value: 'Low', child: Text('Low Priority')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _filterPriority = value);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ),

                  if (_expiryRemindersEnabled) const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // Alerts List (only show if enabled)
                  if (_expiryRemindersEnabled)
                    if (filteredAlerts.isEmpty)
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(48),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.notifications_off,
                                size: 60,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                allAlerts.isEmpty ? 'No alerts' : 'No alerts for this filter',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6c757d),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                allAlerts.isEmpty
                                    ? 'All documents are up to date'
                                    : 'Try changing the filter',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6c757d),
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
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final alert = filteredAlerts[index];
                              return _buildAlertCard(alert);
                            },
                            childCount: filteredAlerts.length,
                          ),
                        ),
                      ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              ),
            ),
    );
  }

  Widget _buildPriorityCard(String label, int count, Color color, String filterValue) {
    final isSelected = _filterPriority == filterValue;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterPriority = isSelected ? 'All' : filterValue;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF8F9FA) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6c757d),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final document = alert['document'] as Map<String, dynamic>;
    final color = _getAlertColor(alert['type']);
    final icon = _getAlertIcon(alert['type']);
    final docId = document['id'].toString();
    
    // Find profile
    final profile = _profiles.firstWhere(
      (p) => p['id'] == document['profile_id'],
      orElse: () => {'full_name': 'Unknown'},
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDEE2E6)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => DocumentDetailsModal(
                document: document.cast<String, dynamic>(),
                onEdit: () {
                  Navigator.pop(context);
                },
                onDelete: () {
                  Navigator.pop(context);
                  _fetchData();
                },
                onShare: () {
                  Navigator.pop(context);
                },
                onDownload: () {},
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border(left: BorderSide(color: color, width: 4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  alert['title'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF212529),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  alert['message'],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF212529),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${profile['full_name']} · ${document['document_type']}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF6c757d),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            color: const Color(0xFF6c757d),
                            onPressed: () => _handleDismissAlert(docId),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${alert['priority'].toUpperCase()} PRIORITY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
