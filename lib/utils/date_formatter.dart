import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

/// Centralized date formatting utility with safe error handling
/// Prevents crashes from invalid date strings across all platforms
class DateFormatter {
  /// Format date as "MMM dd, yyyy" (e.g., "Jan 15, 2024")
  /// Returns 'N/A' if date is invalid or empty
  static String formatShortDate(dynamic date) {
    if (date == null || date.toString().isEmpty) return 'N/A';
    
    try {
      final dt = DateTime.parse(date.toString());
      final formatter = DateFormat('MMM dd, yyyy');
      return formatter.format(dt);
    } catch (e) {
      debugPrint('⚠️ Date format error (formatShortDate): $e for value: $date');
      return 'N/A';
    }
  }
  
  /// Format date as "dd/MM/yyyy" (e.g., "15/01/2024")
  /// Returns 'N/A' if date is invalid or empty
  static String formatSlashDate(dynamic date) {
    if (date == null || date.toString().isEmpty) return 'N/A';
    
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (e) {
      debugPrint('⚠️ Date format error (formatSlashDate): $e for value: $date');
      return 'N/A';
    }
  }
  
  /// Format date with time as "MM/dd/yyyy HH:mm" (e.g., "01/15/2024 14:30")
  /// Returns 'N/A' if date is invalid or empty
  static String formatDateTime(dynamic date) {
    if (date == null || date.toString().isEmpty) return 'N/A';
    
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.month}/${dt.day}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      debugPrint('⚠️ Date format error (formatDateTime): $e for value: $date');
      return 'N/A';
    }
  }
  
  /// Format date as "EEEE, MMMM dd, yyyy" (e.g., "Monday, January 15, 2024")
  /// Returns 'N/A' if date is invalid or empty
  static String formatLongDate(dynamic date) {
    if (date == null || date.toString().isEmpty) return 'N/A';
    
    try {
      final dt = DateTime.parse(date.toString());
      final formatter = DateFormat('EEEE, MMMM dd, yyyy');
      return formatter.format(dt);
    } catch (e) {
      debugPrint('⚠️ Date format error (formatLongDate): $e for value: $date');
      return 'N/A';
    }
  }
  
  /// Format date as relative time (e.g., "2 days ago", "Just now")
  /// Returns 'N/A' if date is invalid or empty
  static String formatRelativeTime(dynamic date) {
    if (date == null || date.toString().isEmpty) return 'N/A';
    
    try {
      final dt = DateTime.parse(date.toString());
      final now = DateTime.now();
      final difference = now.difference(dt);
      
      if (difference.inDays > 365) {
        final years = (difference.inDays / 365).floor();
        return '$years ${years == 1 ? 'year' : 'years'} ago';
      } else if (difference.inDays > 30) {
        final months = (difference.inDays / 30).floor();
        return '$months ${months == 1 ? 'month' : 'months'} ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      debugPrint('⚠️ Date format error (formatRelativeTime): $e for value: $date');
      return 'N/A';
    }
  }
  
  /// Calculate days until expiry
  /// Returns negative number if already expired
  /// Returns null if date is invalid
  static int? daysUntilExpiry(dynamic expiryDate) {
    if (expiryDate == null || expiryDate.toString().isEmpty) return null;
    
    try {
      final expiry = DateTime.parse(expiryDate.toString());
      final now = DateTime.now();
      return expiry.difference(now).inDays;
    } catch (e) {
      debugPrint('⚠️ Date format error (daysUntilExpiry): $e for value: $expiryDate');
      return null;
    }
  }
  
  /// Check if date is valid and parseable
  static bool isValidDate(dynamic date) {
    if (date == null || date.toString().isEmpty) return false;
    
    try {
      DateTime.parse(date.toString());
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Format ISO date string to user-friendly format
  /// Automatically detects best format based on whether time is included
  static String formatAuto(dynamic date) {
    if (date == null || date.toString().isEmpty) return 'N/A';
    
    try {
      final dt = DateTime.parse(date.toString());
      
      // If time is midnight (00:00:00), show date only
      if (dt.hour == 0 && dt.minute == 0 && dt.second == 0) {
        return formatShortDate(date);
      } else {
        return formatDateTime(date);
      }
    } catch (e) {
      debugPrint('⚠️ Date format error (formatAuto): $e for value: $date');
      return 'N/A';
    }
  }
}
