import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/hls_manifest_service.dart';
import '../services/settings_service.dart';

/// A dropdown widget for selecting stream quality.
///
/// Displays available qualities from the HLS manifest and
/// persists selection per-channel via SettingsService.
class QualitySelector extends ConsumerStatefulWidget {
  const QualitySelector({
    super.key,
    required this.channelLogin,
    required this.masterPlaylistUrl,
    this.onQualityChanged,
    this.compact = false,
  });

  /// The channel login (for per-channel quality storage)
  final String channelLogin;

  /// The HLS master playlist URL to parse for qualities
  final String masterPlaylistUrl;

  /// Callback when quality is changed
  final void Function(QualityOption quality)? onQualityChanged;

  /// Whether to show a compact version (icon only)
  final bool compact;

  @override
  ConsumerState<QualitySelector> createState() => _QualitySelectorState();
}

class _QualitySelectorState extends ConsumerState<QualitySelector> {
  final HlsManifestService _manifestService = HlsManifestService();
  List<QualityOption> _qualities = [];
  QualityOption? _selectedQuality;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQualities();
  }

  @override
  void didUpdateWidget(QualitySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.masterPlaylistUrl != widget.masterPlaylistUrl) {
      _loadQualities();
    }
  }

  Future<void> _loadQualities() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final qualities =
          await _manifestService.getQualityOptions(widget.masterPlaylistUrl);

      if (!mounted) return;

      // Get saved quality for this channel
      final savedQuality =
          SettingsService.instance.getEffectiveQuality(widget.channelLogin);

      // Find matching quality or default to 'auto'
      QualityOption? selected;
      selected = qualities.firstWhere(
        (q) => q.id == savedQuality,
        orElse: () => qualities.first,
      );

      setState(() {
        _qualities = qualities;
        _selectedQuality = selected ?? qualities.firstOrNull;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectQuality(QualityOption quality) async {
    setState(() {
      _selectedQuality = quality;
    });

    // Save to settings
    if (quality.isAuto) {
      await SettingsService.instance.setChannelQuality(widget.channelLogin, null);
    } else {
      await SettingsService.instance.setChannelQuality(widget.channelLogin, quality.id);
    }

    widget.onQualityChanged?.call(quality);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.compact
          ? const SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
    }

    if (_error != null || _qualities.isEmpty) {
      return widget.compact
          ? IconButton(
              icon: const Icon(Icons.settings, size: 20),
              onPressed: _loadQualities,
              tooltip: 'Quality unavailable',
            )
          : TextButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              onPressed: _loadQualities,
            );
    }

    if (widget.compact) {
      return _buildCompactSelector();
    }

    return _buildFullSelector();
  }

  Widget _buildCompactSelector() {
    return PopupMenuButton<QualityOption>(
      icon: const Icon(Icons.settings, size: 20),
      tooltip: 'Quality: ${_selectedQuality?.label ?? 'Auto'}',
      onSelected: _selectQuality,
      itemBuilder: (context) => _qualities.map((quality) {
        final isSelected = quality.id == _selectedQuality?.id;
        return PopupMenuItem<QualityOption>(
          value: quality,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected)
                const Icon(Icons.check, size: 16)
              else
                const SizedBox(width: 16),
              const SizedBox(width: 8),
              Text(quality.label),
              const SizedBox(width: 8),
              Text(
                _formatBitrate(quality.bandwidth),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFullSelector() {
    return DropdownButton<QualityOption>(
      value: _selectedQuality,
      underline: const SizedBox(),
      dropdownColor: Colors.grey[900],
      items: _qualities.map((quality) {
        return DropdownMenuItem<QualityOption>(
          value: quality,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                quality.label,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(
                _formatBitrate(quality.bandwidth),
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (quality) {
        if (quality != null) {
          _selectQuality(quality);
        }
      },
    );
  }

  /// Format bandwidth for display
  String _formatBitrate(int? bandwidth) {
    if (bandwidth == null) return '';
    final mbps = bandwidth / 1000000;
    if (mbps >= 1) {
      return '${mbps.toStringAsFixed(1)} Mbps';
    }
    final kbps = bandwidth / 1000;
    return '${kbps.toStringAsFixed(0)} kbps';
  }
}
