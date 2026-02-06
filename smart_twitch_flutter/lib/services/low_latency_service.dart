import 'dart:async';
import 'package:fvp/fvp.dart' as fvp;
import 'package:smart_twitch_flutter/core/interfaces/disposable.dart';
import 'settings_service.dart';

/// Service for managing low-latency playback.
///
/// Uses MDK's buffer control and playback rate adjustment for catch-up.
/// Target latency is configurable from 0.5s to 10s.
///
/// Implements [Disposable] for graceful shutdown on window close.
class LowLatencyService implements Disposable {
  LowLatencyService._();
  static final instance = LowLatencyService._();

  /// Minimum buffer in milliseconds (for low latency mode)
  static const int minBufferMs = 500;

  /// Maximum buffer in milliseconds (for stability mode)
  static const int maxBufferMs = 10000;

  /// Default target latency in seconds
  static const double defaultLatencyTarget = 2.0;

  /// Playback rate for catch-up (when behind target)
  static const double catchUpRate = 1.05;

  /// Playback rate for normal playback
  static const double normalRate = 1.0;

  /// Threshold to trigger catch-up (seconds ahead of target)
  static const double catchUpThreshold = 0.5;

  Timer? _catchUpTimer;
  bool _isLowLatencyMode = true;
  double _latencyTarget = defaultLatencyTarget;

  /// Whether low latency mode is enabled
  bool get isLowLatencyMode => _isLowLatencyMode;

  /// Current target latency in seconds
  double get latencyTarget => _latencyTarget;

  /// Initialize the service with saved settings
  Future<void> initialize() async {
    _isLowLatencyMode = SettingsService.instance.lowLatencyMode;
    _latencyTarget = SettingsService.instance.latencyTarget;
  }

  /// Set low latency mode on/off
  Future<void> setLowLatencyMode(bool enabled) async {
    _isLowLatencyMode = enabled;
    SettingsService.instance.lowLatencyMode = enabled;
  }

  /// Set target latency in seconds (0.5 - 10.0)
  Future<void> setLatencyTarget(double seconds) async {
    _latencyTarget = seconds.clamp(0.5, 10.0);
    SettingsService.instance.latencyTarget = _latencyTarget;
  }

  /// Get the buffer range configuration for MDK
  ///
  /// Returns (minMs, maxMs, drop) for setBufferRange
  (int, int, bool) getBufferConfig() {
    if (_isLowLatencyMode) {
      final targetMs = (_latencyTarget * 1000).toInt();
      // In low latency mode, use tight buffer around target
      return (0, targetMs, true);
    } else {
      // In stability mode, use larger buffer
      return (0, maxBufferMs, false);
    }
  }

  /// Apply buffer settings to a player
  ///
  /// Call this after creating a player or when changing latency settings.
  /// Note: fvp/MDK uses setBufferRange on the native side.
  /// This provides the parameters to use.
  Map<String, dynamic> getPlayerOptions() {
    final (minMs, maxMs, drop) = getBufferConfig();
    return {
      'lowLatency': _isLowLatencyMode ? 1 : 0,
      'bufferMin': minMs,
      'bufferMax': maxMs,
      'bufferDrop': drop,
    };
  }

  /// Format latency for display
  static String formatLatency(double seconds) {
    if (seconds < 1.0) {
      return '${(seconds * 1000).toInt()}ms';
    } else if (seconds == seconds.toInt().toDouble()) {
      return '${seconds.toInt()}s';
    } else {
      return '${seconds.toStringAsFixed(1)}s';
    }
  }

  /// Get preset latency options
  static List<LatencyPreset> get presets => const [
        LatencyPreset(0.5, 'Ultra Low', 'May stutter on slow connections'),
        LatencyPreset(1.0, 'Low', 'Good for fast reactions'),
        LatencyPreset(2.0, 'Normal', 'Balanced latency and stability'),
        LatencyPreset(4.0, 'Stable', 'Fewer drops, more delay'),
        LatencyPreset(10.0, 'Maximum', 'Best stability, most delay'),
      ];

  /// Dispose resources, cancelling any catch-up timers.
  @override
  Future<void> dispose() async {
    _catchUpTimer?.cancel();
    _catchUpTimer = null;
  }
}

/// A latency preset option
class LatencyPreset {
  const LatencyPreset(this.seconds, this.name, this.description);

  final double seconds;
  final String name;
  final String description;

  @override
  String toString() => '$name (${LowLatencyService.formatLatency(seconds)})';
}
