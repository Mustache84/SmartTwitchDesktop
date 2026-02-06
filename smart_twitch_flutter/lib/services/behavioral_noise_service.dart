/// Behavioral Noise Service - Session Persistence & Anti-Detection
///
/// This service creates "noise" in the Ghost Browser to maintain session
/// validity and mimic real user behavior. It prevents Twitch from detecting
/// automated access patterns.
///
/// Features:
/// 1. Shadow Navigation: Navigates to channel-specific pages when user watches
/// 2. Heartbeat: Periodic JS actions to maintain "user presence"
///
/// Architecture:
/// - Listens to MultiStreamState to detect current viewing
/// - Controls TwitchIntegrityService's Ghost Browser
/// - Randomized timers to avoid detection patterns
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_twitch_flutter/core/di/service_locator.dart';
import 'package:smart_twitch_flutter/services/twitch_integrity_service.dart';
import 'package:smart_twitch_flutter/state/multi_stream_state.dart';

/// Configuration for behavioral noise patterns
class BehavioralNoiseConfig {
  BehavioralNoiseConfig._();

  /// Minimum interval between heartbeats (3 minutes)
  static const Duration heartbeatMinInterval = Duration(minutes: 3);

  /// Maximum interval between heartbeats (7 minutes)
  static const Duration heartbeatMaxInterval = Duration(minutes: 7);

  /// Delay before shadow navigation after channel change (seconds)
  static const Duration shadowNavigationDelay = Duration(seconds: 2);

  /// URL template for shadow navigation (popout chat - lightweight)
  static String getChatPopoutUrl(String channelLogin) =>
      'https://www.twitch.tv/popout/${channelLogin.toLowerCase()}/chat';

  /// Alternative: Channel page without autoplay
  static String getChannelUrl(String channelLogin) =>
      'https://www.twitch.tv/${channelLogin.toLowerCase()}';

  /// Heartbeat JavaScript actions (harmless, maintains presence)
  static const List<String> heartbeatScripts = [
    // Minimal scroll action
    'window.scrollBy(0, 10); window.scrollBy(0, -10);',
    // Focus check
    'document.hasFocus();',
    // Timestamp update (mimics tab activity)
    'Date.now();',
    // Mouse movement simulation (lightweight)
    '''
    (function() {
      var event = new MouseEvent('mousemove', {
        clientX: Math.random() * 100,
        clientY: Math.random() * 100
      });
      document.dispatchEvent(event);
    })();
    ''',
  ];
}

/// Service that generates behavioral noise in the Ghost Browser.
///
/// Usage:
/// ```dart
/// final noiseService = BehavioralNoiseService(integrityService);
/// noiseService.start(ref); // Pass Riverpod ref to listen to state
/// // ... app running ...
/// noiseService.stop(); // On app close
/// ```
class BehavioralNoiseService {
  final TwitchIntegrityService _integrityService;
  final Random _random = Random();

  /// Timer for heartbeat actions
  Timer? _heartbeatTimer;

  /// Timer for delayed shadow navigation
  Timer? _shadowNavTimer;

  /// Subscription to stream state changes
  ProviderSubscription<List<StreamSlot>>? _streamSubscription;

  /// Currently tracked channel (for shadow navigation)
  String? _currentChannel;

  /// Whether the service is active
  bool _isRunning = false;

  /// Track last heartbeat time for debugging
  DateTime? _lastHeartbeat;

  BehavioralNoiseService(this._integrityService);

  /// Check if the service is running
  bool get isRunning => _isRunning;

  /// Get the currently tracked channel
  String? get currentChannel => _currentChannel;

  /// Get time since last heartbeat
  Duration? get timeSinceLastHeartbeat {
    if (_lastHeartbeat == null) return null;
    return DateTime.now().difference(_lastHeartbeat!);
  }

  /// Start the behavioral noise service.
  ///
  /// [ref] is needed to subscribe to Riverpod state changes.
  void start(Ref ref) {
    if (_isRunning) {
      if (kDebugMode) {
        print('[BehavioralNoise] Already running');
      }
      return;
    }

    _isRunning = true;

    if (kDebugMode) {
      print('[BehavioralNoise] Starting service...');
    }

    // Start heartbeat timer
    _scheduleNextHeartbeat();

    // Subscribe to stream state changes for shadow navigation
    _streamSubscription = ref.listen<List<StreamSlot>>(
      multiStreamProvider,
      (previous, current) => _onStreamStateChanged(previous, current),
      fireImmediately: true,
    );
  }

  /// Stop the behavioral noise service.
  ///
  /// MUST be called on app shutdown to prevent memory leaks.
  void stop() {
    if (!_isRunning) return;

    if (kDebugMode) {
      print('[BehavioralNoise] Stopping service...');
    }

    _isRunning = false;

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _shadowNavTimer?.cancel();
    _shadowNavTimer = null;

    _streamSubscription?.close();
    _streamSubscription = null;

    _currentChannel = null;
  }

  /// Dispose resources (alias for stop)
  void dispose() => stop();

  // ===========================================================================
  // HEARTBEAT IMPLEMENTATION
  // ===========================================================================

