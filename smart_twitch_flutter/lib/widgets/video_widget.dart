import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:fvp/fvp.dart' as fvp;

class TwitchVideoWidget extends StatefulWidget {
  final String hlsUrl;
  final bool hasAudio;
  
  const TwitchVideoWidget({
    super.key,
    required this.hlsUrl,
    this.hasAudio = true,
  });

  @override
  State<TwitchVideoWidget> createState() => _TwitchVideoWidgetState();
}

class _TwitchVideoWidgetState extends State<TwitchVideoWidget> {
  late VideoPlayerController _controller;
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
    print('[VideoWidget] Initializing player with URL: ${widget.hlsUrl.substring(0, 80)}...');
    
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.hlsUrl),
      httpHeaders: const {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
      },
    );
    
    try {
      await _controller.initialize();
      print('[VideoWidget] Player initialized successfully');
      _controller.setVolume(widget.hasAudio ? 1.0 : 0.0);
      await _controller.play();
      
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
