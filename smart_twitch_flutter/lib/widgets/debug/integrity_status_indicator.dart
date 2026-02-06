/// Integrity Status Indicator Widget
///
/// Visual indicator for the Twitch Integrity Infrastructure status.
/// Shows a colored dot with tooltip details for debugging.
///
/// States:
/// - 🔴 Red: Error / Not Initialized
/// - 🟡 Orange: Harvesting (WebView Loading)
/// - 🟢 Green: Ready (Tokens Valid)
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_twitch_flutter/services/behavioral_noise_service.dart';
import 'package:smart_twitch_flutter/state/integrity_provider.dart';

/// Colors for integrity status states
class IntegrityStatusColors {
  IntegrityStatusColors._();

  static const Color ready = Color(0xFF4CAF50); // Green
  static const Color loading = Color(0xFFFF9800); // Orange
  static const Color error = Color(0xFFF44336); // Red
  static const Color initial = Color(0xFF9E9E9E); // Grey
}

/// Compact status indicator for the integrity service.
///
/// Displays a colored dot showing the current state of token harvesting.
/// On hover, shows a tooltip with detailed status information.
/// On click, shows a dialog with full debug details.
class IntegrityStatusIndicator extends ConsumerStatefulWidget {
  /// Whether to show the indicator only in debug mode
  final bool debugModeOnly;

  /// Size of the status dot
  final double size;

  const IntegrityStatusIndicator({
    super.key,
    this.debugModeOnly = true,
    this.size = 12.0,
  });

  @override
  ConsumerState<IntegrityStatusIndicator> createState() =>
      _IntegrityStatusIndicatorState();
}

