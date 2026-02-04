import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:fvp/fvp.dart' as fvp;
import '../models/stream_preview.dart';
import '../utils/hls_url_builder.dart';
import 'twitch_api_service.dart';

/// Pre-initialized video controller for instant playback
class PreloadedController {
  final String channelLogin;
  final VideoPlayerController controller;
  final DateTime initializedAt;
  bool isPlaying = false;
  
  PreloadedController({
    required this.channelLogin,
    required this.controller,
  }) : initializedAt = DateTime.now();
}

/// Manages PRE-INITIALIZED video controllers for all visible streams
/// 
/// Optimizations:
/// 1. Pre-initializes ALL controllers when streams load (parallel)
/// 2. On hover: just calls play() - INSTANT playback!
/// 3. Token caching for refresh scenarios
/// 4. Single controller plays at a time (others paused)
class PreviewPlayerManager extends ChangeNotifier {
  static final PreviewPlayerManager _instance = PreviewPlayerManager._internal();
  factory PreviewPlayerManager() => _instance;
  PreviewPlayerManager._internal() {
    fvp.registerWith();
  }
  
  final TwitchApiService _apiService = TwitchApiService();
  
  // Pre-initialized controllers keyed by channel login
  final Map<String, PreloadedController> _controllers = {};
  
  // Track initialization progress
  final Set<String> _initializing = {};
  final Map<String, String> _errors = {};
  
  // Currently playing channel
  String? _currentChannel;
  bool _isLoading = false;
  
  // Pending play: channel that should auto-play when its controller becomes ready
  String? _pendingPlay;

  // Getters
  String? get currentChannel => _currentChannel;
  bool get isLoading => _isLoading;
  String? get error => _currentChannel != null ? _errors[_currentChannel] : null;
  VideoPlayerController? get controller => _currentChannel != null 
      ? _controllers[_currentChannel]?.controller 
      : null;
  
  /// Pre-initialize controllers for ALL streams
  /// Called when streams are loaded - makes previews instant!
  Future<void> preloadAllStreams(List<StreamPreview> streams) async {
    print('[PreviewManager] Pre-loading ${streams.length} streams...');
    
    // Dispose any old controllers first
    await _disposeAllControllers();
    
    // Fetch all tokens in parallel
    final tokenFutures = streams.map((s) => _fetchToken(s.login));
    final tokens = await Future.wait(tokenFutures);
    
    // Build HLS URLs and initialize controllers in parallel
    final initFutures = <Future<void>>[];
    
    for (int i = 0; i < streams.length; i++) {
      final stream = streams[i];
      final token = tokens[i];
      
      if (token != null) {
        initFutures.add(_initializeController(stream.login, token));
      } else {
        _errors[stream.login] = 'Failed to get token';
      }
    }
    
    // Wait for all controllers to initialize
    await Future.wait(initFutures);
    
    final successCount = _controllers.length;
    final failCount = streams.length - successCount;
    print('[PreviewManager] Pre-loaded $successCount streams ($failCount failed)');
    
    notifyListeners();
  }
  
  /// Fetch playback token for a channel
  Future<PlaybackToken?> _fetchToken(String channelLogin) async {
    try {
      return await _apiService.getPlaybackToken(channelLogin);
    } catch (e) {
      print('[PreviewManager] Token fetch failed for $channelLogin: $e');
      return null;
    }
  }
  
