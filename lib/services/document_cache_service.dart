import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Service to cache downloaded documents locally for offline access
class DocumentCacheService {
  static const String _cacheFolder = 'cached_documents';
  static const int _maxCachedDocuments = 50;

  /// Get cache directory
  static Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/$_cacheFolder');
    
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    
    return cacheDir;
  }

  /// Cache a document file
  static Future<void> cacheDocument({
    required int documentId,
    required List<int> bytes,
    required String fileName,
  }) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final file = File('${cacheDir.path}/${documentId}_$fileName');
      
      await file.writeAsBytes(bytes);
      debugPrint('💾 Document cached: $fileName (ID: $documentId)');
      
      // Clean old cache if needed
      await _cleanOldCache();
    } catch (e) {
      debugPrint('❌ Error caching document: $e');
    }
  }

  /// Get cached document file
  static Future<File?> getCachedDocument(int documentId) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final files = await cacheDir.list().toList();
      
      for (var entity in files) {
        if (entity is File && entity.path.contains('${documentId}_')) {
          if (await entity.exists()) {
            debugPrint('✅ Found cached document: ${entity.path}');
            return entity;
          }
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Error getting cached document: $e');
      return null;
    }
  }

  /// Check if document is cached
  static Future<bool> isDocumentCached(int documentId) async {
    final file = await getCachedDocument(documentId);
    return file != null;
  }

  /// Get cached document bytes
  static Future<List<int>?> getCachedDocumentBytes(int documentId) async {
    try {
      final file = await getCachedDocument(documentId);
      if (file != null) {
        return await file.readAsBytes();
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error reading cached document bytes: $e');
      return null;
    }
  }

  /// Delete cached document
  static Future<void> deleteCachedDocument(int documentId) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final files = await cacheDir.list().toList();
      
      for (var entity in files) {
        if (entity is File && entity.path.contains('${documentId}_')) {
          await entity.delete();
          debugPrint('🗑️ Deleted cached document: $documentId');
        }
      }
    } catch (e) {
      debugPrint('❌ Error deleting cached document: $e');
    }
  }

  /// Clear all cached documents
  static Future<void> clearAllCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        debugPrint('🗑️ All document cache cleared');
      }
    } catch (e) {
      debugPrint('❌ Error clearing cache: $e');
    }
  }

  /// Get total cache size in bytes
  static Future<int> getCacheSizeBytes() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (!await cacheDir.exists()) {
        return 0;
      }
      
      int totalSize = 0;
      final files = await cacheDir.list().toList();
      
      for (var entity in files.whereType<File>()) {
        totalSize += await entity.length();
      }
      
      return totalSize;
    } catch (e) {
      debugPrint('❌ Error calculating cache size: $e');
      return 0;
    }
  }

  /// Get cache size as human-readable string
  static Future<String> getCacheSizeFormatted() async {
    final bytes = await getCacheSizeBytes();
    
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  /// Get number of cached documents
  static Future<int> getCachedDocumentCount() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (!await cacheDir.exists()) {
        return 0;
      }
      
      final files = await cacheDir.list().toList();
      return files.whereType<File>().length;
    } catch (e) {
      debugPrint('❌ Error counting cached documents: $e');
      return 0;
    }
  }

  /// Clean old cache if exceeds maximum
  static Future<void> _cleanOldCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final entities = await cacheDir.list().toList();
      final files = entities.whereType<File>().toList();
      
      if (files.length > _maxCachedDocuments) {
        // Sort by last modified date (oldest first)
        files.sort((a, b) => 
          a.lastModifiedSync().compareTo(b.lastModifiedSync())
        );
        
        // Delete oldest files
        final toDelete = files.length - _maxCachedDocuments;
        for (int i = 0; i < toDelete; i++) {
          await files[i].delete();
          debugPrint('🗑️ Cleaned old cached document: ${files[i].path}');
        }
        
        debugPrint('✅ Cache cleanup complete. Deleted $toDelete old documents.');
      }
    } catch (e) {
      debugPrint('❌ Error cleaning old cache: $e');
    }
  }

  /// Get list of cached document IDs
  static Future<List<int>> getCachedDocumentIds() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final files = await cacheDir.list().toList();
      final ids = <int>[];
      
      for (var entity in files) {
        if (entity is File) {
          final fileName = entity.path.split('/').last;
          final idPart = fileName.split('_').first;
          final id = int.tryParse(idPart);
          if (id != null && !ids.contains(id)) {
            ids.add(id);
          }
        }
      }
      
      return ids;
    } catch (e) {
      debugPrint('❌ Error getting cached document IDs: $e');
      return [];
    }
  }
}
