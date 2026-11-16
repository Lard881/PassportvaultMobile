import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// CacheService manages offline local caching for documents and profiles
/// to provide instant 0ms screen loading (Hybrid App Architecture).
/// Now includes TTL (time-to-live) and stale-while-revalidate pattern.
class CacheService {
  static const String _docsCacheKey = 'pv_cached_documents';
  static const String _profilesCacheKey = 'pv_cached_profiles';
  static const String _notificationsCacheKey = 'pv_cached_notifications';
  static const String _syncQueueKey = 'pv_pending_sync_queue';
  
  // Timestamp keys for TTL tracking
  static const String _docsTimestampKey = 'pv_docs_timestamp';
  static const String _profilesTimestampKey = 'pv_profiles_timestamp';
  static const String _notificationsTimestampKey = 'pv_notifications_timestamp';
  
  // Cache TTL: 5 minutes (same as web)
  static const Duration cacheTTL = Duration(minutes: 5);

  /// Save list of documents to local cache with timestamp
  static Future<void> saveDocumentsCache(List<dynamic> docs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(docs);
      await prefs.setString(_docsCacheKey, jsonString);
      await prefs.setInt(_docsTimestampKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('💾 Documents cached: ${docs.length} items');
    } catch (e) {
      debugPrint('Error saving documents cache: $e');
    }
  }

  /// Read list of documents from local cache (0ms instant access)
  static Future<List<dynamic>> getDocumentsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_docsCacheKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final decoded = jsonDecode(jsonString);
        if (decoded is List) {
          return decoded;
        }
      }
    } catch (e) {
      debugPrint('Error reading documents cache: $e');
    }
    return [];
  }
  
  /// Check if documents cache is stale (older than TTL)
  static Future<bool> isDocumentsCacheStale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_docsTimestampKey);
      if (timestamp == null) return true;
      
      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      final isStale = cacheAge > cacheTTL.inMilliseconds;
      
      if (isStale) {
        debugPrint('⏰ Documents cache is stale (${Duration(milliseconds: cacheAge).inMinutes} minutes old)');
      }
      
      return isStale;
    } catch (e) {
      debugPrint('Error checking documents cache age: $e');
      return true;
    }
  }

  /// Save list of profiles to local cache with timestamp
  static Future<void> saveProfilesCache(List<dynamic> profiles) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(profiles);
      await prefs.setString(_profilesCacheKey, jsonString);
      await prefs.setInt(_profilesTimestampKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('💾 Profiles cached: ${profiles.length} items');
    } catch (e) {
      debugPrint('Error saving profiles cache: $e');
    }
  }

  /// Read list of profiles from local cache (0ms instant access)
  static Future<List<dynamic>> getProfilesCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_profilesCacheKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final decoded = jsonDecode(jsonString);
        if (decoded is List) {
          return decoded;
        }
      }
    } catch (e) {
      debugPrint('Error reading profiles cache: $e');
    }
    return [];
  }
  
  /// Check if profiles cache is stale (older than TTL)
  static Future<bool> isProfilesCacheStale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_profilesTimestampKey);
      if (timestamp == null) return true;
      
      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      return cacheAge > cacheTTL.inMilliseconds;
    } catch (e) {
      debugPrint('Error checking profiles cache age: $e');
      return true;
    }
  }
  
  /// Save list of notifications to local cache with timestamp
  static Future<void> saveNotificationsCache(List<dynamic> notifications) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(notifications);
      await prefs.setString(_notificationsCacheKey, jsonString);
      await prefs.setInt(_notificationsTimestampKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('💾 Notifications cached: ${notifications.length} items');
    } catch (e) {
      debugPrint('Error saving notifications cache: $e');
    }
  }

  /// Read list of notifications from local cache
  static Future<List<dynamic>> getNotificationsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_notificationsCacheKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final decoded = jsonDecode(jsonString);
        if (decoded is List) {
          return decoded;
        }
      }
    } catch (e) {
      debugPrint('Error reading notifications cache: $e');
    }
    return [];
  }
  
  /// Check if notifications cache is stale (older than TTL)
  static Future<bool> isNotificationsCacheStale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_notificationsTimestampKey);
      if (timestamp == null) return true;
      
      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      return cacheAge > cacheTTL.inMilliseconds;
    } catch (e) {
      debugPrint('Error checking notifications cache age: $e');
      return true;
    }
  }

  /// Optimistically remove a document from local cache
  static Future<List<dynamic>> removeDocumentFromCache(dynamic id) async {
    final docs = await getDocumentsCache();
    docs.removeWhere((doc) => doc['id']?.toString() == id?.toString());
    await saveDocumentsCache(docs);
    return docs;
  }

  /// Optimistically remove a profile from local cache
  static Future<List<dynamic>> removeProfileFromCache(dynamic id) async {
    final profiles = await getProfilesCache();
    profiles.removeWhere((p) => p['id']?.toString() == id?.toString());
    await saveProfilesCache(profiles);
    return profiles;
  }

  /// Add a pending action to sync queue when offline
  static Future<void> queuePendingAction(Map<String, dynamic> action) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_syncQueueKey);
      List<dynamic> queue = [];
      if (queueJson != null && queueJson.isNotEmpty) {
        queue = jsonDecode(queueJson);
      }
      
      // Add timestamp if not present
      if (!action.containsKey('timestamp')) {
        action['timestamp'] = DateTime.now().toIso8601String();
      }
      
      queue.add(action);
      await prefs.setString(_syncQueueKey, jsonEncode(queue));
      debugPrint('📥 Action queued for sync: ${action['type']}');
    } catch (e) {
      debugPrint('Error queueing pending action: $e');
    }
  }

  /// Get all pending actions from sync queue
  static Future<List<dynamic>> getPendingActions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_syncQueueKey);
      if (queueJson != null && queueJson.isNotEmpty) {
        return jsonDecode(queueJson);
      }
      return [];
    } catch (e) {
      debugPrint('Error getting pending actions: $e');
      return [];
    }
  }

  /// Remove a specific action from sync queue
  static Future<void> removePendingAction(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_syncQueueKey);
      if (queueJson != null) {
        List<dynamic> queue = jsonDecode(queueJson);
        if (index >= 0 && index < queue.length) {
          queue.removeAt(index);
          await prefs.setString(_syncQueueKey, jsonEncode(queue));
          debugPrint('✅ Removed action from sync queue at index $index');
        }
      }
    } catch (e) {
      debugPrint('Error removing pending action: $e');
    }
  }

  /// Clear the entire sync queue
  static Future<void> clearSyncQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_syncQueueKey);
      debugPrint('✅ Sync queue cleared');
    } catch (e) {
      debugPrint('Error clearing sync queue: $e');
    }
  }

  /// Get count of pending actions
  static Future<int> getPendingActionCount() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_syncQueueKey);
    if (queueJson == null || queueJson.isEmpty) {
      return 0;
    }

    final actions = jsonDecode(queueJson);
    if (actions is! List) {
      throw const FormatException('Pending sync queue is not a list');
    }
    return actions.length;
  }

  /// Clear all cache (e.g. on logout)
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_docsCacheKey);
      await prefs.remove(_profilesCacheKey);
      await prefs.remove(_notificationsCacheKey);
      await prefs.remove(_syncQueueKey);
      await prefs.remove(_docsTimestampKey);
      await prefs.remove(_profilesTimestampKey);
      await prefs.remove(_notificationsTimestampKey);
      debugPrint('🗑️ All cache cleared');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }
}
