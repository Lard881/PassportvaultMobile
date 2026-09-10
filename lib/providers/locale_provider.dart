import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_translations.dart';

class LocaleProvider extends ChangeNotifier {
  static const String _localeKey = 'passportvault_locale';
  
  Locale _locale = const Locale('en', 'US');
  bool _isLoading = true;

  Locale get locale => _locale;
  bool get isLoading => _isLoading;
  String get languageCode => _locale.languageCode;
  
  // Supported languages matching dropdown and web version
  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'en', 'name': 'English', 'flag': '🇺🇸'},
    {'code': 'es', 'name': 'Spanish', 'flag': '🇪🇸'},
    {'code': 'fr', 'name': 'French', 'flag': '🇫🇷'},
    {'code': 'de', 'name': 'German', 'flag': '🇩🇪'},
    {'code': 'zh', 'name': 'Chinese', 'flag': '🇨🇳'},
    {'code': 'ar', 'name': 'Arabic', 'flag': '🇸🇦'},
    {'code': 'ko', 'name': 'Korean', 'flag': '🇰🇷'},
  ];

  LocaleProvider() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLocale = prefs.getString(_localeKey);
      
      if (savedLocale != null) {
        _locale = Locale(_mapToCode(savedLocale));
      }
    } catch (e) {
      debugPrint('Error loading locale: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  static String _mapToCode(String input) {
    final lower = input.toLowerCase();
    if (lower == 'english' || lower == 'en') return 'en';
    if (lower == 'spanish' || lower == 'es' || lower == 'español') return 'es';
    if (lower == 'french' || lower == 'fr' || lower == 'français') return 'fr';
    if (lower == 'german' || lower == 'de' || lower == 'deutsch') return 'de';
    if (lower == 'chinese' || lower == 'zh') return 'zh';
    if (lower == 'arabic' || lower == 'ar') return 'ar';
    if (lower == 'korean' || lower == 'ko' || lower == '한국어') return 'ko';
    return 'en';
  }

  static String _mapToName(String code) {
    switch (code) {
      case 'es': return 'Spanish';
      case 'fr': return 'French';
      case 'de': return 'German';
      case 'zh': return 'Chinese';
      case 'ar': return 'Arabic';
      case 'ko': return 'Korean';
      default: return 'English';
    }
  }

  String get currentLanguageName => _mapToName(_locale.languageCode);

  Future<void> setLocale(String languageOrCode) async {
    final code = _mapToCode(languageOrCode);
    if (_locale.languageCode == code) return;
    
    _locale = Locale(code);
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, code);
    } catch (e) {
      debugPrint('Error saving locale: $e');
    }
  }

  String tr(String key) {
    return AppTranslations.get(key, _locale.languageCode);
  }

  String getLanguageName(String code) {
    final language = supportedLanguages.firstWhere(
      (lang) => lang['code'] == code,
      orElse: () => supportedLanguages[0],
    );
    return language['name']!;
  }
}
