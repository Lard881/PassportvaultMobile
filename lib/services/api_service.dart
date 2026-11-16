import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http_parser/http_parser.dart';
import '../config/app_config.dart';

class ApiService {
  static const _storage = FlutterSecureStorage();
  static const String _tokenKey = 'pv_token';
  static const String _savedEmailKey = 'pv_saved_email';
  static const String _savedPasswordKey = 'pv_saved_password';

  static dynamic _deepConvertValue(dynamic value) {
    if (value is Map) {
      // Convert any Map type (including LinkedMap) to Map<String, dynamic>
      return Map<String, dynamic>.from(
        value.map(
          (key, val) => MapEntry(key.toString(), _deepConvertValue(val)),
        ),
      );
    } else if (value is List) {
      return value.map((item) => _deepConvertValue(item)).toList();
    }
    return value;
  }

  // Get stored token
  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  // Save token
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  // Delete token
  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  static Future<void> saveRememberedCredentials(
    String email,
    String password,
  ) async {
    await _storage.write(key: _savedEmailKey, value: email);
    await _storage.write(key: _savedPasswordKey, value: password);
  }

  static Future<Map<String, String?>> getRememberedCredentials() async {
    return {
      'email': await _storage.read(key: _savedEmailKey),
      'password': await _storage.read(key: _savedPasswordKey),
    };
  }

  static Future<void> clearRememberedCredentials() async {
    await _storage.delete(key: _savedEmailKey);
    await _storage.delete(key: _savedPasswordKey);
  }

  static VoidCallback? onUnauthorized;

  // Make authenticated request
  static Future<Map<String, dynamic>> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    // DEBUG: Log every API call
    debugPrint('🔵 API CALL: $method $endpoint');

    final url = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
    final headers = {'Content-Type': 'application/json'};

    if (requiresAuth) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    http.Response response;

    try {
      final startTime = DateTime.now();

      switch (method.toUpperCase()) {
        case 'GET':
          response = await http
              .get(url, headers: headers)
              .timeout(
                const Duration(seconds: 30),
                onTimeout: () => throw Exception('Request timeout'),
              );
          break;
        case 'POST':
          response = await http
              .post(
                url,
                headers: headers,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(
                const Duration(seconds: 30),
                onTimeout: () => throw Exception('Request timeout'),
              );
          break;
        case 'PUT':
          response = await http
              .put(
                url,
                headers: headers,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(
                const Duration(seconds: 30),
                onTimeout: () => throw Exception('Request timeout'),
              );
          break;
        case 'DELETE':
          response = await http
              .delete(url, headers: headers)
              .timeout(
                const Duration(seconds: 30),
                onTimeout: () => throw Exception('Request timeout'),
              );
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      final duration = DateTime.now().difference(startTime);
      debugPrint(
        '✅ API SUCCESS: $method $endpoint (${duration.inMilliseconds}ms) - Status: ${response.statusCode}',
      );

      // Check status code
      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final decoded = jsonDecode(response.body);
          // ALWAYS deep convert to fix LinkedMap issue
          final converted = _deepConvertValue(decoded);
          if (converted is Map<String, dynamic>) {
            return converted;
          }
          return {'success': true, 'data': converted};
        } catch (e) {
          debugPrint('⚠️ JSON decode error: $e');
          // If JSON decode fails, return raw response
          return {'success': true, 'data': response.body};
        }
      } else if (response.statusCode == 404) {
        debugPrint('⚠️ API 404: $method $endpoint - Route not found');
        try {
          final error = jsonDecode(response.body);
          return {
            'success': false,
            'message': error['message'] ?? 'Route not found',
            'status': 404,
          };
        } catch (_) {
          return {
            'success': false,
            'message': 'Route not found',
            'status': 404,
          };
        }
      } else if (response.statusCode == 401) {
        debugPrint('❌ API 401: $method $endpoint - Unauthorized');
        await deleteToken();
        if (onUnauthorized != null) {
          onUnauthorized!();
        }
        return {'success': false, 'message': 'Unauthorized', 'status': 401};
      } else {
        debugPrint(
          '❌ API ERROR: $method $endpoint - Status: ${response.statusCode}',
        );
        try {
          final error = jsonDecode(response.body);
          return {
            'success': false,
            'message': error['message'] ?? 'Request failed',
            'status': response.statusCode,
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Request failed with status ${response.statusCode}',
            'status': response.statusCode,
          };
        }
      }
    } catch (e) {
      debugPrint('❌ API EXCEPTION: $method $endpoint - $e');

      // Handle specific error types for better offline detection
      if (e is SocketException) {
        return {
          'success': false,
          'offline': true,
          'message': 'No internet connection',
          'status': 0,
        };
      } else if (e is TimeoutException || e.toString().contains('timeout')) {
        return {
          'success': false,
          'timeout': true,
          'message': 'Connection timeout - Check your network',
          'status': 0,
        };
      }

      return {'success': false, 'message': 'Network error: $e', 'status': 0};
    }
  }

