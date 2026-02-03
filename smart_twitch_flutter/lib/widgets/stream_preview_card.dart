import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../models/stream_preview.dart';
import '../utils/ui_config.dart';
import '../services/preview_player_manager.dart';

/// Stream preview card with hover-to-play functionality
/// 
/// Uses centralized PreviewPlayerManager for snappy performance:
/// - Single shared player instance (no recreation)
/// - Token pre-fetching (cache hit = instant)
/// - Same-channel skip (no reload if same stream)
class StreamPreviewCard extends StatefulWidget {
  final StreamPreview stream;
  final VoidCallback? onTap;
  final bool isFocused;
  
  const StreamPreviewCard({
    super.key,
    required this.stream,
    this.onTap,
    this.isFocused = false,
  });

  @override
  State<StreamPreviewCard> createState() => _StreamPreviewCardState();
}

class _StreamPreviewCardState extends State<StreamPreviewCard> {
  bool _isHovered = false;
  Timer? _hoverTimer;
  bool _shouldShowPreview = false;
  
  final PreviewPlayerManager _previewManager = PreviewPlayerManager();
  
  @override
  void initState() {
    super.initState();
    _previewManager.addListener(_onPreviewStateChanged);
  }
  
  @override
  void didUpdateWidget(StreamPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Handle keyboard focus changes
    if (widget.isFocused && !oldWidget.isFocused) {
      _startHoverTimer();
    } else if (!widget.isFocused && oldWidget.isFocused && !_isHovered) {
      _stopPreview();
    }
  }
  
  @override
  void dispose() {
    _hoverTimer?.cancel();
    _previewManager.removeListener(_onPreviewStateChanged);
    // Stop preview if this card was showing it
    if (_shouldShowPreview && _previewManager.currentChannel == widget.stream.login) {
      _previewManager.stopPreview();
    }
    super.dispose();
  }
  
  void _onPreviewStateChanged() {
    if (mounted) setState(() {});
  }
  
  void _startHoverTimer() {
    _hoverTimer?.cancel();
    _hoverTimer = Timer(UIConfig.streamPreviewHoverDelay, () {
      if (mounted && (_isHovered || widget.isFocused)) {
        setState(() => _shouldShowPreview = true);
        _previewManager.startPreview(widget.stream.login);
      }
    });
  }
  
  void _stopPreview() {
    _hoverTimer?.cancel();
    _hoverTimer = null;
    
    if (_shouldShowPreview) {
      setState(() => _shouldShowPreview = false);
      // Only stop if we were the one showing
      if (_previewManager.currentChannel == widget.stream.login) {
        _previewManager.stopPreview();
      }
    }
  }

  /// Check if this card should show the video player
  bool get _showVideoPlayer {
    return _shouldShowPreview && 
           _previewManager.currentChannel == widget.stream.login &&
           _previewManager.controller != null;
  }
  
  /// Check if this card is loading
  bool get _isLoading {
    return _shouldShowPreview && 
           _previewManager.currentChannel == widget.stream.login &&
           _previewManager.isLoading;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _startHoverTimer();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        if (!widget.isFocused) {
          _stopPreview();
        }
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent && 
                event.logicalKey == LogicalKeyboardKey.enter) {
              widget.onTap?.call();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (_isHovered || widget.isFocused) 
                    ? UIConfig.twitchPurple 
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail / Video preview
                  AspectRatio(
                    aspectRatio: UIConfig.streamCardAspectRatio,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Thumbnail image (always shown as base layer)
                        Image.network(
                          widget.stream.previewImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: UIConfig.twitchSurface,
                            child: const Center(
                              child: Icon(Icons.image_not_supported, 
                                  color: Colors.white24),
                            ),
                          ),
                        ),
                        
                        // Video overlay when this card is previewing
                        if (_showVideoPlayer)
                          AspectRatio(
                            aspectRatio: _previewManager.controller!.value.aspectRatio > 0 
                                ? _previewManager.controller!.value.aspectRatio 
                                : 16 / 9,
                            child: VideoPlayer(_previewManager.controller!),
                          ),
                        
                        // Loading indicator
                        if (_isLoading)
                          Container(
                            color: Colors.black45,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: UIConfig.twitchPurple,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        
                        // Error indicator
                        if (_shouldShowPreview && 
                            _previewManager.currentChannel == widget.stream.login &&
                            _previewManager.error != null)
                          Container(
                            color: Colors.black45,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.tv_off, color: Colors.grey, size: 24),
                                  const SizedBox(height: 4),
                                  Text(
                                    _previewManager.error!,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        
                        // Live badge
                        Positioned(
                          left: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: UIConfig.liveIndicatorRed,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        
                        // Viewer count
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person, 
                                    color: Colors.red, size: 12),
                                const SizedBox(width: 2),
                                Text(
                                  widget.stream.formattedViewers,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Uptime
                        if (widget.stream.uptime != null)
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                widget.stream.uptime!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Stream info below thumbnail
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: UIConfig.twitchSurface,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Streamer avatar
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: UIConfig.twitchPurple,
                          backgroundImage: widget.stream.profileImageUrl.isNotEmpty
                              ? NetworkImage(widget.stream.profileImageUrl)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        
                        // Stream details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title
                              Text(
                                widget.stream.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              
                              // Streamer name
                              Row(
                                children: [
                                  Text(
                                    widget.stream.displayName,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (widget.stream.isPartner)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Icon(
                                        Icons.verified,
                                        color: UIConfig.twitchPurple,
                                        size: 14,
                                      ),
                                    ),
                                ],
                              ),
                              
                              // Game name
                              if (widget.stream.gameName != null)
                                Text(
                                  widget.stream.gameName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
