import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// WhatsApp-style backup restore service
/// Automatically detects and offers to restore backup on first launch
class BackupRestoreService {
  /// Check if this is first launch and offer restore if backup exists
  static Future<void> checkAndOfferRestore(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if we've already shown restore prompt
      final hasShownRestorePrompt = prefs.getBool('pv_shown_restore_prompt') ?? false;
      
      if (hasShownRestorePrompt) {
        print('[BackupRestore] Already shown restore prompt, skipping');
        return;
      }

      // Check if backup exists on server
      print('[BackupRestore] Checking for existing backup...');
      final response = await ApiService.getLatestBackup();
      
      if (response['success'] == true && response['data'] != null) {
        final backupData = response['data'];
        final documentCount = backupData['document_count'] ?? 0;
        final profileCount = backupData['profile_count'] ?? 0;
        
        print('[BackupRestore] Found backup: $documentCount documents, $profileCount profiles');
        
        // Mark that we've shown the prompt
        await prefs.setBool('pv_shown_restore_prompt', true);
        
        // Show restore dialog (WhatsApp-style)
        if (context.mounted) {
          final shouldRestore = await _showRestoreDialog(
            context,
            documentCount: documentCount,
            profileCount: profileCount,
            sizeMB: backupData['size_mb'],
          );
          
          if (shouldRestore == true) {
            await _performRestore(context, backupData['id']);
          }
        }
      } else {
        print('[BackupRestore] No backup found');
        // Mark that we checked (so we don't keep checking)
        await prefs.setBool('pv_shown_restore_prompt', true);
      }
    } catch (error) {
      print('[BackupRestore] Error checking for backup: $error');
      // Mark as checked to avoid repeated failed attempts
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pv_shown_restore_prompt', true);
    }
  }

  /// Show WhatsApp-style restore dialog
  static Future<bool?> _showRestoreDialog(
    BuildContext context, {
    required int documentCount,
    required int profileCount,
    dynamic sizeMB,
  }) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Force user to make a choice
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cloud_download, color: Color(0xFF0d6efd), size: 28),
            SizedBox(width: 12),
            Text(
              'Restore Backup?',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'We found a backup from your previous session.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFe3f2fd),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF0d6efd).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Backup contains:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF084298),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.description, size: 16, color: Color(0xFF0d6efd)),
                      const SizedBox(width: 8),
                      Text(
                        '$documentCount documents',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF084298)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Color(0xFF0d6efd)),
                      const SizedBox(width: 8),
                      Text(
                        '$profileCount profiles',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF084298)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Skip',
              style: TextStyle(color: Color(0xFF6c757d), fontSize: 15),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0d6efd),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Restore', style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }

  /// Perform the restore operation
  static Future<void> _performRestore(BuildContext context, String backupId) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF0d6efd)),
            SizedBox(height: 16),
            Text('Restoring your data...'),
          ],
        ),
      ),
    );

    try {
      final response = await ApiService.restoreBackup(backupId, mode: 'overwrite');
      
      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Restored successfully! ${data['profiles_restored']} profiles, ${data['documents_restored']} documents.',
              ),
              backgroundColor: const Color(0xFF198754),
              duration: const Duration(seconds: 3),
            ),
          );
          
          // Force complete app reload by clearing navigation stack and rebuilding
          // This ensures all screens (Documents, Profiles, etc.) fetch fresh data
          await Future.delayed(const Duration(seconds: 2));
          if (context.mounted) {
            // Navigate to main screen and remove all routes - this forces all screens to reinitialize
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          }
        }
      } else {
        throw Exception(response['message'] ?? 'Restore failed');
      }
    } catch (error) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $error'),
            backgroundColor: const Color(0xFFdc3545),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Reset the restore prompt flag (for testing purposes)
  static Future<void> resetRestorePrompt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pv_shown_restore_prompt');
    print('[BackupRestore] Reset restore prompt flag');
  }
}