class _IntegrityStatusIndicatorState
    extends ConsumerState<IntegrityStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Hide in release mode if debugModeOnly is true
    if (widget.debugModeOnly && !kDebugMode) {
      return const SizedBox.shrink();
    }

    final integrityState = ref.watch(integrityProvider);
    final noiseService = ref.watch(behavioralNoiseServiceProvider);

    // Determine color and pulse state
    final (color, shouldPulse, statusText) = _getStatusInfo(integrityState);

    // Control pulse animation
    if (shouldPulse && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!shouldPulse && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }

    return Tooltip(
      message: _buildTooltipMessage(integrityState, noiseService),
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: () => _showDetailsDialog(context, integrityState, noiseService),
        borderRadius: BorderRadius.circular(widget.size),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              final scale = shouldPulse ? _pulseAnimation.value : 1.0;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Get status color, pulse state, and text based on integrity state
  (Color, bool, String) _getStatusInfo(IntegrityState state) {
    return switch (state) {
      IntegrityInitial() => (
          IntegrityStatusColors.initial,
          false,
          'Not Started',
        ),
      IntegrityLoading(needsVisibleWebView: final fallback) => (
          IntegrityStatusColors.loading,
          true,
          fallback ? 'Fallback Mode' : 'Harvesting...',
        ),
      IntegrityReady(session: final session) => (
          session.isExpired
              ? IntegrityStatusColors.loading
              : IntegrityStatusColors.ready,
          session.isExpired,
          session.isExpired ? 'Token Expired' : 'Ready',
        ),
      IntegrityError() => (
          IntegrityStatusColors.error,
          false,
          'Error',
        ),
    };
  }

  /// Build tooltip message with quick status info
  String _buildTooltipMessage(
    IntegrityState state,
    BehavioralNoiseService noiseService,
  ) {
    final (_, _, statusText) = _getStatusInfo(state);
    final lines = <String>['Integrity: $statusText'];

    if (state is IntegrityReady) {
      final session = state.session;
      final age = DateTime.now().difference(session.createdAt);
      lines.add('Token Age: ${_formatDuration(age)}');
    }

    final heartbeatAge = noiseService.timeSinceLastHeartbeat;
    if (heartbeatAge != null) {
      lines.add('Last Heartbeat: ${_formatDuration(heartbeatAge)}');
    }

    if (noiseService.currentChannel != null) {
      lines.add('Tracking: ${noiseService.currentChannel}');
    }

    return lines.join('\n');
  }

  /// Show detailed dialog with full status info
  void _showDetailsDialog(
    BuildContext context,
    IntegrityState state,
    BehavioralNoiseService noiseService,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _getStatusInfo(state).$1,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Integrity Status',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusSection(state),
              const Divider(color: Colors.white24),
              _buildNoiseSection(noiseService),
              const Divider(color: Colors.white24),
              _buildActionsSection(context),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Build the integrity status section
  Widget _buildStatusSection(IntegrityState state) {
    final rows = <Widget>[];
    final (color, _, statusText) = _getStatusInfo(state);

    rows.add(_buildDetailRow('Status', statusText, color: color));

    if (state is IntegrityReady) {
      final session = state.session;
      final age = DateTime.now().difference(session.createdAt);

      rows.add(_buildDetailRow(
        'Client ID',
        '${session.clientId.substring(0, 8)}...',
      ));
      rows.add(_buildDetailRow(
        'Integrity Token',
        session.integrityToken.isNotEmpty
            ? '${session.integrityToken.substring(0, 12)}...'
            : 'None',
      ));
      rows.add(_buildDetailRow('Device ID', '${session.deviceId.substring(0, 8)}...'));
      rows.add(_buildDetailRow('Token Age', _formatDuration(age)));
      rows.add(_buildDetailRow(
        'Has Auth',
        session.authorization != null ? 'Yes' : 'No',
      ));
      rows.add(_buildDetailRow(
        'Cookies',
        '${session.cookieString.length} chars',
      ));
    } else if (state is IntegrityLoading) {
      rows.add(_buildDetailRow(
        'Mode',
        state.needsVisibleWebView ? 'Visible Fallback' : 'Headless',
      ));
    } else if (state is IntegrityError) {
      rows.add(_buildDetailRow('Error', state.message, color: Colors.red));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Token Harvesting',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...rows,
      ],
    );
  }

  /// Build the behavioral noise section
  Widget _buildNoiseSection(BehavioralNoiseService noiseService) {
    final rows = <Widget>[];

    rows.add(_buildDetailRow(
      'Service',
      noiseService.isRunning ? 'Running' : 'Stopped',
      color: noiseService.isRunning
          ? IntegrityStatusColors.ready
          : IntegrityStatusColors.error,
    ));

    final heartbeatAge = noiseService.timeSinceLastHeartbeat;
    rows.add(_buildDetailRow(
      'Last Heartbeat',
      heartbeatAge != null ? '${_formatDuration(heartbeatAge)} ago' : 'Never',
    ));

    rows.add(_buildDetailRow(
      'Tracking Channel',
      noiseService.currentChannel ?? 'None',
    ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Behavioral Noise',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...rows,
      ],
    );
  }

  /// Build actions section with debug buttons
  Widget _buildActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actions',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _buildActionButton(
              'Refresh Token',
              Icons.refresh,
              () {
                ref.read(integrityProvider.notifier).refresh();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🔄 Refreshing integrity token...'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            _buildActionButton(
              'Force Heartbeat',
              Icons.favorite,
              () {
                ref.read(behavioralNoiseServiceProvider).forceHeartbeat();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❤️ Heartbeat sent!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color ?? Colors.white,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        backgroundColor: Colors.white10,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}

/// Compact version for sidebar (just the dot)
class IntegrityStatusDot extends ConsumerWidget {
  const IntegrityStatusDot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hide in release mode
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    final integrityState = ref.watch(integrityProvider);

    final color = switch (integrityState) {
      IntegrityInitial() => IntegrityStatusColors.initial,
      IntegrityLoading() => IntegrityStatusColors.loading,
      IntegrityReady(session: final s) =>
        s.isExpired ? IntegrityStatusColors.loading : IntegrityStatusColors.ready,
      IntegrityError() => IntegrityStatusColors.error,
    };

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
