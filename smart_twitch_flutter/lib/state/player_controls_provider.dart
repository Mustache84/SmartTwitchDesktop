import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';
import '../services/hls_manifest_service.dart';

/// State for player controls (per-player instance)
class PlayerControlsState {
  final bool isPlaying;
  final bool isMuted;
  final double volume;
  final bool isFullscreen;
  final bool showControls;
  final bool showStats;
  final String currentQuality;
  final List<QualityOption> availableQualities;
  final bool lowLatencyMode;
  final double latencyTarget;
  final Duration currentPosition;
  final Duration? bufferPosition;
  final bool isBuffering;
  final String? error;

  const PlayerControlsState({
    this.isPlaying = true,
    this.isMuted = false,
    this.volume = 0.8,
    this.isFullscreen = false,
    this.showControls = true,
    this.showStats = false,
    this.currentQuality = 'auto',
    this.availableQualities = const [],
    this.lowLatencyMode = true,
    this.latencyTarget = 2.0,
    this.currentPosition = Duration.zero,
    this.bufferPosition,
    this.isBuffering = false,
    this.error,
  });

  PlayerControlsState copyWith({
    bool? isPlaying,
    bool? isMuted,
    double? volume,
    bool? isFullscreen,
    bool? showControls,
    bool? showStats,
    String? currentQuality,
    List<QualityOption>? availableQualities,
    bool? lowLatencyMode,
    double? latencyTarget,
    Duration? currentPosition,
    Duration? bufferPosition,
    bool? isBuffering,
    String? error,
  }) {
    return PlayerControlsState(
      isPlaying: isPlaying ?? this.isPlaying,
      isMuted: isMuted ?? this.isMuted,
      volume: volume ?? this.volume,
      isFullscreen: isFullscreen ?? this.isFullscreen,
      showControls: showControls ?? this.showControls,
      showStats: showStats ?? this.showStats,
      currentQuality: currentQuality ?? this.currentQuality,
      availableQualities: availableQualities ?? this.availableQualities,
      lowLatencyMode: lowLatencyMode ?? this.lowLatencyMode,
      latencyTarget: latencyTarget ?? this.latencyTarget,
      currentPosition: currentPosition ?? this.currentPosition,
      bufferPosition: bufferPosition ?? this.bufferPosition,
      isBuffering: isBuffering ?? this.isBuffering,
      error: error,
    );
  }
}

/// Notifier for player controls state
class PlayerControlsNotifier extends FamilyNotifier<PlayerControlsState, String> {
  final HlsManifestService _manifestService = HlsManifestService();
  final SettingsService _settings = SettingsService.instance;

  @override
  PlayerControlsState build(String channelLogin) {
    // Load initial state from settings
    return PlayerControlsState(
      volume: _settings.playerVolume,
      isMuted: _settings.playerMuted,
      lowLatencyMode: _settings.lowLatencyMode,
      latencyTarget: _settings.latencyTarget,
      currentQuality: _settings.getEffectiveQuality(channelLogin),
      showStats: _settings.showStats,
    );
  }

  /// Initialize with available qualities from manifest
  Future<void> loadQualities(String manifestUrl) async {
    final qualities = await _manifestService.getQualityOptions(manifestUrl);
    state = state.copyWith(availableQualities: qualities);
  }

  // ==========================================================================
  // PLAYBACK CONTROLS
  // ==========================================================================

  void play() {
    state = state.copyWith(isPlaying: true);
  }

  void pause() {
    state = state.copyWith(isPlaying: false);
  }

  void togglePlayPause() {
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  // ==========================================================================
  // VOLUME CONTROLS
  // ==========================================================================

  void setVolume(double volume) {
    final clamped = volume.clamp(0.0, 1.0);
    state = state.copyWith(volume: clamped, isMuted: clamped == 0);
    _settings.playerVolume = clamped;
  }

  void toggleMute() {
    final newMuted = !state.isMuted;
    state = state.copyWith(isMuted: newMuted);
    _settings.playerMuted = newMuted;
  }

  void volumeUp([double step = 0.1]) {
    setVolume(state.volume + step);
  }

  void volumeDown([double step = 0.1]) {
    setVolume(state.volume - step);
  }

  // ==========================================================================
  // QUALITY CONTROLS
  // ==========================================================================

  void setQuality(String qualityId, {bool saveForChannel = true}) {
    state = state.copyWith(currentQuality: qualityId);
    
    if (saveForChannel) {
      // Save as per-channel preference
      _settings.setChannelQuality(arg, qualityId);
    }
  }

  void setDefaultQuality(String qualityId) {
    _settings.defaultQuality = qualityId;
  }

  // ==========================================================================
  // LATENCY CONTROLS
  // ==========================================================================

  void toggleLowLatency() {
    final newMode = !state.lowLatencyMode;
    state = state.copyWith(lowLatencyMode: newMode);
    _settings.lowLatencyMode = newMode;
  }

  void setLatencyTarget(double seconds) {
    final clamped = seconds.clamp(0.5, 10.0);
    state = state.copyWith(latencyTarget: clamped);
    _settings.latencyTarget = clamped;
  }

  // ==========================================================================
  // UI CONTROLS
  // ==========================================================================

  void toggleFullscreen() {
    state = state.copyWith(isFullscreen: !state.isFullscreen);
  }

  void setFullscreen(bool fullscreen) {
    state = state.copyWith(isFullscreen: fullscreen);
  }

  void showControlsOverlay() {
    state = state.copyWith(showControls: true);
  }

  void hideControlsOverlay() {
    state = state.copyWith(showControls: false);
  }

  void toggleStats() {
    final newStats = !state.showStats;
    state = state.copyWith(showStats: newStats);
    _settings.showStats = newStats;
  }

  // ==========================================================================
  // PLAYBACK STATE UPDATES (called by player)
  // ==========================================================================

  void updatePosition(Duration position) {
    state = state.copyWith(currentPosition: position);
  }

  void updateBuffer(Duration? bufferPosition) {
    state = state.copyWith(bufferPosition: bufferPosition);
  }

  void setBuffering(bool buffering) {
    state = state.copyWith(isBuffering: buffering);
  }

  void setError(String? error) {
    state = state.copyWith(error: error);
  }
}

/// Provider for player controls (family provider, keyed by channel login)
final playerControlsProvider = NotifierProvider.family<PlayerControlsNotifier, PlayerControlsState, String>(
  PlayerControlsNotifier.new,
);

/// Convenience providers
final playerVolumeProvider = Provider.family<double, String>((ref, channel) {
  return ref.watch(playerControlsProvider(channel)).volume;
});

final playerMutedProvider = Provider.family<bool, String>((ref, channel) {
  return ref.watch(playerControlsProvider(channel)).isMuted;
});

final playerQualityProvider = Provider.family<String, String>((ref, channel) {
  return ref.watch(playerControlsProvider(channel)).currentQuality;
});

final playerIsPlayingProvider = Provider.family<bool, String>((ref, channel) {
  return ref.watch(playerControlsProvider(channel)).isPlaying;
});

final playerShowControlsProvider = Provider.family<bool, String>((ref, channel) {
  return ref.watch(playerControlsProvider(channel)).showControls;
});
