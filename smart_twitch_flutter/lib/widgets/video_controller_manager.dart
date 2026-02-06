import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:smart_twitch_flutter/models/twitch_session.dart';
import 'package:smart_twitch_flutter/state/integrity_provider.dart';
import 'package:smart_twitch_flutter/utils/browser_constants.dart';

/// Manages video player controllers keyed by channel name
/// This allows streams to persist when slots are rearranged
class VideoControllerManager {
  static final VideoControllerManager _instance = VideoControllerManager._internal();
  factory VideoControllerManager() => _instance;
  VideoControllerManager._internal() {
    // Register fvp once at startup
    fvp.registerWith();
  }
  
  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, bool> _initializing = {};
  final Map<String, String?> _errors = {};
  /// Tracks channels that should not be initialized (cancelled)
  final Set<String> _cancelled = {};
  
  /// Get or create a controller for a channel
  /// 
  /// If [session] is provided, the controller will include integrity headers.
  Future<VideoPlayerController> getController(
    String channelLogin,
    String hlsUrl, {
    TwitchSession? session,
  }) async {
    // Check if cancelled
    if (_cancelled.contains(channelLogin)) {
      _cancelled.remove(channelLogin);
      throw Exception('Controller initialization cancelled for $channelLogin');
    }
    
    // If controller already exists and is for the same URL, return it
    if (_controllers.containsKey(channelLogin)) {
      return _controllers[channelLogin]!;
    }
    
    // Mark as initializing
    _initializing[channelLogin] = true;
    _errors[channelLogin] = null;
    
    try {
      print('[VideoManager] Creating controller for $channelLogin');
      
      // Build HTTP headers - MUST match the harvester User-Agent exactly
      final headers = <String, String>{
        'User-Agent': kBrowserUserAgent,
      };
      
      // Add integrity headers if session is available
      if (session != null) {
        headers['Client-ID'] = session.clientId;
        headers['Client-Integrity'] = session.integrityToken;
        headers['X-Device-Id'] = session.deviceId;
        
        if (session.authorization != null) {
          headers['Authorization'] = session.authorization!;
        }
        
        if (session.cookieString.isNotEmpty) {
          headers['Cookie'] = session.cookieString;
        }
        
        print('[VideoManager] 🔐 Using integrity session for $channelLogin');
      } else {
        print('[VideoManager] ⚠️ No integrity session - playback may fail');
      }
      
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(hlsUrl),
        httpHeaders: headers,
      );
      
      await controller.initialize();
      
      // Check if cancelled during async initialization
      if (_cancelled.contains(channelLogin)) {
        print('[VideoManager] Controller cancelled during init for $channelLogin');
        _cancelled.remove(channelLogin);
        controller.dispose();
        _initializing[channelLogin] = false;
        throw Exception('Controller initialization cancelled for $channelLogin');
      }
      
      await controller.play();
      
      _controllers[channelLogin] = controller;
      _initializing[channelLogin] = false;
      
      print('[VideoManager] Controller ready for $channelLogin');
      return controller;
      
    } catch (e) {
      print('[VideoManager] Error creating controller for $channelLogin: $e');
      _initializing[channelLogin] = false;
      
      // Check if this is likely an offline channel error
      final errorString = e.toString();
      if (errorString.contains('media open error') || 
          errorString.contains('invalid or unsupported media')) {
        _errors[channelLogin] = 'Channel appears to be offline';
      } else if (!errorString.contains('cancelled')) {
        _errors[channelLogin] = errorString;
      }
      
      rethrow;
    }
  }
  
  /// Check if a controller exists
  bool hasController(String channelLogin) => _controllers.containsKey(channelLogin);
  
  /// Check if initializing
  bool isInitializing(String channelLogin) => _initializing[channelLogin] ?? false;
  
  /// Get error for channel
  String? getError(String channelLogin) => _errors[channelLogin];
  
  /// Get existing controller (may be null)
  VideoPlayerController? getExistingController(String channelLogin) => _controllers[channelLogin];
  
  /// Set volume on a controller
  void setVolume(String channelLogin, double volume) {
    _controllers[channelLogin]?.setVolume(volume);
  }
  
  /// Dispose a specific controller
  void disposeController(String channelLogin) {
    print('[VideoManager] Disposing controller for $channelLogin');
    
    // Mark as cancelled to abort any in-flight initialization
    _cancelled.add(channelLogin);
    
    // Dispose existing controller
    _controllers[channelLogin]?.dispose();
    _controllers.remove(channelLogin);
    _initializing.remove(channelLogin);
    _errors.remove(channelLogin);
  }
  
  /// Dispose all controllers
  void disposeAll() {
    print('[VideoManager] Disposing all controllers');
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _initializing.clear();
    _errors.clear();
    _cancelled.clear();
  }
}

