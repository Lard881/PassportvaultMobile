import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// CacheService manages offline local caching for documents and profiles
/// to provide instant 0ms screen loading (Hybrid App Architecture).
class CacheService {
  static const String _docsCacheKey = 'pv_cached_documents';
  static const String _profilesCacheKey = 'pv_cached_profiles';
  static const String _syncQueueKey = 'pv_pending_sync_queue';

  /// Save list of documents to local cache
  static Future<void> saveDocumentsCache(List<dynamic> docs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(docs);
      await prefs.setString(_docsCacheKey, jsonString);
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

  /// Save list of profiles to local cache
  static Future<void> saveProfilesCache(List<dynamic> profiles) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(profiles);
      await prefs.setString(_profilesCacheKey, jsonString);
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
    final actions = await getPendingActions();
    return actions.length;
  }

  /// Clear all cache (e.g. on logout)
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_docsCacheKey);
      await prefs.remove(_profilesCacheKey);
      await prefs.remove(_syncQueueKey);
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }
}
