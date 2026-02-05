import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/twitch_api_service.dart';
import '../services/low_latency_service.dart';
import '../utils/hls_url_builder.dart';
import '../core/core.dart';
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
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _loadStream();
    LowLatencyService.instance.initialize();
    _resetHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  /// Reset the auto-hide timer. Called on any user interaction.
  void _resetHideTimer() {
    _hideTimer?.cancel();
    if (!_showControls) {
      setState(() => _showControls = true);
    }
    _hideTimer = Timer(AppDurations.controlsAutoHide, () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    _resetHideTimer();

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.space) {
      _togglePlayPause();
    } else if (key == LogicalKeyboardKey.keyM) {
      _toggleMute();
    } else if (key == LogicalKeyboardKey.keyL) {
      _toggleLowLatency();
    } else if (key == LogicalKeyboardKey.keyH) {
      // Manual toggle - cancel auto-hide when manually shown
      _hideTimer?.cancel();
      setState(() => _showControls = !_showControls);
      if (_showControls) {
        _resetHideTimer();
      }
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _adjustVolume(0.1);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _adjustVolume(-0.1);
    }
  }

  void _togglePlayPause() {
    if (_playerController == null) return;
    _playerController!.togglePlayPause();
    setState(() {
      _isPlaying = !_isPlaying;
    });
    // When paused, keep controls visible
    if (!_isPlaying) {
      _hideTimer?.cancel();
      setState(() => _showControls = true);
    } else {
      _resetHideTimer();
    }
  }

  void _toggleMute() {
    if (_playerController == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _playerController!.setVolume(_isMuted ? 0.0 : _volume);
    });
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
    setState(() {});
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

    if (_hlsUrl == null) {
      return const Center(
        child: Text('No stream available', style: TextStyle(color: Colors.white)),
      );
    }

    return MouseRegion(
      cursor: _showControls ? SystemMouseCursors.basic : SystemMouseCursors.none,
      onHover: (_) => _resetHideTimer(),
      child: GestureDetector(
        onTap: () {
          if (_showControls) {
            _hideTimer?.cancel();
            setState(() => _showControls = false);
          } else {
            _resetHideTimer();
          }
        },
        child: Stack(
          children: [
            // Video player (fills entire screen)
            Center(
              child: TwitchVideoWidget(
                hlsUrl: _hlsUrl!,
                onControllerReady: _onControllerReady,
              ),
            ),
            // Top bar overlay
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: AppDurations.controlsFade,
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: _buildTopBar(),
                ),
              ),
            ),
            // Bottom controls overlay
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: AppDurations.controlsFade,
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: _buildBottomBar(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Back button
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 8),
            // Channel name
            Text(
              widget.channelLogin,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            // Quality selector
            if (_hlsUrl != null)
              QualitySelector(
                channelLogin: widget.channelLogin,
                masterPlaylistUrl: _hlsUrl!,
                compact: true,
                onQualityChanged: (quality) {
                  debugPrint('[PlayerScreen] Quality changed to: ${quality.label}');
                },
              ),
            // Latency controls
            const LatencySlider(compact: true),
            // Low latency toggle
            const LowLatencyToggle(),
            // Refresh
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'Reload stream',
              onPressed: _loadStream,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
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
          // Play/Pause
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
            onPressed: _togglePlayPause,
            tooltip: _isPlaying ? 'Pause (Space)' : 'Play (Space)',
          ),
          // Mute
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
              'Space: Play/Pause  M: Mute  L: Low Latency  H: Toggle UI  \u2191\u2193: Volume',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