  /// Schedule the next heartbeat with randomized interval.
  void _scheduleNextHeartbeat() {
    if (!_isRunning) return;

    // Random interval between 3-7 minutes
    final minMs = BehavioralNoiseConfig.heartbeatMinInterval.inMilliseconds;
    final maxMs = BehavioralNoiseConfig.heartbeatMaxInterval.inMilliseconds;
    final intervalMs = minMs + _random.nextInt(maxMs - minMs);
    final interval = Duration(milliseconds: intervalMs);

    if (kDebugMode) {
      print('[BehavioralNoise] Next heartbeat in ${interval.inMinutes}m '
          '${interval.inSeconds % 60}s');
    }

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer(interval, _executeHeartbeat);
  }

  /// Execute a heartbeat action.
  Future<void> _executeHeartbeat() async {
    if (!_isRunning) return;

    // Check if integrity service is ready
    if (!_integrityService.isReady) {
      if (kDebugMode) {
        print('[BehavioralNoise] Skipping heartbeat - integrity not ready');
      }
      _scheduleNextHeartbeat();
      return;
    }

    // Pick a random heartbeat script
    final script = BehavioralNoiseConfig.heartbeatScripts[
        _random.nextInt(BehavioralNoiseConfig.heartbeatScripts.length)];

    if (kDebugMode) {
      print('[Noise] ❤️ Executing heartbeat action');
    }

    try {
      await _integrityService.executeJavaScript(script);
      _lastHeartbeat = DateTime.now();

      if (kDebugMode) {
        print('[Noise] ❤️ Heartbeat executed successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[Noise] ❌ Heartbeat error: $e');
      }
    }

    // Schedule next heartbeat
    _scheduleNextHeartbeat();
  }

  // ===========================================================================
  // SHADOW NAVIGATION IMPLEMENTATION
  // ===========================================================================

  /// Handle stream state changes for shadow navigation.
  void _onStreamStateChanged(
    List<StreamSlot>? previous,
    List<StreamSlot> current,
  ) {
    // Find the primary channel (the one with audio, or first active)
    final primarySlot = current.firstWhere(
      (s) => s.hasAudio && s.isActive,
      orElse: () => current.firstWhere(
        (s) => s.isActive,
        orElse: () => const StreamSlot(position: -1),
      ),
    );

    final newChannel = primarySlot.channelLogin;

    // No change needed
    if (newChannel == _currentChannel) return;

    // Channel changed - schedule shadow navigation
    _currentChannel = newChannel;

    if (newChannel == null) {
      if (kDebugMode) {
        print('[BehavioralNoise] No active channel');
      }
      return;
    }

    if (kDebugMode) {
      print('[BehavioralNoise] Channel changed to: $newChannel');
    }

    // Debounce navigation to avoid rapid changes
    _shadowNavTimer?.cancel();
    _shadowNavTimer = Timer(
      BehavioralNoiseConfig.shadowNavigationDelay,
      () => _executeShadowNavigation(newChannel),
    );
  }

  /// Execute shadow navigation to the channel's chat popout.
  Future<void> _executeShadowNavigation(String channelLogin) async {
    if (!_isRunning) return;

    // Check if integrity service is ready
    if (!_integrityService.isReady) {
      if (kDebugMode) {
        print('[BehavioralNoise] Skipping shadow nav - integrity not ready');
      }
      return;
    }

    final url = BehavioralNoiseConfig.getChatPopoutUrl(channelLogin);

    if (kDebugMode) {
      print('[Noise] 👻 Shadow navigating to: $url');
    }

    try {
      await _integrityService.loadUrl(url);

      if (kDebugMode) {
        print('[Noise] 👻 Shadow navigation complete');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[Noise] ❌ Shadow navigation error: $e');
      }
    }
  }

  /// Manually trigger shadow navigation (for testing/debugging).
  Future<void> navigateToChannel(String channelLogin) async {
    await _executeShadowNavigation(channelLogin);
  }

  /// Force a heartbeat (for testing/debugging).
  Future<void> forceHeartbeat() async {
    await _executeHeartbeat();
  }
}

// =============================================================================
// RIVERPOD PROVIDERS
// =============================================================================

/// Provider for the BehavioralNoiseService.
///
/// This provider creates the service and manages its lifecycle.
/// It automatically starts when first accessed and stops on dispose.
final behavioralNoiseServiceProvider = Provider<BehavioralNoiseService>((ref) {
  // Get the integrity service from ServiceLocator
  final integrityService = sl<TwitchIntegrityService>();
  
  final service = BehavioralNoiseService(integrityService);

  // Start the service
  service.start(ref);

  // Stop on dispose
  ref.onDispose(() {
    service.stop();
  });

  return service;
});

/// Provider that exposes just the TwitchIntegrityService from ServiceLocator.
///
/// This provides access to the shared instance.
final integrityServiceProvider = Provider<TwitchIntegrityService>((ref) {
  return sl<TwitchIntegrityService>();
});

/// Provider for checking if behavioral noise is active.
final isBehavioralNoiseActiveProvider = Provider<bool>((ref) {
  final service = ref.watch(behavioralNoiseServiceProvider);
  return service.isRunning;
});

/// Provider for the currently tracked channel.
final behavioralNoiseChannelProvider = Provider<String?>((ref) {
  final service = ref.watch(behavioralNoiseServiceProvider);
  return service.currentChannel;
});
