import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/low_latency_service.dart';
import '../services/settings_service.dart';

/// A slider widget for controlling stream latency.
///
/// Allows selection from 0.5s to 10s with preset quick-picks.
/// Persists settings via SettingsService.
class LatencySlider extends ConsumerStatefulWidget {
  const LatencySlider({
    super.key,
    this.onLatencyChanged,
    this.onLowLatencyModeChanged,
    this.compact = false,
  });

  /// Callback when latency target is changed
  final void Function(double seconds)? onLatencyChanged;

  /// Callback when low latency mode is toggled
  final void Function(bool enabled)? onLowLatencyModeChanged;

  /// Whether to show a compact version
  final bool compact;

  @override
  ConsumerState<LatencySlider> createState() => _LatencySliderState();
}

class _LatencySliderState extends ConsumerState<LatencySlider> {
  late double _latencyTarget;
  late bool _lowLatencyMode;

  @override
  void initState() {
    super.initState();
    _latencyTarget = SettingsService.instance.latencyTarget;
    _lowLatencyMode = SettingsService.instance.lowLatencyMode;
  }

  Future<void> _setLatencyTarget(double seconds) async {
    setState(() {
      _latencyTarget = seconds;
    });

    await LowLatencyService.instance.setLatencyTarget(seconds);
    widget.onLatencyChanged?.call(seconds);
  }

  Future<void> _setLowLatencyMode(bool enabled) async {
    setState(() {
      _lowLatencyMode = enabled;
    });

    await LowLatencyService.instance.setLowLatencyMode(enabled);
    widget.onLowLatencyModeChanged?.call(enabled);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompact();
    }
    return _buildFull();
  }

  Widget _buildCompact() {
    return PopupMenuButton<dynamic>(
      icon: Icon(
        _lowLatencyMode ? Icons.speed : Icons.speed_outlined,
        size: 20,
        color: _lowLatencyMode ? Colors.green : null,
      ),
      tooltip:
          'Latency: ${LowLatencyService.formatLatency(_latencyTarget)}',
      itemBuilder: (context) => [
        // Low latency mode toggle
        PopupMenuItem<bool>(
          value: !_lowLatencyMode,
          child: Row(
            children: [
              Icon(
                _lowLatencyMode ? Icons.check_box : Icons.check_box_outline_blank,
                size: 20,
                color: _lowLatencyMode ? Colors.green : null,
              ),
              const SizedBox(width: 8),
              const Text('Low Latency Mode'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        // Preset options
        ...LowLatencyService.presets.map((preset) {
          final isSelected =
              (_latencyTarget - preset.seconds).abs() < 0.01;
          return PopupMenuItem<double>(
            value: preset.seconds,
            enabled: _lowLatencyMode,
            child: Row(
              children: [
                if (isSelected)
                  const Icon(Icons.radio_button_checked,
                      size: 16, color: Colors.green)
                else
                  const Icon(Icons.radio_button_unchecked, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(preset.name),
                      Text(
                        LowLatencyService.formatLatency(preset.seconds),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
      onSelected: (value) {
        if (value is bool) {
          _setLowLatencyMode(value);
        } else if (value is double) {
          _setLatencyTarget(value);
        }
      },
    );
  }

  Widget _buildFull() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Low latency mode toggle
          Row(
            children: [
              Switch(
                value: _lowLatencyMode,
                onChanged: _setLowLatencyMode,
                activeColor: Colors.green,
              ),
              const SizedBox(width: 8),
              const Text(
                'Low Latency Mode',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Latency slider
          if (_lowLatencyMode) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Target Latency',
                  style: TextStyle(color: Colors.white70),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    LowLatencyService.formatLatency(_latencyTarget),
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.green,
                inactiveTrackColor: Colors.grey[700],
                thumbColor: Colors.green,
                overlayColor: Colors.green.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: _latencyTarget,
                min: 0.5,
                max: 10.0,
                divisions: 19, // 0.5 step increments
                label: LowLatencyService.formatLatency(_latencyTarget),
                onChanged: (value) {
                  setState(() {
                    _latencyTarget = value;
                  });
                },
                onChangeEnd: _setLatencyTarget,
              ),
            ),
            const SizedBox(height: 8),

            // Preset buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: LowLatencyService.presets.map((preset) {
                final isSelected =
                    (_latencyTarget - preset.seconds).abs() < 0.01;
                return ActionChip(
                  label: Text(preset.name),
                  backgroundColor:
                      isSelected ? Colors.green : Colors.grey[800],
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[300],
                    fontSize: 12,
                  ),
                  onPressed: () => _setLatencyTarget(preset.seconds),
                );
              }).toList(),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Enable Low Latency Mode for buffer control',
                style: TextStyle(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}

/// A simple toggle button for low latency mode
class LowLatencyToggle extends ConsumerStatefulWidget {
  const LowLatencyToggle({
    super.key,
    this.onChanged,
  });

  final void Function(bool enabled)? onChanged;

  @override
  ConsumerState<LowLatencyToggle> createState() => _LowLatencyToggleState();
}

class _LowLatencyToggleState extends ConsumerState<LowLatencyToggle> {
  late bool _lowLatencyMode;

  @override
  void initState() {
    super.initState();
    _lowLatencyMode = SettingsService.instance.lowLatencyMode;
  }

  Future<void> _toggle() async {
    final newValue = !_lowLatencyMode;
    setState(() {
      _lowLatencyMode = newValue;
    });

    await LowLatencyService.instance.setLowLatencyMode(newValue);
    widget.onChanged?.call(newValue);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _lowLatencyMode ? Icons.flash_on : Icons.flash_off,
        color: _lowLatencyMode ? Colors.yellow : null,
      ),
      tooltip: _lowLatencyMode ? 'Low Latency: ON' : 'Low Latency: OFF',
      onPressed: _toggle,
    );
  }
}
