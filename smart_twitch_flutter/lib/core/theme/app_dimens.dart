/// Single Source of Truth for layout dimension constants.
///
/// This class contains all standard spacing, sizing, and layout values.
/// Use these instead of hardcoded "magic numbers" throughout the app.
///
/// Naming convention:
/// - padding* : Internal spacing within components
/// - margin* : External spacing between components
/// - radius* : Border radius values
/// - icon* : Icon sizes
/// - *Height/*Width : Fixed dimension values
///
/// Usage:
/// ```dart
/// import 'package:smart_twitch_flutter/core/theme/app_dimens.dart';
/// Padding(padding: EdgeInsets.all(AppDimens.paddingMedium))
/// ```
abstract final class AppDimens {
  // Prevent instantiation
  AppDimens._();

  // ============================================================
  // Standard Padding Scale (8pt grid system)
  // ============================================================

  /// Extra small padding: 4.0
  static const double paddingXSmall = 4.0;

  /// Small padding: 8.0
  static const double paddingSmall = 8.0;

  /// Medium padding: 16.0
  static const double paddingMedium = 16.0;

  /// Large padding: 24.0
  static const double paddingLarge = 24.0;

  /// Extra large padding: 32.0
  static const double paddingXLarge = 32.0;

  /// XXL padding: 48.0
  static const double paddingXXLarge = 48.0;

  // ============================================================
  // Standard Margin Scale
  // ============================================================

  /// Small margin: 8.0
  static const double marginSmall = 8.0;

  /// Medium margin: 16.0
  static const double marginMedium = 16.0;

  /// Large margin: 24.0
  static const double marginLarge = 24.0;

  // ============================================================
  // Border Radius
  // ============================================================

  /// Small radius: 4.0
  static const double radiusSmall = 4.0;

  /// Medium radius: 8.0
  static const double radiusMedium = 8.0;

  /// Large radius: 12.0
  static const double radiusLarge = 12.0;

  /// Extra large radius: 16.0
  static const double radiusXLarge = 16.0;

  /// Circular/pill radius: 999.0
  static const double radiusCircular = 999.0;

  // ============================================================
  // Icon Sizes
  // ============================================================

  /// Small icon: 16.0
  static const double iconSmall = 16.0;

  /// Medium icon: 24.0
  static const double iconMedium = 24.0;

  /// Large icon: 32.0
  static const double iconLarge = 32.0;

  /// Extra large icon: 48.0
  static const double iconXLarge = 48.0;

  // ============================================================
  // Sidebar Dimensions
  // ============================================================

  /// Sidebar expanded width
  static const double sidebarExpandedWidth = 240.0;

  /// Sidebar collapsed width (icons only)
  static const double sidebarCollapsedWidth = 56.0;

  // ============================================================
  // Card Dimensions
  // ============================================================

  /// Stream preview card height
  static const double streamCardHeight = 180.0;

  /// Stream card aspect ratio (16:9)
  static const double streamCardAspectRatio = 16 / 9;

  /// Category card height
  static const double categoryCardHeight = 200.0;

  /// Category card aspect ratio (~3:4 box art)
  static const double categoryCardAspectRatio = 3 / 4;

  // ============================================================
  // Window Dimensions
  // ============================================================

  /// Default window width
  static const double windowDefaultWidth = 1280.0;

  /// Default window height
  static const double windowDefaultHeight = 720.0;

  /// Minimum window width
  static const double windowMinWidth = 800.0;

  /// Minimum window height
  static const double windowMinHeight = 600.0;

  // ============================================================
  // Content Counts (Home Screen)
  // ============================================================

  /// Number of featured streams on home screen
  static const int homeStreamCount = 10;

  /// Number of categories on home screen
  static const int homeCategoryCount = 12;

  // ============================================================
  // Touch Targets (Accessibility)
  // ============================================================

  /// Minimum touch target size for accessibility
  static const double minTouchTarget = 48.0;

  /// Standard button height
  static const double buttonHeight = 40.0;

  /// Large button height
  static const double buttonHeightLarge = 48.0;
}
