import 'package:flutter/material.dart';

/// Single Source of Truth for animation curves.
///
/// This class contains all Curve definitions used for animations.
/// Separating curves from durations maintains semantic clarity.
///
/// Usage:
/// ```dart
/// import 'package:smart_twitch_flutter/core/theme/app_curves.dart';
/// CurvedAnimation(curve: AppCurves.standard)
/// ```
abstract final class AppCurves {
  // Prevent instantiation
  AppCurves._();

  // ============================================================
  // Standard Curves
  // ============================================================

  /// Standard ease out curve for most animations
  static const Curve standard = Curves.easeOut;

  /// Smooth deceleration (ease out cubic)
  static const Curve decelerate = Curves.easeOutCubic;

  /// Smooth acceleration (ease in)
  static const Curve accelerate = Curves.easeIn;

  /// Smooth acceleration and deceleration
  static const Curve smooth = Curves.easeInOut;

  // ============================================================
  // Component-Specific Curves
  // ============================================================

  /// Sidebar expand/collapse animation curve
  static const Curve sidebar = Curves.easeOutCubic;

  /// Modal/dialog entrance curve
  static const Curve modal = Curves.easeOutCubic;

  /// Fade animations curve
  static const Curve fade = Curves.easeOut;

  /// Scale animations curve
  static const Curve scale = Curves.easeOutBack;
}
