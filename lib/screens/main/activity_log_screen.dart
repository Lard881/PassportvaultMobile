import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/skeleton_loader.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  bool _isLoading = true;
  List<dynamic> _activities = [];
  Map<String, dynamic>? _activityStats;
  String _filterType = 'all';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _fetchActivityLog();
  }

  Future<void> _fetchActivityLog() async {
    setState(() => _isLoading = true);

    try {
      // Fetch both activity log and stats in parallel
      final results = await Future.wait([
        ApiService.getActivityLog(
          filter: _filterType != 'all' ? _filterType : null,
          startDate: _startDate?.toIso8601String().split('T')[0],
          endDate: _endDate?.toIso8601String().split('T')[0],
        ),
        ApiService.getActivityStats(),
      ]);
      
      if (results[0]['success'] == true) {
        setState(() {
          _activities = results[0]['data'] ?? [];
        });
      }
      
      if (results[1]['success'] == true) {
        setState(() {
          _activityStats = results[1]['data'];
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load activity log: $error'),
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
  void _resetFilters() {
    setState(() {
      _filterType = 'all';
      _startDate = null;
      _endDate = null;
    });
    _fetchActivityLog();
  }

  IconData _getActivityIcon(String? actionType, String? entityType) {
    if (actionType == 'create') {
      return entityType == 'profile' ? Icons.person_add : Icons.add_circle;
    } else if (actionType == 'update') {
      return Icons.edit;
    } else if (actionType == 'delete') {
      return Icons.delete;
    } else if (actionType == 'share') {
      return Icons.share;
    } else if (actionType == 'backup') {
      return Icons.cloud_upload;
    }
    return Icons.circle;
  }

  Color _getActivityColor(String? actionType) {
    switch (actionType) {
      case 'create':
        return const Color(0xFF198754);
      case 'update':
        return const Color(0xFF0d6efd);
      case 'delete':
        return const Color(0xFFdc3545);
      case 'share':
        return const Color(0xFF9d4edd);
      case 'backup':
        return const Color(0xFF0dcaf0);
      default:
        return const Color(0xFF6c757d);
    }
  }

  String _getRelativeTime(String? timestamp) {
    if (timestamp == null) return '';
    
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return '';
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: _endDate ?? DateTime.now(),
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
      _fetchActivityLog();
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
      _fetchActivityLog();
    }
  }

  bool get _hasActiveFilters {
    return _filterType != 'all' || _startDate != null || _endDate != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? SkeletonLoader.cardList()
          : RefreshIndicator(
              onRefresh: _fetchActivityLog,
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
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Activity Log',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF212529),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Track all changes and activities',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6c757d),
                                ),
                              ),
                            ],
                          ),
                          // Clear Old Logs button removed (unused function)
                        ],
                      ),
                    ),
                  ),

                  // Activity Statistics Cards
                  if (_activityStats != null) ...[
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.5,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        delegate: SliverChildListDelegate([
                          _buildStatCard(
                            'Total Activities',
                            _activityStats!['total_activities']?.toString() ?? '0',
                            Icons.analytics,
                            const Color(0xFF0d6efd),
                          ),
                          _buildStatCard(
                            'This Month',
                            _activityStats!['this_month']?.toString() ?? '0',
                            Icons.calendar_month,
                            const Color(0xFF198754),
                          ),
                          _buildStatCard(
                            'Created',
                            _activityStats!['by_type']?['create']?.toString() ?? '0',
                            Icons.add_circle,
                            const Color(0xFF28a745),
                          ),
                          _buildStatCard(
                            'Updated',
                            _activityStats!['by_type']?['update']?.toString() ?? '0',
                            Icons.edit,
                            const Color(0xFFffc107),
                          ),
                        ]),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],

                  // Filters Card
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDEE2E6)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Activity Type Filter
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Activity Type',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF212529),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFDEE2E6)),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _filterType,
                                          isExpanded: true,
                                          style: const TextStyle(fontSize: 14, color: Color(0xFF212529)),
                                          items: const [
                                            DropdownMenuItem(value: 'all', child: Text('All Activities')),
                                            DropdownMenuItem(value: 'create', child: Text('Created')),
                                            DropdownMenuItem(value: 'update', child: Text('Updated')),
                                            DropdownMenuItem(value: 'delete', child: Text('Deleted')),
                                            DropdownMenuItem(value: 'share', child: Text('Shared')),
                                            DropdownMenuItem(value: 'backup', child: Text('Backups')),
                                          ],
                                          onChanged: (value) {
                                            if (value != null) {
                                              setState(() => _filterType = value);
                                              _fetchActivityLog();
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              
                              // From Date
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'From Date',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF212529),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    OutlinedButton(
                                      onPressed: _selectStartDate,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF212529),
                                        side: const BorderSide(color: Color(0xFFDEE2E6)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      child: Text(
                                        _startDate == null
                                            ? 'Select'
                                            : '${_startDate!.month}/${_startDate!.day}/${_startDate!.year}',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              
                              // To Date
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'To Date',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF212529),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    OutlinedButton(
                                      onPressed: _selectEndDate,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF212529),
                                        side: const BorderSide(color: Color(0xFFDEE2E6)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      child: Text(
                                        _endDate == null
                                            ? 'Select'
                                            : '${_endDate!.month}/${_endDate!.day}/${_endDate!.year}',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          // Reset Button
                          if (_hasActiveFilters) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                onPressed: _resetFilters,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Reset Filters'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF6c757d),
                                  side: const BorderSide(color: Color(0xFF6c757d)),
                                ),
                              ),
                            ),
                          ],
                          
                          // Active Filters Summary
                          if (_hasActiveFilters) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Text(
                                    'Active Filters:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6c757d),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (_filterType != 'all')
                                    Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0d6efd),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _filterType,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  if (_startDate != null)
                                    Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0dcaf0),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'From: ${_startDate!.month}/${_startDate!.day}/${_startDate!.year}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  if (_endDate != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0dcaf0),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'To: ${_endDate!.month}/${_endDate!.day}/${_endDate!.year}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // Activity Timeline
                  if (_activities.isEmpty)
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
                            Icon(Icons.schedule, size: 60, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            const Text(
                              'No activities yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6c757d),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Your activities will appear here',
                              style: TextStyle(
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
                            final activity = _activities[index];
                            final isLast = index == _activities.length - 1;
                            return _buildActivityItem(activity, isLast);
                          },
                          childCount: _activities.length,
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              ),
            ),
    );
  }

  Widget _buildActivityItem(dynamic activity, bool isLast) {
    final actionType = activity['action_type'] as String?;
    final entityType = activity['entity_type'] as String?;
    final icon = _getActivityIcon(actionType, entityType);
    final color = _getActivityColor(actionType);
    final title = '${entityType ?? 'Item'} ${actionType ?? 'modified'}';
    final description = activity['description'] ?? '$actionType $entityType';
    final timestamp = activity['created_at'];

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline
          Column(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              
              // Line
              if (!isLast)
                Container(
                  width: 2,
                  height: 60,
                  color: const Color(0xFFDEE2E6),
                ),
            ],
          ),
          
          const SizedBox(width: 16),
          
          // Content
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDEE2E6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF212529),
                          ),
                        ),
                      ),
                      Text(
                        _getRelativeTime(timestamp),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6c757d),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6c757d),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'By You',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6c757d),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDEE2E6)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6c757d),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