  // ==================== AUTH APIs ====================

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    return await _makeRequest(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
      requiresAuth: false,
    );
  }

  static Future<Map<String, dynamic>> signup(
    String fullName,
    String email,
    String password,
  ) async {
    return await _makeRequest(
      'POST',
      '/auth/signup',
      body: {'fullName': fullName, 'email': email, 'password': password},
      requiresAuth: false,
    );
  }

  static Future<Map<String, dynamic>> getCurrentUser() async {
    return await _makeRequest('GET', '/auth/me');
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    return await _makeRequest(
      'POST',
      '/auth/forgot-password',
      body: {'email': email},
      requiresAuth: false,
    );
  }

  static Future<Map<String, dynamic>> resetPassword(
    String token,
    String newPassword,
  ) async {
    return await _makeRequest(
      'POST',
      '/auth/reset-password',
      body: {'token': token, 'newPassword': newPassword},
      requiresAuth: false,
    );
  }

  static Future<Map<String, dynamic>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    return await _makeRequest(
      'POST',
      '/auth/change-password',
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  static Future<Map<String, dynamic>> logout() async {
    final response = await _makeRequest('POST', '/auth/logout');
    // Delete token regardless of response
    await deleteToken();
    return response;
  }

  static Future<Map<String, dynamic>> deleteAccount() async {
    final response = await _makeRequest('DELETE', '/auth/account');
    if (response['success'] == true) {
      await deleteToken();
    }
    return response;
  }

  // ==================== PROFILES APIs ====================

  static Future<Map<String, dynamic>> getProfiles() async {
    return await _makeRequest('GET', '/profiles');
  }

  static Future<Map<String, dynamic>> getProfile(dynamic id) async {
    return await _makeRequest('GET', '/profiles/$id');
  }

  static Future<Map<String, dynamic>> getExpiringSoonProfiles() async {
    return await _makeRequest('GET', '/profiles/expiring/soon');
  }

  static Map<String, dynamic> _mapProfileDataToSnakeCase(
    Map<String, dynamic> data,
  ) {
    return {
      'full_name': data['full_name'] ?? data['fullName'] ?? '',
      'profile_type': data['profile_type'] ?? data['profileType'] ?? 'Self',
      'document_number':
          data['document_number'] ?? data['documentNumber'] ?? '',
      'country': data['country'] ?? '',
      'nationality': data['nationality'] ?? '',
      'date_of_birth': data['date_of_birth'] ?? data['dateOfBirth'],
      'gender': data['gender'] ?? data['sex'] ?? '',
      'notes': data['notes'] ?? '',
      'tags': data['tags'] ?? [],
      'is_favorite': data['is_favorite'] ?? data['isFavorite'] ?? false,
      if (data['issue_date'] != null || data['issueDate'] != null)
        'issue_date': data['issue_date'] ?? data['issueDate'],
      if (data['expiry_date'] != null || data['expiryDate'] != null)
        'expiry_date': data['expiry_date'] ?? data['expiryDate'],
      if (data['place_of_birth'] != null || data['placeOfBirth'] != null)
        'place_of_birth': data['place_of_birth'] ?? data['placeOfBirth'],
    };
  }

  static Future<Map<String, dynamic>> createProfile(
    Map<String, dynamic> profileData,
  ) async {
    return await _makeRequest(
      'POST',
      '/profiles',
      body: _mapProfileDataToSnakeCase(profileData),
    );
  }

  static Future<Map<String, dynamic>> updateProfile(
    dynamic id,
    Map<String, dynamic> profileData,
  ) async {
    return await _makeRequest(
      'PUT',
      '/profiles/$id',
      body: _mapProfileDataToSnakeCase(profileData),
    );
  }

  static Future<Map<String, dynamic>> deleteProfile(dynamic id) async {
    return await _makeRequest('DELETE', '/profiles/$id');
  }

  // Upload profile photo
  static Future<Map<String, dynamic>> uploadProfilePhoto(
    dynamic profileId,
    File photoFile,
  ) async {
    final token = await getToken();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/profiles/upload-photo');

    var request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['profile_id'] = profileId.toString();

    final fileExtension = photoFile.path.split('.').last.toLowerCase();
    request.files.add(
      await http.MultipartFile.fromPath(
        'photo',
        photoFile.path,
        contentType: MediaType(
          'image',
          fileExtension == 'png'
              ? 'png'
              : fileExtension == 'gif'
              ? 'gif'
              : 'jpeg',
        ),
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      try {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Photo upload failed');
      } catch (e) {
        throw Exception('Photo upload failed: ${response.statusCode}');
      }
    }
  }

  // Upload profile with optional photo
  static Future<Map<String, dynamic>> uploadProfile(
    Map<String, dynamic> profileData,
    File? photoFile,
  ) async {
    final res = await createProfile(profileData);
    if (res['success'] == true && photoFile != null) {
      final profileId = res['data']?['id'];
      if (profileId != null) {
        try {
          final photoRes = await uploadProfilePhoto(profileId, photoFile);
          if (photoRes['data']?['photo_url'] != null) {
            res['data']['photo_url'] = photoRes['data']['photo_url'];
          }
        } catch (e) {
          debugPrint('Profile created but photo upload failed: $e');
        }
      }
    }
    return res;
  }

  // Update profile with optional photo
  static Future<Map<String, dynamic>> updateProfileWithPhoto(
    dynamic id,
    Map<String, dynamic> profileData,
    File? photoFile,
  ) async {
    if (photoFile != null) {
      try {
        final photoRes = await uploadProfilePhoto(id, photoFile);
        if (photoRes['data'] != null && photoRes['data']['photo_url'] != null) {
          profileData['photo_url'] = photoRes['data']['photo_url'];
        }
      } catch (e) {
        debugPrint('Photo upload failed during profile update: $e');
      }
    }
    return await updateProfile(id, profileData);
  }

  // ==================== DOCUMENTS APIs ====================

  static Future<Map<String, dynamic>> getDocuments({dynamic profileId}) async {
    String endpoint = '/documents';
    if (profileId != null) {
      endpoint += '?profile_id=$profileId';
    }
    return await _makeRequest('GET', endpoint);
  }

  static Future<Map<String, dynamic>> getDocument(dynamic id) async {
    return await _makeRequest('GET', '/documents/$id');
  }

  static Future<Map<String, dynamic>> deleteDocument(dynamic id) async {
    return await _makeRequest('DELETE', '/documents/$id');
  }

  // Upload document with file
  static Future<Map<String, dynamic>> uploadDocument(
    Map<String, dynamic> documentData,
    File documentFile,
  ) async {
    final token = await getToken();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/documents/upload');

    var request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';

    // Add document data as fields, mapping common variations to backend format
    final fields = <String, String>{};
    documentData.forEach((key, value) {
      if (value != null && key != 'documentFile') {
        fields[key] = value.toString();
      }
    });

    if (documentData.containsKey('documentName') &&
        !fields.containsKey('document_name')) {
      fields['document_name'] = documentData['documentName'].toString();
    }
    if (documentData.containsKey('profile') &&
        !fields.containsKey('profile_id')) {
      fields['profile_id'] = documentData['profile'].toString();
    }
    if (documentData.containsKey('documentNumber') &&
        !fields.containsKey('document_number')) {
      fields['document_number'] = documentData['documentNumber'].toString();
    }
    if (documentData.containsKey('dateOfIssue') &&
        !fields.containsKey('issue_date')) {
      fields['issue_date'] = documentData['dateOfIssue'].toString();
    }
    if (documentData.containsKey('dateOfExpiry') &&
        !fields.containsKey('expiry_date')) {
      fields['expiry_date'] = documentData['dateOfExpiry'].toString();
    }
    if (documentData.containsKey('notes') &&
        !fields.containsKey('description')) {
      fields['description'] = documentData['notes'].toString();
    }

    request.fields.addAll(fields);

    // Add document file
    final fileExtension = documentFile.path.split('.').last.toLowerCase();
    String mimeType;

    switch (fileExtension) {
      case 'pdf':
        mimeType = 'application/pdf';
        break;
      case 'png':
        mimeType = 'image/png';
        break;
      case 'jpg':
      case 'jpeg':
        mimeType = 'image/jpeg';
        break;
      default:
        mimeType = 'application/octet-stream';
    }

    // Backend expects 'file' via upload.single('file')
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        documentFile.path,
        contentType: MediaType.parse(mimeType),
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Upload failed');
    }
  }

  // Update document metadata (without file)
  static Future<Map<String, dynamic>> updateDocument(
    dynamic id,
    Map<String, dynamic> documentData,
  ) async {
    final mappedData = <String, dynamic>{
      'document_name':
          documentData['document_name'] ?? documentData['documentName'],
      'description': documentData['description'] ?? documentData['notes'],
      'profile_id': documentData['profile_id'] ?? documentData['profile'],
      'document_number':
          documentData['document_number'] ?? documentData['documentNumber'],
      'issue_date': documentData['issue_date'] ?? documentData['dateOfIssue'],
      'expiry_date':
          documentData['expiry_date'] ?? documentData['dateOfExpiry'],
      if (documentData.containsKey('tags')) 'tags': documentData['tags'],
    };
    return await _makeRequest('PUT', '/documents/$id', body: mappedData);
  }

  // Download document
  static Future<List<int>> downloadDocument(dynamic id) async {
    final token = await getToken();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/documents/$id/download');

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    } else {
      throw Exception('Download failed');
    }
  }

  static Future<Map<String, dynamic>> getDocumentSignedUrl(dynamic id) async {
    return await _makeRequest('GET', '/documents/$id/signed-url');
  }

  // Export all documents
  static Future<List<int>> exportAllDocuments() async {
    final token = await getToken();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/documents/export');

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    } else {
      throw Exception('Export failed');
    }
  }

  // ==================== NOTIFICATIONS APIs ====================

  static Future<Map<String, dynamic>> getNotifications() async {
    return await _makeRequest('GET', '/notifications');
  }

  static Future<Map<String, dynamic>> getUnreadNotificationsCount() async {
    return await _makeRequest('GET', '/notifications/unread/count');
  }

  static Future<Map<String, dynamic>> markNotificationAsRead(dynamic id) async {
    return await _makeRequest('PUT', '/notifications/$id/read');
  }

  static Future<Map<String, dynamic>> deleteNotification(dynamic id) async {
    return await _makeRequest('DELETE', '/notifications/$id');
  }

  static Future<Map<String, dynamic>> markAllNotificationsAsRead() async {
    return await _makeRequest('PUT', '/notifications/read-all');
  }

  static Future<Map<String, dynamic>> triggerExpiryCheck() async {
    return await _makeRequest('POST', '/notifications/trigger-expiry-check');
  }

  static Future<Map<String, dynamic>> triggerWeeklyDigest() async {
    return await _makeRequest('POST', '/notifications/trigger-weekly-digest');
  }

  // ==================== ACTIVITY LOG APIs ====================

  static Future<Map<String, dynamic>> getActivityLog({
    String? filter,
    String? startDate,
    String? endDate,
  }) async {
    String endpoint = '/activity';
    final params = <String>[];

    if (filter != null && filter.isNotEmpty) {
      params.add('action_type=$filter');
    }
    if (startDate != null && startDate.isNotEmpty) {
      params.add('start_date=$startDate');
    }
    if (endDate != null && endDate.isNotEmpty) {
      params.add('end_date=$endDate');
    }

    if (params.isNotEmpty) {
      endpoint += '?${params.join('&')}';
    }

    return await _makeRequest('GET', endpoint);
  }

  static Future<Map<String, dynamic>> getActivityStats() async {
    return await _makeRequest('GET', '/activity/stats');
  }

  static Future<Map<String, dynamic>> clearActivityLog(int daysOld) async {
    return await _makeRequest('DELETE', '/activity?days_old=$daysOld');
  }

  // ==================== SETTINGS APIs ====================

  static Future<Map<String, dynamic>> getSettings() async {
    return await _makeRequest('GET', '/settings');
  }

  static Future<Map<String, dynamic>> updateEmailNotifications(
    bool enabled,
  ) async {
    return await _makeRequest(
      'PUT',
      '/settings',
      body: {'email_notifications': enabled},
    );
  }

  static Future<Map<String, dynamic>> updateSettings(
    Map<String, dynamic> settings,
  ) async {
    const settingAliases = {
      'push_notifications': 'pushNotifications',
      'expiry_reminders': 'expiryReminders',
      'auto_backup': 'autoBackup',
      'biometric_auth': 'biometricAuth',
      'biometric_method': 'biometricMethod',
      'language': 'language',
    };
    final payload = <String, dynamic>{};
    for (final entry in settingAliases.entries) {
      if (settings.containsKey(entry.key)) {
        payload[entry.key] = settings[entry.key];
      } else if (settings.containsKey(entry.value)) {
        payload[entry.key] = settings[entry.value];
      }
    }

    if (payload.isEmpty) {
      throw ArgumentError('At least one supported setting is required.');
    }

    final response = await _makeRequest('PUT', '/settings', body: payload);
    if (response['success'] == true) return response;
    return {'success': true, 'message': 'Settings updated locally'};
  }

  // User Profile - Get current user's profile with notification settings
  static Future<Map<String, dynamic>> getUserProfile() async {
    return await getCurrentUser();
  }

  // User Profile - Update current user's profile (including notification settings)
  static Future<Map<String, dynamic>> updateUserProfile(
    Map<String, dynamic> profileData,
  ) async {
    return await _makeRequest('PUT', '/auth/profile', body: profileData);
  }

  static Future<Map<String, dynamic>> getStorageStats() async {
    final res = await _makeRequest('GET', '/settings/storage');
    if (res['success'] == true && res['data'] != null) return res;
    return {
      'success': true,
      'data': {'used': 0, 'total': 104857600},
    };
  }

  // ==================== BACKUP APIs ====================

  static Future<Map<String, dynamic>> getBackups() async {
    return await _makeRequest('GET', '/backups');
  }

  static Future<Map<String, dynamic>> getLatestBackup() async {
    final res = await _makeRequest('GET', '/backups/latest');
    if (res['success'] == true) return res;
    if (res['status'] == 404 && res['message'] == 'No backup found') {
      return {'success': true, 'data': null};
    }
    return res;
  }

  static Future<Map<String, dynamic>> createBackup({
    String type = 'manual',
  }) async {
    return await _makeRequest('POST', '/backups/create', body: {'type': type});
  }

  static Future<Map<String, dynamic>> restoreBackup(
    dynamic backupId, {
    String mode = 'overwrite',
  }) async {
    return await _makeRequest(
      'POST',
      '/backups/$backupId/restore',
      body: {'restore_mode': mode, 'mode': mode},
    );
  }

  static Future<Map<String, dynamic>> deleteBackup(dynamic backupId) async {
    return await _makeRequest('DELETE', '/backups/$backupId');
  }

  // ==================== SHARES APIs ====================

  static Future<Map<String, dynamic>> getAllShares() async {
    return await _makeRequest('GET', '/shares');
  }

  static Future<Map<String, dynamic>> createShare(
    Map<String, dynamic> shareData,
  ) async {
    return await _makeRequest('POST', '/shares', body: shareData);
  }

  static Future<Map<String, dynamic>> revokeShare(dynamic shareId) async {
    return await _makeRequest('PUT', '/shares/$shareId/revoke');
  }

  static Future<Map<String, dynamic>> deleteShare(dynamic shareId) async {
    return await _makeRequest('DELETE', '/shares/$shareId');
  }

  static Future<Map<String, dynamic>> getPublicShare(String token) async {
    return await _makeRequest(
      'GET',
      '/shares/public/$token',
      requiresAuth: false,
    );
  }

  static Future<Map<String, dynamic>> accessPublicShare(
    String token, {
    String? password,
  }) async {
    return await _makeRequest(
      'POST',
      '/shares/public/$token/access',
      body: password != null ? {'password': password} : {},
      requiresAuth: false,
    );
  }

  // ==================== SUPPORT APIs ====================

  static Future<Map<String, dynamic>> submitSupportRequest(
    Map<String, dynamic> supportData,
  ) async {
    return await _makeRequest('POST', '/support/contact', body: supportData);
  }
}
