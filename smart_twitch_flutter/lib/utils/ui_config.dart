/// Centralized UIUX configuration constants
/// 
/// All timing, animation, and behavioral values that affect user experience
/// should be defined here for easy tuning and future exposure in Settings.
/// 
/// TODO: Expose these settings in Settings screen for user customization
library;

import 'package:flutter/material.dart';

class UIConfig {
  // Prevent instantiation
  UIConfig._();
  
  // ============================================================
  // Stream Preview Behavior
  // ============================================================
  
  /// Delay before stream preview starts playing on hover/focus
  /// 
  /// With pre-initialized controllers, this can be very low since
  /// we're just calling play() - no network latency.
  /// TODO (Release): Make this user-tunable in Settings (range: 0-2000ms)
  static const Duration streamPreviewHoverDelay = Duration(milliseconds: 50);
  
  /// Whether stream previews should auto-play with audio
  static const bool streamPreviewAudioEnabled = true;
  
  /// Preview quality setting
  /// 
  /// Options: 'auto', '1080p', '720p', '480p', '360p'
  /// Auto lets Twitch/player decide based on bandwidth.
  /// TODO (Release): Make this user-tunable in Settings
  static const String streamPreviewQuality = 'auto';
  
  // ============================================================
  // Sidebar Animation
  // ============================================================
  
  /// Duration for sidebar expand/collapse animation
  /// 
  /// Kept snappy to avoid blocking user's view of content.
  /// TODO (Release): Consider making this user-tunable
  static const Duration sidebarAnimationDuration = Duration(milliseconds: 150);
  
  /// Sidebar expanded width
  static const double sidebarExpandedWidth = 240.0;
  
  /// Sidebar collapsed width (just icons)
  static const double sidebarCollapsedWidth = 56.0;
  
  /// Sidebar animation curve
  static const Curve sidebarAnimationCurve = Curves.easeOutCubic;
  
  // ============================================================
  // Home Screen Layout
  // ============================================================
  
  /// Number of featured streams to show on home screen
  static const int homeScreenStreamCount = 10;
  
  /// Number of categories to show on home screen
  static const int homeScreenCategoryCount = 12;
  
  /// Height of stream preview cards
  static const double streamCardHeight = 180.0;
  
  /// Aspect ratio for stream thumbnails (16:9)
  static const double streamCardAspectRatio = 16 / 9;
  
  /// Height of category cards
  static const double categoryCardHeight = 200.0;
  
  /// Aspect ratio for category box art (typically ~3:4)
  static const double categoryCardAspectRatio = 3 / 4;
  
  // ============================================================
  // Search Bar
  // ============================================================
  
  /// Debounce delay for search input
  static const Duration searchDebounceDelay = Duration(milliseconds: 400);
  
  // ============================================================
  // Colors & Theming
  // ============================================================
  
  /// Twitch brand purple
  static const Color twitchPurple = Color(0xFF9146FF);
  
  /// Twitch dark background
  static const Color twitchDarkBg = Color(0xFF0E0E10);
  
  /// Twitch card/surface color
  static const Color twitchSurface = Color(0xFF18181B);
  
  /// Twitch hover highlight
  static const Color twitchHover = Color(0xFF26262C);
  
  /// Live indicator red
  static const Color liveIndicatorRed = Color(0xFFEB0400);
}
