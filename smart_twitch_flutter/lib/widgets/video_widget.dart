import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:smart_twitch_flutter/models/twitch_session.dart';
import 'package:smart_twitch_flutter/utils/browser_constants.dart';

/// Controller wrapper that exposes video player controls
class TwitchPlayerController {
  final VideoPlayerController _controller;
  final void Function() _onReload;
  
  TwitchPlayerController(this._controller, this._onReload);
  
  /// Get the underlying video player controller
  VideoPlayerController get videoController => _controller;
  
  /// Play the video
  Future<void> play() => _controller.play();
  
  /// Pause the video
  Future<void> pause() => _controller.pause();
  
  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_controller.value.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }
  
  /// Set volume (0.0 - 1.0)
  Future<void> setVolume(double volume) => _controller.setVolume(volume.clamp(0.0, 1.0));
  
  /// Get current volume
  double get volume => _controller.value.volume;
  
  /// Check if playing
  bool get isPlaying => _controller.value.isPlaying;
  
  /// Reload the stream (forces re-fetch of HLS manifest)
  void reload() => _onReload();
  
  /// Set playback speed (for catch-up in low latency mode)
  Future<void> setPlaybackSpeed(double speed) => _controller.setPlaybackSpeed(speed);
}

class TwitchVideoWidget extends StatefulWidget {
  final String hlsUrl;
  final bool hasAudio;
  final void Function(TwitchPlayerController controller)? onControllerReady;
  
  /// Integrity session for authenticated playback.
  /// If provided, the player will include Client-Integrity and Cookie headers.
  final TwitchSession? integritySession;
  
  const TwitchVideoWidget({
    super.key,
    required this.hlsUrl,
    this.hasAudio = true,
    this.onControllerReady,
    this.integritySession,
  });

  @override
  State<TwitchVideoWidget> createState() => _TwitchVideoWidgetState();
}

class _TwitchVideoWidgetState extends State<TwitchVideoWidget> {
  late VideoPlayerController _controller;
  TwitchPlayerController? _twitchController;
  bool _initialized = false;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    // Register fvp as the video backend for HW acceleration
    fvp.registerWith();
    _initializePlayer();
  }
  
  Future<void> _initializePlayer() async {
    print('[VideoWidget] Initializing player with URL: '
        '${widget.hlsUrl.substring(0, 80)}...');
    
    // Build HTTP headers - MUST match the harvester User-Agent exactly
    final headers = <String, String>{
      'User-Agent': kBrowserUserAgent,
    };
    
    // Add integrity headers if session is available
    if (widget.integritySession != null) {
      final session = widget.integritySession!;
      headers['Client-ID'] = session.clientId;
      headers['Client-Integrity'] = session.integrityToken;
      headers['X-Device-Id'] = session.deviceId;
      
      if (session.authorization != null) {
        headers['Authorization'] = session.authorization!;
      }
      
      if (session.cookieString.isNotEmpty) {
        headers['Cookie'] = session.cookieString;
      }
      
      print('[VideoWidget] Using integrity session for playback');
    } else {
      print('[VideoWidget] No integrity session - playback may fail');
    }
    
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.hlsUrl),
      httpHeaders: headers,
    );
    
    try {
      await _controller.initialize();
      print('[VideoWidget] Player initialized successfully');
      _controller.setVolume(widget.hasAudio ? 1.0 : 0.0);
      await _controller.play();
      
      // Create the controller wrapper and notify
      _twitchController = TwitchPlayerController(_controller, _reload);
      widget.onControllerReady?.call(_twitchController!);
      
      setState(() {
        _initialized = true;
      });
    } catch (e) {
      print('[VideoWidget] Error initializing player: $e');
      
      // Check if this is likely an offline channel error
      final errorString = e.toString();
      String userFriendlyError;
      
      if (errorString.contains('media open error') || 
          errorString.contains('invalid or unsupported media')) {
        userFriendlyError = 'Channel appears to be offline';
      } else {
        userFriendlyError = errorString;
      }
      
      setState(() {
        _error = userFriendlyError;
      });
    }
  }
  
  @override
  void didUpdateWidget(TwitchVideoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.hlsUrl != widget.hlsUrl) {
      _controller.dispose();
      _initializePlayer();
    }
    
    if (oldWidget.hasAudio != widget.hasAudio) {
      _controller.setVolume(widget.hasAudio ? 1.0 : 0.0);
    }
  }
  
  void _reload() {
    _controller.dispose();
    setState(() {
      _initialized = false;
      _error = null;
    });
    _initializePlayer();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      // Check if it's an offline error for better UI
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
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
    
    if (!_initialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.purple),
      );
    }
    
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    );
  }
}
