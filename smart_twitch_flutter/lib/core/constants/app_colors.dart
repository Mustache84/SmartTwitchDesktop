import 'package:flutter/material.dart';

/// Single Source of Truth for all app color constants.
///
/// This class contains all color definitions used throughout the app.
/// Import this file instead of hardcoding hex values in widgets.
///
/// Organization:
/// - Brand colors (Twitch purple, etc.)
/// - Background colors (scaffolds, cards)
/// - Semantic colors (success, error, warning)
/// - Overlay colors (modals, tooltips)
///
/// Usage:
/// ```dart
/// import 'package:smart_twitch_flutter/core/constants/app_colors.dart';
/// Container(color: AppColors.primary)
/// ```
abstract final class AppColors {
  // Prevent instantiation
  AppColors._();

  // ============================================================
  // Brand Colors
  // ============================================================

  /// Primary brand color - Twitch Purple
  static const Color primary = Color(0xFF9146FF);

  /// Secondary accent color
  static const Color secondary = Color(0xFF772CE8);

  /// Twitch brand purple (alias for primary)
  static const Color twitchPurple = primary;

  // ============================================================
  // Background Colors
  // ============================================================

  /// Main scaffold/app background - Twitch Dark
  static const Color background = Color(0xFF0E0E10);

  /// Alternative dark background
  static const Color backgroundDark = Color(0xFF0E0E10);

  /// Card/Surface background color
  static const Color surface = Color(0xFF18181B);

  /// Elevated surface (cards, dialogs)
  static const Color surfaceElevated = Color(0xFF1F1F23);

  /// Hover state background
  static const Color hover = Color(0xFF26262C);

  // ============================================================
  // Text Colors
  // ============================================================

  /// Primary text color
  static const Color textPrimary = Colors.white;

  /// Secondary/muted text color
  static const Color textSecondary = Color(0xFFADADB8);

  /// Disabled text color
  static const Color textDisabled = Color(0xFF636369);

  // ============================================================
  // Semantic Colors
  // ============================================================

  /// Live indicator red
  static const Color liveRed = Color(0xFFEB0400);

  /// Success/Online green
  static const Color success = Color(0xFF00C853);

  /// Warning/Caution amber
  static const Color warning = Color(0xFFFFB300);

  /// Error/Offline red
  static const Color error = Color(0xFFEB0400);

  // ============================================================
  // Overlay Colors
  // ============================================================

  /// Modal barrier/overlay color
  static const Color overlay = Color(0x99000000);

  /// Tooltip background
  static const Color tooltip = Color(0xFF323236);

  // ============================================================
  // Border Colors
  // ============================================================

  /// Default border color
  static const Color border = Color(0xFF38383D);

  /// Focused border color
  static const Color borderFocused = primary;

  // ============================================================
  // Player Colors
  // ============================================================

  /// Player control bar background
  static const Color playerControlsBg = Color(0xCC000000);

  /// Progress bar background
  static const Color progressBarBg = Color(0xFF464649);

  /// Progress bar active/filled
  static const Color progressBarActive = primary;
}