/// Provider for the video controller manager
final videoManagerProvider = Provider<VideoControllerManager>((ref) {
  return VideoControllerManager();
});

/// Persistent video widget that uses the shared controller manager
class PersistentVideoWidget extends ConsumerStatefulWidget {
  final String channelLogin;
  final String hlsUrl;
  final bool hasAudio;
  
  const PersistentVideoWidget({
    super.key,
    required this.channelLogin,
    required this.hlsUrl,
    required this.hasAudio,
  });

  @override
  ConsumerState<PersistentVideoWidget> createState() => _PersistentVideoWidgetState();
}

class _PersistentVideoWidgetState extends ConsumerState<PersistentVideoWidget> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  String? _error;
  bool _disposed = false;
  
  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }
  
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
  
  Future<void> _initializePlayer() async {
    final manager = ref.read(videoManagerProvider);
    final session = ref.read(integritySessionProvider);
    
    // Check if controller already exists
    final existing = manager.getExistingController(widget.channelLogin);
    if (existing != null) {
      if (_disposed) return;
      setState(() {
        _controller = existing;
        _initialized = true;
      });
      _updateVolume();
      return;
    }
    
    // Check for existing error
    final existingError = manager.getError(widget.channelLogin);
    if (existingError != null) {
      if (_disposed) return;
      setState(() => _error = existingError);
      return;
    }
    
    try {
      final controller = await manager.getController(
        widget.channelLogin,
        widget.hlsUrl,
        session: session,
      );
      // Check if disposed during async operation
      if (_disposed) {
        // Widget was disposed while we were initializing - clean up the controller
        print('[PersistentVideoWidget] Widget disposed during init, cleaning up ${widget.channelLogin}');
        manager.disposeController(widget.channelLogin);
        return;
      }
      if (mounted) {
        setState(() {
          _controller = controller;
          _initialized = true;
        });
        _updateVolume();
      }
    } catch (e) {
      if (_disposed) return;
      if (mounted) {
        setState(() {
          _error = manager.getError(widget.channelLogin) ?? e.toString();
        });
      }
    }
  }
  
  void _updateVolume() {
    final manager = ref.read(videoManagerProvider);
    manager.setVolume(widget.channelLogin, widget.hasAudio ? 1.0 : 0.0);
  }
  
  @override
  void didUpdateWidget(PersistentVideoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Only update volume when hasAudio changes - don't reinitialize!
    if (oldWidget.hasAudio != widget.hasAudio) {
      _updateVolume();
    }
  }
  
  // Note: We don't dispose the controller here - it's managed by VideoControllerManager
  // and will be disposed when the stream is removed from the multi-stream state

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      final isOffline = _error == 'Channel appears to be offline';
      
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOffline ? Icons.tv_off : Icons.error,
              color: isOffline ? Colors.grey : Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                color: isOffline ? Colors.grey[400] : Colors.white,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    if (!_initialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.purple),
      );
    }
    
    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio > 0 
          ? _controller!.value.aspectRatio 
          : 16 / 9,
      child: VideoPlayer(_controller!),
    );
  }
}