  /// Initialize a single controller (called in parallel)
  Future<void> _initializeController(String channelLogin, PlaybackToken token) async {
    if (_initializing.contains(channelLogin)) return;
    _initializing.add(channelLogin);
    
    try {
      final hlsUrl = HlsUrlBuilder.buildStreamUrl(
        channel: channelLogin,
        token: token.token,
        signature: token.signature,
      );
      
      print('[PreviewManager] Initializing controller for $channelLogin');
      
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(hlsUrl),
        httpHeaders: const {
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        },
      );
      
      await controller.initialize();
      
      // Set volume to 0 initially (will unmute when played)
      await controller.setVolume(0.0);
      
      // DON'T play yet - just keep it ready
      // The first frame will be buffered
      
      _controllers[channelLogin] = PreloadedController(
        channelLogin: channelLogin,
        controller: controller,
      );
      
      print('[PreviewManager] Controller ready for $channelLogin');
      
      // Check if this channel was pending play (user hovered during preload)
      if (_pendingPlay == channelLogin && _currentChannel == channelLogin) {
        print('[PreviewManager] Auto-playing pending channel: $channelLogin');
        await controller.setVolume(1.0);
        await controller.play();
        _controllers[channelLogin]!.isPlaying = true;
        _pendingPlay = null;
        _isLoading = false;
        notifyListeners();
      }
      
    } catch (e) {
      print('[PreviewManager] Init failed for $channelLogin: $e');
      
      final errorString = e.toString();
      if (errorString.contains('media open error') || 
          errorString.contains('invalid or unsupported media')) {
        _errors[channelLogin] = 'Channel offline';
      } else {
        _errors[channelLogin] = 'Load failed';
      }
    } finally {
      _initializing.remove(channelLogin);
    }
  }
  
  /// Start playing a channel preview - INSTANT if pre-loaded!
  Future<void> startPreview(String channelLogin) async {
    // Same channel - do nothing
    if (_currentChannel == channelLogin) {
      return;
    }
    
    // Pause current preview
    if (_currentChannel != null && _controllers.containsKey(_currentChannel)) {
      final current = _controllers[_currentChannel]!;
      current.controller.pause();
      current.controller.setVolume(0.0);
      current.isPlaying = false;
    }
    
    _currentChannel = channelLogin;
    
    // Check if we have a pre-loaded controller
    final preloaded = _controllers[channelLogin];
    if (preloaded != null) {
      print('[PreviewManager] INSTANT play for $channelLogin');
      
      // Clear any pending play since we're playing now
      _pendingPlay = null;
      
      // Just play - it's already initialized!
      await preloaded.controller.setVolume(1.0);
      await preloaded.controller.play();
      preloaded.isPlaying = true;
      
      notifyListeners();
      return;
    }
    
    // Check if controller is being initialized by preload - queue for auto-play
    if (_initializing.contains(channelLogin)) {
      print('[PreviewManager] Queuing play for $channelLogin (still initializing)');
      _pendingPlay = channelLogin;
      _isLoading = true;
      notifyListeners();
      return;  // Don't start duplicate init, just wait for preload to finish
    }
    
    // Fallback: Initialize on-demand if not pre-loaded and not initializing
    print('[PreviewManager] On-demand load for $channelLogin (not pre-loaded)');
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final token = await _fetchToken(channelLogin);
      if (token == null) throw Exception('Failed to get token');
      
      await _initializeController(channelLogin, token);
      
      // Now play it
      final controller = _controllers[channelLogin];
      if (controller != null && _currentChannel == channelLogin) {
        await controller.controller.setVolume(1.0);
        await controller.controller.play();
        controller.isPlaying = true;
      }
      
      _isLoading = false;
      notifyListeners();
      
    } catch (e) {
      print('[PreviewManager] On-demand load failed: $e');
      _isLoading = false;
      _errors[channelLogin] = 'Load failed';
      notifyListeners();
    }
  }
  
  /// Stop the current preview (pause, don't dispose)
  void stopPreview() {
    // Clear pending play - user moved mouse away
    _pendingPlay = null;
    
    if (_currentChannel != null && _controllers.containsKey(_currentChannel)) {
      final current = _controllers[_currentChannel]!;
      current.controller.pause();
      current.controller.setVolume(0.0);
      current.isPlaying = false;
    }
    
    _currentChannel = null;
    _isLoading = false;
    notifyListeners();
  }
  
  /// Check if a channel has an error
  String? getError(String channelLogin) => _errors[channelLogin];
  
  /// Check if a channel is pre-loaded and ready
  bool isReady(String channelLogin) => _controllers.containsKey(channelLogin);
  
  /// Check if a channel is initializing
  bool isInitializing(String channelLogin) => _initializing.contains(channelLogin);
  
  /// Dispose all controllers (call when leaving home screen)
  Future<void> _disposeAllControllers() async {
    _pendingPlay = null;  // Clear pending play on dispose
    for (final preloaded in _controllers.values) {
      await preloaded.controller.dispose();
    }
    _controllers.clear();
    _errors.clear();
    _currentChannel = null;
  }
  
  /// Public dispose method
  void disposePlayer() {
    print('[PreviewManager] Disposing all preview controllers');
    _disposeAllControllers();
    notifyListeners();
  }
  
  /// Refresh a specific channel's controller
  Future<void> refreshChannel(String channelLogin) async {
    // Dispose old controller
    final old = _controllers.remove(channelLogin);
    await old?.controller.dispose();
    _errors.remove(channelLogin);
    
    // Re-initialize
    final token = await _fetchToken(channelLogin);
    if (token != null) {
      await _initializeController(channelLogin, token);
    }
    
    notifyListeners();
  }
}
