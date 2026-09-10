/// Type conversion helpers to handle API data safely
class TypeHelpers {
  /// Safely convert dynamic to int
  static int? toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    if (value is double) return value.toInt();
    return null;
  }

  /// Safely convert dynamic to String
  static String? toStr(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  /// Safely convert dynamic to bool
  static bool toBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    return defaultValue;
  }

  /// Safely convert dynamic to double
  static double? toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  /// Safely convert Map from API (handles LinkedMap)
  static Map<String, dynamic> toMap(dynamic value) {
    if (value == null) return {};
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return {};
  }

  /// Safely convert List from API
  static List<dynamic> toList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value;
    return [];
  }

  /// Safely get nested value from Map
  static T? getNestedValue<T>(Map<String, dynamic>? map, String key, {T? defaultValue}) {
    if (map == null) return defaultValue;
    final value = map[key];
    if (value is T) return value;
    return defaultValue;
  }

  /// Construct full image URL for photo endpoints
  static String getFullImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    const baseUrl = 'https://passportvault-backend.onrender.com';
    if (url.startsWith('/')) return '$baseUrl$url';
    return '$baseUrl/$url';
  }
}
