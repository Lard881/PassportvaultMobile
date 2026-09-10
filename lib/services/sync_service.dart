import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'cache_service.dart';
import 'connectivity_service.dart';

/// Service to handle syncing of offline changes when connection is restored
class SyncService {
  static bool _isSyncing = false;

  /// Process all pending actions in the sync queue
  static Future<Map<String, dynamic>> processSyncQueue() async {
    if (_isSyncing) {
      debugPrint('⏸️ Sync already in progress, skipping...');
      return {
        'success': false,
        'message': 'Sync already in progress',
      };
    }

    // Check connectivity first
    final isOnline = await ConnectivityService.hasInternetConnection();
    if (!isOnline) {
      debugPrint('❌ Cannot sync - No internet connection');
      return {
        'success': false,
        'message': 'No internet connection',
      };
    }

    _isSyncing = true;
    debugPrint('🔄 Starting sync process...');

    try {
      final pendingActions = await CacheService.getPendingActions();
      
      if (pendingActions.isEmpty) {
        debugPrint('✅ Nothing to sync');
        _isSyncing = false;
        return {
          'success': true,
          'message': 'Nothing to sync',
          'synced': 0,
        };
      }

      int successCount = 0;
      int failedCount = 0;
      final List<String> errors = [];

      for (int i = 0; i < pendingActions.length; i++) {
        final action = pendingActions[i];
        debugPrint('🔄 Processing action ${i + 1}/${pendingActions.length}: ${action['type']}');

        try {
          final result = await _processAction(action);
          
          if (result['success'] == true) {
            successCount++;
            // Remove successfully synced action
            await CacheService.removePendingAction(i);
            debugPrint('✅ Action synced successfully: ${action['type']}');
          } else {
            failedCount++;
            errors.add(result['message'] ?? 'Unknown error');
            debugPrint('❌ Failed to sync action: ${action['type']} - ${result['message']}');
          }
        } catch (e) {
          failedCount++;
          errors.add(e.toString());
          debugPrint('❌ Exception syncing action: ${action['type']} - $e');
        }
      }

      _isSyncing = false;

      final message = successCount > 0
          ? 'Synced $successCount action${successCount > 1 ? 's' : ''}'
          : 'No actions were synced';

      return {
        'success': successCount > 0,
        'message': message,
        'synced': successCount,
        'failed': failedCount,
        'errors': errors,
      };
    } catch (e) {
      _isSyncing = false;
      debugPrint('❌ Sync process error: $e');
      return {
        'success': false,
        'message': 'Sync process error: $e',
      };
    }
  }

  /// Process a single action
  static Future<Map<String, dynamic>> _processAction(Map<String, dynamic> action) async {
    final type = action['type'];
    final data = action['data'];

    switch (type) {
      case 'create_profile':
        return await ApiService.uploadProfile(data, data['photoFile']);
      
      case 'edit_profile':
        return await ApiService.updateProfile(data['id'], data);
      
      case 'delete_profile':
        return await ApiService.deleteProfile(data['id']);
      
      case 'create_document':
        return await ApiService.uploadDocument(data, data['documentFile']);
      
      case 'edit_document':
        return await ApiService.updateDocument(data['id'], data);
      
      case 'delete_document':
        return await ApiService.deleteDocument(data['id']);
      
      default:
        return {
          'success': false,
          'message': 'Unknown action type: $type',
        };
    }
  }

  /// Check if sync is in progress
  static bool get isSyncing => _isSyncing;

  /// Get pending sync count
  static Future<int> getPendingSyncCount() async {
    return await CacheService.getPendingActionCount();
  }
}
