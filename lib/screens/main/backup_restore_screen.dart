import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_theme.dart';
import '../../services/api_service.dart';
import '../../providers/connectivity_provider.dart';

/// WhatsApp-Style Backup & Restore Screen
/// Exact replica of WhatsApp's backup interface
class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _isLoading = true;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _autoBackup = false;
  String _backupFrequency = 'daily';
  Map<String, dynamic>? _lastBackupInfo;
  Map<String, dynamic>? _backupExists;

  @override
  void initState() {
    super.initState();
    _loadBackupStatus();
  }

  Future<void> _loadBackupStatus() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      bool savedAutoBackup = prefs.getBool('pv_auto_backup') ?? false; // Default to false instead of true
      String savedFrequency = prefs.getString('pv_backup_frequency') ?? 'daily';

      // Don't override local preference with backend - let user control
      // Only sync if local preference doesn't exist yet
      if (!prefs.containsKey('pv_auto_backup')) {
        try {
          final settingsRes = await ApiService.getSettings();
          if (settingsRes['success'] == true && settingsRes['data'] != null) {
            savedAutoBackup = settingsRes['data']['auto_backup'] ?? false;
            await prefs.setBool('pv_auto_backup', savedAutoBackup);
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _autoBackup = savedAutoBackup;
          _backupFrequency = savedFrequency;
        });
      }

      final response = await ApiService.getLatestBackup();
      if (response['success'] == true && response['data'] != null) {
        if (mounted) {
          setState(() {
            final data = response['data'];
            _lastBackupInfo = {
              'timestamp': DateTime.parse(data['created_at']).millisecondsSinceEpoch,
              'profileCount': data['profile_count'],
              'documentCount': data['document_count'],
              'sizeMB': data['size_mb'],
            };
            _backupExists = {
              'exists': true,
              'profileCount': data['profile_count'],
              'documentCount': data['document_count'],
              'sizeMB': data['size_mb'],
              'id': data['id'],
            };
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _lastBackupInfo = null;
            _backupExists = null;
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _lastBackupInfo = null;
          _backupExists = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleAutoBackup(bool value) async {
    setState(() => _autoBackup = value);
    
    // Save to local storage FIRST
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pv_auto_backup', value);

    // Then sync to backend (but don't wait for it or let it override)
    try {
      await ApiService.updateSettings({'auto_backup': value});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? 'Automatic backup enabled' : 'Automatic backup disabled'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (_) {
      // Even if backend fails, keep local setting
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Setting saved locally: ${value ? "ON" : "OFF"}'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _setBackupFrequency(String frequency) async {
    setState(() => _backupFrequency = frequency);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pv_backup_frequency', frequency);
  }

  String _getLastBackupTime() {
    if (_lastBackupInfo == null) return 'Never';
    
    final timestamp = _lastBackupInfo!['timestamp'] as int;
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  Future<void> _handleCreateBackup() async {
    setState(() => _isBackingUp = true);

    try {
      final response = await ApiService.createBackup(type: 'manual');
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Backup created: ${data['profile_count']} profiles, ${data['document_count']} documents'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          await _loadBackupStatus();
        }
      } else {
        throw Exception(response['message'] ?? 'Backup failed');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: $error'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBackingUp = false);
      }
    }
  }

  Future<void> _handleRestoreBackup() async {
    if (_backupExists == null || _backupExists!['id'] == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from backup?'),
        content: const Text('Your current data will be replaced with the backup.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6c757d))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isRestoring = true);

    try {
      final backupId = _backupExists!['id'];
      final response = await ApiService.restoreBackup(backupId, mode: 'overwrite');
      
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        if (mounted) {
          final message = 'Restored successfully! ${data['profiles_restored']} profiles, ${data['documents_restored']} documents.';
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppTheme.successColor,
              duration: const Duration(seconds: 2),
            ),
          );
          
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          }
        }
      } else {
        throw Exception(response['message'] ?? 'Restore failed');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $error'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRestoring = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgPrimary = isDark ? AppTheme.darkBgPrimary : AppTheme.lightBgSecondary;
    final bgSecondary = isDark ? AppTheme.darkBgCard : AppTheme.lightBgCard;
    final textPrimary = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;
    final textSecondary = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.lightTextSecondary;
    final borderColor = isDark
        ? AppTheme.darkBorderColor
        : AppTheme.lightBorderColor;

    return Scaffold(
      backgroundColor: bgPrimary,
      appBar: AppBar(
        backgroundColor: bgSecondary,
        foregroundColor: textPrimary,
        elevation: 0,
        title: const Text('Backups', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : RefreshIndicator(
              onRefresh: _loadBackupStatus,
              color: AppTheme.primaryColor,
              child: ListView(
                children: [
                  // Auto Backup Toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: bgPrimary,
                      border: Border(bottom: BorderSide(color: borderColor)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Automatic backup preference',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _autoBackup
                                    ? 'Enabled. Use Back Up Now to create a backup.'
                                    : 'Choose whether automatic backups are enabled.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _toggleAutoBackup(!_autoBackup),
                          child: Container(
                            width: 50,
                            height: 28,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: _autoBackup
                                  ? AppTheme.primaryColor
                                  : (isDark
                                        ? AppTheme.darkBorderColor
                                        : AppTheme.lightBorderColor),
                            ),
                            child: AnimatedAlign(
                              duration: const Duration(milliseconds: 200),
                              alignment: _autoBackup ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                width: 22,
                                height: 22,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Backup Frequency (only when auto backup is ON)
                  if (_autoBackup)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: bgPrimary,
                        border: Border(bottom: BorderSide(color: borderColor)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Backup frequency',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _backupFrequency.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                          DropdownButton<String>(
                            value: _backupFrequency,
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(value: 'never', child: Text('Never')),
                              DropdownMenuItem(value: 'daily', child: Text('Daily')),
                              DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                            ],
                            onChanged: (value) {
                              if (value != null) _setBackupFrequency(value);
                            },
                          ),
                        ],
                      ),
                    ),

                  // Last Backup Info
                  if (_lastBackupInfo != null)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: bgPrimary,
                        border: Border(bottom: BorderSide(color: bgSecondary, width: 8)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Last backup',
                            style: TextStyle(
                              fontSize: 16,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getLastBackupTime(),
                            style: TextStyle(
                              fontSize: 14,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_lastBackupInfo!['documentCount']} documents • ${_lastBackupInfo!['profileCount']} profiles • ${_lastBackupInfo!['sizeMB']} MB',
                            style: TextStyle(
                              fontSize: 14,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Backup Button
                  Consumer<ConnectivityProvider>(
                    builder: (context, connectivity, _) {
                      final isOffline = !connectivity.isOnline;
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: (_isBackingUp || isOffline) ? null : _handleCreateBackup,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  AppTheme.lightTextSecondary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              _isBackingUp ? 'BACKING UP...' : 'BACK UP NOW',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Restore Section (only if backup exists)
                  if (_backupExists != null && _backupExists!['exists'] == true) ...[
                    Container(
                      height: 8,
                      color: bgSecondary,
                    ),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: bgPrimary,
                        border: Border(bottom: BorderSide(color: borderColor)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RESTORE',
                            style: TextStyle(
                              fontSize: 14,
                              color: textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Restore from backup',
                            style: TextStyle(
                              fontSize: 16,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Replace your current data with backup data',
                            style: TextStyle(
                              fontSize: 14,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: _isRestoring ? null : _handleRestoreBackup,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: AppTheme.primaryColor,
                              ),
                              foregroundColor: AppTheme.primaryColor,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              _isRestoring ? 'RESTORING...' : 'RESTORE',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Info Text
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _backupExists != null && _backupExists!['exists'] == true
                          ? 'Your documents and profiles are backed up to the cloud.'
                          : 'Your documents and profiles are backed up to the cloud. Create your first backup to secure your data.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
