import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/twitch_api_service.dart';
import '../services/low_latency_service.dart';
import '../utils/hls_url_builder.dart';
import '../widgets/video_widget.dart';
import '../widgets/quality_selector.dart';
import '../widgets/latency_slider.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final String channelLogin;
  
  const PlayerScreen({super.key, required this.channelLogin});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  final TwitchApiService _apiService = TwitchApiService();
  String? _hlsUrl;
  String? _error;
  bool _loading = true;
  bool _showControls = true;
  bool _isPlaying = true;
  double _volume = 1.0;
  bool _isMuted = false;
  final FocusNode _keyboardFocusNode = FocusNode();
  TwitchPlayerController? _playerController;
  
  @override
  void initState() {
    super.initState();
    _loadStream();
    // Initialize low latency service
    LowLatencyService.instance.initialize();
  }
  
  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }
  
  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    
    final key = event.logicalKey;
    
    // Space - Play/Pause
    if (key == LogicalKeyboardKey.space) {
      _togglePlayPause();
    }
    
    // M - Mute toggle
    if (key == LogicalKeyboardKey.keyM) {
      _toggleMute();
    }
    
    // L - Toggle low latency mode
    if (key == LogicalKeyboardKey.keyL) {
      _toggleLowLatency();
    }
    
    // H - Hide/show controls
    if (key == LogicalKeyboardKey.keyH) {
      setState(() {
        _showControls = !_showControls;
      });
    }
    
    // Arrow Up - Volume up
    if (key == LogicalKeyboardKey.arrowUp) {
      _adjustVolume(0.1);
    }
    
    // Arrow Down - Volume down
    if (key == LogicalKeyboardKey.arrowDown) {
      _adjustVolume(-0.1);
    }
  }
  
  void _togglePlayPause() {
    if (_playerController == null) return;
    _playerController!.togglePlayPause();
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }
  
  void _toggleMute() {
    if (_playerController == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _playerController!.setVolume(_isMuted ? 0.0 : _volume);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isMuted ? 'Muted' : 'Unmuted'),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }
  
  void _adjustVolume(double delta) {
    if (_playerController == null) return;
    setState(() {
      _volume = (_volume + delta).clamp(0.0, 1.0);
      if (!_isMuted) {
        _playerController!.setVolume(_volume);
      }
    });
  }
  
  void _toggleLowLatency() {
    final currentMode = LowLatencyService.instance.isLowLatencyMode;
    LowLatencyService.instance.setLowLatencyMode(!currentMode);
    setState(() {}); // Refresh UI
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Low Latency: ${!currentMode ? 'ON' : 'OFF'}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }
  
  void _onControllerReady(TwitchPlayerController controller) {
    _playerController = controller;
    setState(() {
      _isPlaying = true;
    });
  }
  
  Future<void> _loadStream() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final token = await _apiService.getPlaybackToken(widget.channelLogin);
      
      final hlsUrl = HlsUrlBuilder.buildStreamUrl(
        channel: widget.channelLogin,
        token: token.token,
        signature: token.signature,
      );
      
      setState(() {
        _hlsUrl = hlsUrl;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: _showControls
            ? AppBar(
                backgroundColor: Colors.grey[900],
                title: Text('Watching: ${widget.channelLogin}'),
                actions: [
                  // Quality selector
                  if (_hlsUrl != null)
                    QualitySelector(
                      channelLogin: widget.channelLogin,
                      masterPlaylistUrl: _hlsUrl!,
                      compact: true,
                      onQualityChanged: (quality) {
                        // TODO: Switch stream to selected quality
                        debugPrint('[PlayerScreen] Quality changed to: ${quality.label}');
                      },
                    ),
                  // Latency controls
                  const LatencySlider(compact: true),
                  // Low latency toggle
                  const LowLatencyToggle(),
                  // Refresh
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Reload stream',
                    onPressed: _loadStream,
                  ),
                ],
              )
            : null,
        body: _buildBody(),
      ),
    );
  }
  
  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.purple),
            SizedBox(height: 16),
            Text('Loading stream...', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }
    
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadStream,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    if (_hlsUrl != null) {
      return Stack(
        children: [
          Center(
            child: TwitchVideoWidget(
              hlsUrl: _hlsUrl!,
              onControllerReady: _onControllerReady,
            ),
          ),
          // Bottom controls overlay
          if (_showControls)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    // Play/Pause button
                    IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                      onPressed: _togglePlayPause,
                      tooltip: _isPlaying ? 'Pause (Space)' : 'Play (Space)',
                    ),
                    // Mute button
                    IconButton(
                      icon: Icon(
                        _isMuted ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white,
                      ),
                      onPressed: _toggleMute,
                      tooltip: _isMuted ? 'Unmute (M)' : 'Mute (M)',
                    ),
                    // Volume slider
                    SizedBox(
                      width: 100,
                      child: Slider(
                        value: _isMuted ? 0.0 : _volume,
                        onChanged: (value) {
                          setState(() {
                            _volume = value;
                            _isMuted = false;
                            _playerController?.setVolume(value);
                          });
                        },
                        activeColor: Colors.white,
                        inactiveColor: Colors.white38,
                      ),
                    ),
                    const Spacer(),
                    // Keyboard shortcut hints
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Space: Play/Pause • M: Mute • L: Low Latency • H: Hide UI • ↑↓: Volume',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }
    
    return const Center(
      child: Text('No stream available', style: TextStyle(color: Colors.white)),
    );
  }
}
