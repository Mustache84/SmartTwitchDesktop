/// Single Source of Truth for animation and timing constants.
///
/// This class contains all Duration values used for animations,
/// timeouts, debouncing, and other time-based behaviors.
///
/// Separating durations from AppDimens keeps numeric values
/// semantically organized (space vs. time).
///
/// Usage:
/// ```dart
/// import 'package:smart_twitch_flutter/core/theme/app_durations.dart';
/// AnimatedContainer(duration: AppDurations.animationFast)
/// ```
abstract final class AppDurations {
  // Prevent instantiation
  AppDurations._();

  // ============================================================
  // Animation Durations
  // ============================================================

  /// Instant animation: 0ms (for testing/debugging)
  static const Duration instant = Duration.zero;

  /// Ultra fast animation: 100ms
  static const Duration animationUltraFast = Duration(milliseconds: 100);

  /// Fast animation: 150ms
  static const Duration animationFast = Duration(milliseconds: 150);

  /// Normal animation: 200ms
  static const Duration animationNormal = Duration(milliseconds: 200);

  /// Slow animation: 300ms
  static const Duration animationSlow = Duration(milliseconds: 300);

  /// Extra slow animation: 500ms
  static const Duration animationExtraSlow = Duration(milliseconds: 500);

  // ============================================================
  // Component-Specific Durations
  // ============================================================

  /// Sidebar expand/collapse animation
  static const Duration sidebarAnimation = Duration(milliseconds: 150);

  /// Player controls fade in/out
  static const Duration controlsFade = Duration(milliseconds: 200);

  /// Stream preview hover delay before playback starts
  static const Duration streamPreviewHoverDelay = Duration(milliseconds: 50);

  /// Player controls auto-hide delay after mouse inactivity
  static const Duration controlsAutoHide = Duration(seconds: 3);

  // ============================================================
  // Debounce/Throttle Durations
  // ============================================================

  /// Search input debounce delay
  static const Duration searchDebounce = Duration(milliseconds: 400);

  /// General input debounce
  static const Duration inputDebounce = Duration(milliseconds: 300);

  /// Scroll position save debounce
  static const Duration scrollDebounce = Duration(milliseconds: 150);

  // ============================================================
  // Timeout Durations
  // ============================================================

  /// Network request timeout
  static const Duration networkTimeout = Duration(seconds: 30);

  /// Connection timeout
  static const Duration connectionTimeout = Duration(seconds: 10);

  /// Snackbar display duration
  static const Duration snackbarDuration = Duration(seconds: 4);

  // ============================================================
  // Refresh Intervals
  // ============================================================

  /// Live data refresh interval (viewer counts, etc.)
  static const Duration liveDataRefresh = Duration(seconds: 60);

  /// Followed channels refresh interval
  static const Duration followedRefresh = Duration(minutes: 5);
}
