import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for persistent app settings using shared_preferences.
/// 
/// Stores:
/// - Default quality preference
/// - Per-channel quality overrides (unlimited, ~5KB per 100 channels)
/// - Low latency settings
/// - Player volume/mute state
class SettingsService {
  static SettingsService? _instance;
  static SharedPreferences? _prefs;

  // Preference keys
  static const _keyDefaultQuality = 'quality.default';
  static const _keyPerChannelQuality = 'quality.perChannel';
  static const _keyLatencyTarget = 'latency.target';
  static const _keyLowLatencyMode = 'latency.lowLatencyMode';
  static const _keyPlayerVolume = 'player.volume';
  static const _keyPlayerMuted = 'player.muted';
  static const _keyAutoPlay = 'player.autoPlay';
  static const _keyShowStats = 'player.showStats';

  SettingsService._();

  /// Get singleton instance
  static SettingsService get instance {
    _instance ??= SettingsService._();
    return _instance!;
  }

  /// Initialize shared preferences (call once at app startup)
  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get _preferences {
    if (_prefs == null) {
      throw StateError('SettingsService not initialized. Call initialize() first.');
    }
    return _prefs!;
  }

  // ==========================================================================
  // QUALITY SETTINGS
  // ==========================================================================

  /// Default quality preference for all streams
  /// Values: 'auto', 'source', '1080p60', '1080p', '720p60', '720p', '480p', '360p', '160p'
  String get defaultQuality => _preferences.getString(_keyDefaultQuality) ?? 'auto';

  set defaultQuality(String value) {
    _preferences.setString(_keyDefaultQuality, value);
  }

  /// Get quality preference for a specific channel
  /// Returns null if no per-channel preference is set (use default)
  String? getChannelQuality(String channelLogin) {
    final perChannel = _getPerChannelMap();
    return perChannel[channelLogin.toLowerCase()];
  }

  /// Set quality preference for a specific channel
  /// Pass null to remove the per-channel override
  Future<void> setChannelQuality(String channelLogin, String? quality) async {
    final perChannel = _getPerChannelMap();
    final key = channelLogin.toLowerCase();
    
    if (quality == null) {
      perChannel.remove(key);
    } else {
      perChannel[key] = quality;
    }
    
    await _preferences.setString(_keyPerChannelQuality, jsonEncode(perChannel));
  }

  /// Get effective quality for a channel (per-channel override or default)
  String getEffectiveQuality(String channelLogin) {
    return getChannelQuality(channelLogin) ?? defaultQuality;
  }

  /// Get all per-channel quality overrides
  Map<String, String> getAllChannelQualities() => _getPerChannelMap();

  /// Clear all per-channel quality overrides
  Future<void> clearAllChannelQualities() async {
    await _preferences.setString(_keyPerChannelQuality, '{}');
  }

  Map<String, String> _getPerChannelMap() {
    final json = _preferences.getString(_keyPerChannelQuality);
    if (json == null || json.isEmpty) return {};
    
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  // ==========================================================================
  // LATENCY SETTINGS
  // ==========================================================================

  /// Target latency in seconds (0.5 - 10.0)
  double get latencyTarget => _preferences.getDouble(_keyLatencyTarget) ?? 2.0;

  set latencyTarget(double value) {
    _preferences.setDouble(_keyLatencyTarget, value.clamp(0.5, 10.0));
  }

  /// Whether low latency mode is enabled
  bool get lowLatencyMode => _preferences.getBool(_keyLowLatencyMode) ?? true;

  set lowLatencyMode(bool value) {
    _preferences.setBool(_keyLowLatencyMode, value);
  }

  // ==========================================================================
  // PLAYER SETTINGS
  // ==========================================================================

  /// Player volume (0.0 - 1.0)
  double get playerVolume => _preferences.getDouble(_keyPlayerVolume) ?? 0.8;

  set playerVolume(double value) {
    _preferences.setDouble(_keyPlayerVolume, value.clamp(0.0, 1.0));
  }

  /// Whether player is muted
  bool get playerMuted => _preferences.getBool(_keyPlayerMuted) ?? false;

  set playerMuted(bool value) {
    _preferences.setBool(_keyPlayerMuted, value);
  }

  /// Whether to auto-play when opening a stream
  bool get autoPlay => _preferences.getBool(_keyAutoPlay) ?? true;

  set autoPlay(bool value) {
    _preferences.setBool(_keyAutoPlay, value);
  }

  /// Whether to show stats overlay by default
  bool get showStats => _preferences.getBool(_keyShowStats) ?? false;

  set showStats(bool value) {
    _preferences.setBool(_keyShowStats, value);
  }
}

/// Available quality options
class QualityOption {
  final String id;
  final String label;
  final int? width;
  final int? height;
  final int? frameRate;
  final int? bandwidth;
  final String? codecs;

  const QualityOption({
    required this.id,
    required this.label,
    this.width,
    this.height,
    this.frameRate,
    this.bandwidth,
    this.codecs,
  });

  /// Check if this is the "auto" quality option
  bool get isAuto => id == 'auto';

  /// Check if this is the "source" quality option
  bool get isSource => id == 'source' || id == 'chunked';

  /// Human-readable resolution string
  String get resolution {
    if (isAuto) return 'Auto';
    if (height == null) return label;
    final fps = frameRate != null ? '$frameRate' : '';
    return '${height}p$fps';
  }

  @override
  String toString() => 'QualityOption($id: $label)';
}
