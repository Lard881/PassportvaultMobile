import 'package:flutter/material.dart';

class AppTheme {
  // Primary Colors - Matching web version
  static const Color primaryColor = Color(0xFF0d6efd);
  static const Color primaryHover = Color(0xFF0051D5);
  static const Color dangerColor = Color(0xFFdc3545);
  static const Color warningColor = Color(0xFFffc107);
  static const Color successColor = Color(0xFF198754);
  static const Color infoColor = Color(0xFF0d6efd);
  
  // Document Type Colors
  static const Color docPassport = Color(0xFF9333EA); // purple
  static const Color docVisa = Color(0xFF198754); // green
  static const Color docNationalId = Color(0xFF7C3AED); // violet
  static const Color docLicense = Color(0xFFf59e0b); // amber
  static const Color docBirthCert = Color(0xFFEC4899); // pink
  static const Color docOther = Color(0xFF6c757d); // muted
  
  // Status Colors
  static const Color statusActive = Color(0xFF198754);
  static const Color statusExpiring = Color(0xFFffc107);
  static const Color statusExpired = Color(0xFFdc3545);
  static const Color statusValid = Color(0xFF198754);
  
  // Light Theme Colors
  static const Color lightBgPrimary = Color(0xFFFFFFFF);
  static const Color lightBgSecondary = Color(0xFFF8F9FA);
  static const Color lightBgCard = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF212529);
  static const Color lightTextSecondary = Color(0xFF6c757d);
  static const Color lightTextMuted = Color(0xFF9ca3af);
  static const Color lightBorderColor = Color(0xFFDEE2E6);
  
  // Dark Theme Colors
  static const Color darkBgPrimary = Color(0xFF1a1a1a);
  static const Color darkBgSecondary = Color(0xFF2d2d2d);
  static const Color darkBgCard = Color(0xFF242424);
  static const Color darkTextPrimary = Color(0xFFf8f9fa);
  static const Color darkTextSecondary = Color(0xFFadb5bd);
  static const Color darkTextMuted = Color(0xFF868e96);
  static const Color darkBorderColor = Color(0xFF404040);
  
  // Border Radius
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  
  // Typography
  static const double fontSizeXs = 11.0;
  static const double fontSizeSm = 13.0;
  static const double fontSizeBase = 15.0;
  static const double fontSizeLg = 17.0;
  static const double fontSizeXl = 20.0;
  static const double fontSizeXxl = 28.0;
  
  // Light Theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: lightBgSecondary,
    cardColor: lightBgCard,
    dividerColor: lightBorderColor,
    
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: primaryColor,
      error: dangerColor,
      surface: lightBgCard,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onError: Colors.white,
      onSurface: lightTextPrimary,
    ),
    
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: fontSizeLg,
        fontWeight: FontWeight.w700,
      ),
    ),
    
    cardTheme: CardThemeData(
      color: lightBgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        side: const BorderSide(color: lightBorderColor, width: 1),
      ),
    ),
    
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: lightBgCard,
      selectedItemColor: primaryColor,
      unselectedItemColor: lightTextSecondary,
      selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightBgCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: lightBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: lightBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: dangerColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      hintStyle: const TextStyle(color: lightTextMuted),
    ),
    
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        textStyle: const TextStyle(
          fontSize: fontSizeBase,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        textStyle: const TextStyle(
          fontSize: fontSizeBase,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: fontSizeXxl, fontWeight: FontWeight.w700, color: lightTextPrimary),
      displayMedium: TextStyle(fontSize: fontSizeXl, fontWeight: FontWeight.w700, color: lightTextPrimary),
      displaySmall: TextStyle(fontSize: fontSizeLg, fontWeight: FontWeight.w600, color: lightTextPrimary),
      headlineMedium: TextStyle(fontSize: fontSizeLg, fontWeight: FontWeight.w600, color: lightTextPrimary),
      titleLarge: TextStyle(fontSize: fontSizeLg, fontWeight: FontWeight.w600, color: lightTextPrimary),
      titleMedium: TextStyle(fontSize: fontSizeBase, fontWeight: FontWeight.w600, color: lightTextPrimary),
      bodyLarge: TextStyle(fontSize: fontSizeBase, color: lightTextPrimary),
      bodyMedium: TextStyle(fontSize: fontSizeSm, color: lightTextSecondary),
      bodySmall: TextStyle(fontSize: fontSizeXs, color: lightTextMuted),
    ),
    
    snackBarTheme: SnackBarThemeData(
      backgroundColor: darkBgCard,
      contentTextStyle: const TextStyle(color: darkTextPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusSm),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
  
  // Dark Theme
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: darkBgPrimary,
    cardColor: darkBgCard,
    dividerColor: darkBorderColor,
    
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: primaryColor,
      error: dangerColor,
      surface: darkBgCard,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onError: Colors.white,
      onSurface: darkTextPrimary,
    ),
    
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: fontSizeLg,
        fontWeight: FontWeight.w700,
      ),
    ),
    
    cardTheme: CardThemeData(
      color: darkBgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        side: const BorderSide(color: darkBorderColor, width: 1),
      ),
    ),
    
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: darkBgCard,
      selectedItemColor: primaryColor,
      unselectedItemColor: darkTextSecondary,
      selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkBgSecondary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: darkBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: darkBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: dangerColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      hintStyle: const TextStyle(color: darkTextMuted),
    ),
    
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        textStyle: const TextStyle(
          fontSize: fontSizeBase,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        textStyle: const TextStyle(
          fontSize: fontSizeBase,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: fontSizeXxl, fontWeight: FontWeight.w700, color: darkTextPrimary),
      displayMedium: TextStyle(fontSize: fontSizeXl, fontWeight: FontWeight.w700, color: darkTextPrimary),
      displaySmall: TextStyle(fontSize: fontSizeLg, fontWeight: FontWeight.w600, color: darkTextPrimary),
      headlineMedium: TextStyle(fontSize: fontSizeLg, fontWeight: FontWeight.w600, color: darkTextPrimary),
      titleLarge: TextStyle(fontSize: fontSizeLg, fontWeight: FontWeight.w600, color: darkTextPrimary),
      titleMedium: TextStyle(fontSize: fontSizeBase, fontWeight: FontWeight.w600, color: darkTextPrimary),
      bodyLarge: TextStyle(fontSize: fontSizeBase, color: darkTextPrimary),
      bodyMedium: TextStyle(fontSize: fontSizeSm, color: darkTextSecondary),
      bodySmall: TextStyle(fontSize: fontSizeXs, color: darkTextMuted),
    ),
    
    snackBarTheme: SnackBarThemeData(
      backgroundColor: darkBgSecondary,
      contentTextStyle: const TextStyle(color: darkTextPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusSm),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
