import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../services/api_service.dart';
import '../../services/cache_service.dart';
import '../../widgets/modals/document_details_modal.dart';
import '../../widgets/skeleton_loader.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isLoading = true;
  List<dynamic> _documents = [];
  Map<DateTime, List<dynamic>> _events = {};
  String _filterStatus = 'All';
  String _sortBy = 'date-asc';

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadCachedDataAndRefresh();
  }

  /// Stale-while-revalidate pattern
  Future<void> _loadCachedDataAndRefresh() async {
    await _loadCachedData();

    final isStale = await CacheService.isDocumentsCacheStale();
    if (isStale || _documents.isEmpty) {
      _fetchDocuments();
    }
  }

  Future<void> _loadCachedData() async {
    final cachedDocs = await CacheService.getDocumentsCache();
    if (mounted && cachedDocs.isNotEmpty) {
      setState(() {
        _processDocuments(cachedDocs);
        _isLoading = false;
      });
    }
  }

  void _processDocuments(List<dynamic> rawDocs) {
    final documents = rawDocs
        .where((doc) => doc['expiry_date'] != null)
        .toList();
    final events = <DateTime, List<dynamic>>{};

    for (var doc in documents) {
      try {
        final expiryDate = DateTime.parse(doc['expiry_date']);
        final dateKey = DateTime(
          expiryDate.year,
          expiryDate.month,
          expiryDate.day,
        );

        if (events[dateKey] == null) {
          events[dateKey] = [];
        }
        events[dateKey]!.add(doc);
      } catch (e) {
        // Skip invalid dates
      }
    }

    _documents = documents;
    _events = events;
  }

  Future<void> _fetchDocuments() async {
    if (_documents.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final response = await ApiService.getDocuments();
      if (response['success'] == true) {
        final rawDocs = response['data'] as List? ?? [];
        await CacheService.saveDocumentsCache(rawDocs);

        if (mounted) {
          setState(() {
            _processDocuments(rawDocs);
          });
        }
      }
    } catch (error) {
      if (mounted && _documents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load calendar: $error'),
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

  List<dynamic> _getEventsForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _events[dateKey] ?? [];
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

  String _getDocumentStatus(String expiryDate) {
    final daysToExpiry = _calculateDaysToExpiry(expiryDate);
    if (daysToExpiry < 0) return 'Expired';
    if (daysToExpiry <= 30) return 'Expiring Soon';
    return 'Valid';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Expired':
        return const Color(0xFFdc3545);
      case 'Expiring Soon':
        return const Color(0xFFffc107);
      case 'Valid':
        return const Color(0xFF198754);
      default:
        return const Color(0xFF6c757d);
    }
  }

  String _formatDate(String date) {
    try {
      final dt = DateTime.parse(date);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (e) {
      return date;
    }
  }

  Map<String, List<dynamic>> _getGroupedDocuments() {
    final filtered = _documents.where((doc) {
      if (_filterStatus == 'All') return true;
      final status = _getDocumentStatus(doc['expiry_date']);
      return status == _filterStatus;
    }).toList();

    // Sort
    filtered.sort((a, b) {
      final daysA = _calculateDaysToExpiry(a['expiry_date']);
      final daysB = _calculateDaysToExpiry(b['expiry_date']);

      switch (_sortBy) {
        case 'date-asc':
          return daysA.compareTo(daysB);
        case 'date-desc':
          return daysB.compareTo(daysA);
        case 'name':
          return (a['document_name'] ?? '').compareTo(b['document_name'] ?? '');
        case 'status':
          return daysA.compareTo(daysB);
        default:
          return 0;
      }
    });

    return {
      'expired': filtered
          .where((doc) => _calculateDaysToExpiry(doc['expiry_date']) < 0)
          .toList(),
      'next30': filtered.where((doc) {
        final days = _calculateDaysToExpiry(doc['expiry_date']);
        return days >= 0 && days <= 30;
      }).toList(),
      'next90': filtered.where((doc) {
        final days = _calculateDaysToExpiry(doc['expiry_date']);
        return days > 30 && days <= 90;
      }).toList(),
      'later': filtered
          .where((doc) => _calculateDaysToExpiry(doc['expiry_date']) > 90)
          .toList(),
    };
  }

  void _goToToday() {
    setState(() {
      _focusedDay = DateTime.now();
      _selectedDay = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _getGroupedDocuments();
    final upcomingExpiries = [
      ...grouped['next30']!,
      ...grouped['next90']!,
    ].take(3).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? const Color(0xFFF4F4F5)
        : const Color(0xFF212529);
    final subtitleColor = isDark
        ? const Color(0xFFA1A1AA)
        : const Color(0xFF6C757D);
    final cardBg = isDark ? const Color(0xFF1E1E22) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF3F3F46)
        : const Color(0xFFDEE2E6);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Expiry Calendar',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF0d6efd),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? SkeletonLoader.calendar()
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
                            'Expiry Calendar',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Track document expiry dates',
                            style: TextStyle(
                              fontSize: 14,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Calendar Widget
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: TableCalendar(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedDay,
                        calendarFormat: _calendarFormat,
                        selectedDayPredicate: (day) =>
                            isSameDay(_selectedDay, day),
                        eventLoader: _getEventsForDay,
                        headerStyle: HeaderStyle(
                          titleCentered: true,
                          formatButtonVisible: false,
                          titleTextStyle: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                          leftChevronIcon: const Icon(
                            Icons.chevron_left,
                            color: Color(0xFF0d6efd),
                          ),
                          rightChevronIcon: const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF0d6efd),
                          ),
                        ),
                        calendarStyle: CalendarStyle(
                          defaultTextStyle: TextStyle(color: textColor),
                          weekendTextStyle: TextStyle(
                            color: isDark
                                ? const Color(0xFFF87171)
                                : const Color(0xFFDC2626),
                          ),
                          outsideTextStyle: TextStyle(color: subtitleColor),
                          todayDecoration: BoxDecoration(
                            color: const Color(
                              0xFF0d6efd,
                            ).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF0d6efd),
                              width: 2,
                            ),
                          ),
                          todayTextStyle: const TextStyle(
                            color: Color(0xFF0d6efd),
                            fontWeight: FontWeight.w600,
                          ),
                          selectedDecoration: const BoxDecoration(
                            color: Color(0xFF0d6efd),
                            shape: BoxShape.circle,
                          ),
                          selectedTextStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          markerDecoration: const BoxDecoration(
                            color: Color(0xFFffc107),
                            shape: BoxShape.circle,
                          ),
                          markersMaxCount: 3,
                        ),
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                        },
                        onPageChanged: (focusedDay) {
                          setState(() {
                            _focusedDay = focusedDay;
                          });
                        },
                      ),
                    ),
                  ),

                  // Go to Today Button
                  if (_focusedDay.month != DateTime.now().month ||
                      _focusedDay.year != DateTime.now().year)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: OutlinedButton.icon(
                          onPressed: _goToToday,
                          icon: const Icon(Icons.today, size: 18),
                          label: const Text('Go to Today'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0d6efd),
                            side: BorderSide(color: const Color(0xFF0d6efd)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Upcoming Expiries Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Upcoming Expiries',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          if (upcomingExpiries.length > 3)
                            TextButton(
                              onPressed: () {
                                // Scroll to all documents section
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF0d6efd),
                              ),
                              child: const Text('View All'),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // Upcoming Documents
                  if (upcomingExpiries.isEmpty)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Center(
                          child: Text(
                            'No upcoming expiries',
                            style: TextStyle(color: subtitleColor),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final doc = upcomingExpiries[index];
                          return _buildDocumentItem(doc);
                        }, childCount: upcomingExpiries.length),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),

                  // All Documents Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'All Documents',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // Filter and Sort Controls
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
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
                                  value: _filterStatus,
                                  isExpanded: true,
                                  dropdownColor: cardBg,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textColor,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'All',
                                      child: Text('All Status'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Expired',
                                      child: Text('Expired'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Expiring Soon',
                                      child: Text('Expiring Soon'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Valid',
                                      child: Text('Valid'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _filterStatus = value);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
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
                                  value: _sortBy,
                                  isExpanded: true,
                                  dropdownColor: cardBg,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textColor,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'date-asc',
                                      child: Text('Soonest First'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'date-desc',
                                      child: Text('Latest First'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'name',
                                      child: Text('By Name'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'status',
                                      child: Text('By Status'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _sortBy = value);
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

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // Summary Cards
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.5,
                        children: [
                          _buildSummaryCard(
                            'EXPIRED',
                            grouped['expired']!.length,
                            const Color(0xFFdc3545),
                          ),
                          _buildSummaryCard(
                            'NEXT 30 DAYS',
                            grouped['next30']!.length,
                            const Color(0xFFffc107),
                          ),
                          _buildSummaryCard(
                            'NEXT 90 DAYS',
                            grouped['next90']!.length,
                            const Color(0xFF0d6efd),
                          ),
                          _buildSummaryCard(
                            'LATER',
                            grouped['later']!.length,
                            const Color(0xFF198754),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Grouped Documents
                  ...['expired', 'next30', 'next90', 'later'].map((key) {
                    final docs = grouped[key]!;
                    if (docs.isEmpty)
                      return const SliverToBoxAdapter(child: SizedBox.shrink());

                    String title;
                    Color color;
                    IconData icon;

                    switch (key) {
                      case 'expired':
                        title = 'Expired (${docs.length})';
                        color = const Color(0xFFdc3545);
                        icon = Icons.error;
                        break;
                      case 'next30':
                        title = 'Next 30 Days (${docs.length})';
                        color = const Color(0xFFffc107);
                        icon = Icons.event;
                        break;
                      case 'next90':
                        title = 'Next 90 Days (${docs.length})';
                        color = const Color(0xFF0d6efd);
                        icon = Icons.event_note;
                        break;
                      case 'later':
                        title = 'Later (${docs.length})';
                        color = const Color(0xFF198754);
                        icon = Icons.event_available;
                        break;
                      default:
                        return const SliverToBoxAdapter(
                          child: SizedBox.shrink(),
                        );
                    }

                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(icon, color: color, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...docs.map((doc) => _buildDocumentItem(doc)),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(String label, int count, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF242424) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFADB5BD) : const Color(0xFF6c757d),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentItem(dynamic doc) {
    final daysToExpiry = _calculateDaysToExpiry(doc['expiry_date']);
    final status = _getDocumentStatus(doc['expiry_date']);
    final statusColor = _getStatusColor(status);
    final profileInitials = (doc['profile_name'] ?? 'UK')
        .split(' ')
        .take(2)
        .map((n) => n.isNotEmpty ? n[0] : '')
        .join()
        .toUpperCase();

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
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF6366f1).withValues(alpha: 0.1),
            child: Text(
              profileInitials,
              style: const TextStyle(
                color: Color(0xFF6366f1),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          title: Text(
            doc['document_name'] ?? 'Untitled Document',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '${doc['profile_name'] ?? 'Unknown'} · ${doc['document_type'] ?? 'Document'}',
                style: TextStyle(fontSize: 14, color: subtitleColor),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    daysToExpiry < 0
                        ? '${daysToExpiry.abs()} days ago (${_formatDate(doc['expiry_date'])})'
                        : 'in $daysToExpiry days (${_formatDate(doc['expiry_date'])})',
                    style: TextStyle(fontSize: 12, color: subtitleColor),
                  ),
                ],
              ),
            ],
          ),
          trailing: Icon(Icons.chevron_right, color: subtitleColor),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => DocumentDetailsModal(
                document: doc.cast<String, dynamic>(),
                onEdit: () {
                  Navigator.pop(context);
                },
                onDelete: () {
                  Navigator.pop(context);
                  _fetchDocuments();
                },
                onShare: () {
                  Navigator.pop(context);
                },
                onDownload: () {},
              ),
            );
          },
        ),
      ),
    );
  }
}
