import 'package:flutter/material.dart';

/// Responsive utility class for handling different screen sizes
/// Breakpoints based on Material Design guidelines
class Responsive {
  /// Check if device is a small phone (< 375px width)
  static bool isSmallPhone(BuildContext context) {
    return MediaQuery.of(context).size.width < 375;
  }

  /// Check if device is a phone (< 600px width)
  static bool isPhone(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  /// Check if device is a tablet (600px - 1200px width)
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 1200;
  }

  /// Check if device is a large tablet/desktop (>= 1200px width)
  static bool isLargeTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1200;
  }

  /// Check if device is in landscape orientation
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Check if device is in portrait orientation
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  /// Get number of grid columns based on screen size
  static int getGridColumns(BuildContext context, {int? phone, int? tablet, int? largeTablet}) {
    if (isLargeTablet(context)) {
      return largeTablet ?? 4;
    } else if (isTablet(context)) {
      return tablet ?? 3;
    } else {
      return phone ?? 2;
    }
  }

  /// Get responsive padding based on screen size
  static double getPadding(BuildContext context, {double? phone, double? tablet}) {
    if (isTablet(context) || isLargeTablet(context)) {
      return tablet ?? 20.0;
    } else {
      return phone ?? 16.0;
    }
  }

  /// Get responsive font size
  static double getFontSize(BuildContext context, double baseSize) {
    if (isLargeTablet(context)) {
      return baseSize * 1.2;
    } else if (isTablet(context)) {
      return baseSize * 1.1;
    } else {
      return baseSize;
    }
  }

  /// Get responsive card height
  static double getCardHeight(BuildContext context, {double? phone, double? tablet}) {
    if (isTablet(context) || isLargeTablet(context)) {
      return tablet ?? 200.0;
    } else {
      return phone ?? 150.0;
    }
  }

  /// Get responsive icon size
  static double getIconSize(BuildContext context, double baseSize) {
    if (isLargeTablet(context)) {
      return baseSize * 1.3;
    } else if (isTablet(context)) {
      return baseSize * 1.15;
    } else {
      return baseSize;
    }
  }

  /// Get responsive spacing
  static double getSpacing(BuildContext context, double baseSpacing) {
    if (isLargeTablet(context)) {
      return baseSpacing * 1.5;
    } else if (isTablet(context)) {
      return baseSpacing * 1.25;
    } else {
      return baseSpacing;
    }
  }

  /// Get max content width for centered layouts
  static double getMaxContentWidth(BuildContext context) {
    if (isLargeTablet(context)) {
      return 1200;
    } else if (isTablet(context)) {
      return 900;
    } else {
      return double.infinity;
    }
  }

  /// Get crossAxisCount for GridView based on screen size and orientation
  static int getCrossAxisCount(BuildContext context, {int phonePortrait = 2, int phoneLandscape = 3, int tabletPortrait = 3, int tabletLandscape = 4}) {
    final isTabletDevice = isTablet(context) || isLargeTablet(context);
    final isLandscapeMode = isLandscape(context);

    if (isTabletDevice) {
      return isLandscapeMode ? tabletLandscape : tabletPortrait;
    } else {
      return isLandscapeMode ? phoneLandscape : phonePortrait;
    }
  }

  /// Get responsive dialog width
  static double getDialogWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (isLargeTablet(context)) {
      return 600;
    } else if (isTablet(context)) {
      return 500;
    } else {
      return screenWidth * 0.9;
    }
  }

  /// Check if should show side-by-side layout (for settings, forms, etc.)
  static bool shouldShowSideBySide(BuildContext context) {
    return (isTablet(context) || isLargeTablet(context)) && isLandscape(context);
  }

  /// Get responsive bottom sheet height
  static double getBottomSheetHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    if (isTablet(context) || isLargeTablet(context)) {
      return screenHeight * 0.7;
    } else {
      return screenHeight * 0.9;
    }
  }
}
