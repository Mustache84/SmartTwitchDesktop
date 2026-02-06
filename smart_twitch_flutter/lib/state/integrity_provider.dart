/// Integrity Provider - Riverpod state management for TwitchIntegrityService
///
/// This provider exposes the integrity session to the rest of the app,
/// handling initialization, refresh, and error states.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_twitch_flutter/core/di/service_locator.dart';
import 'package:smart_twitch_flutter/models/twitch_session.dart';
import 'package:smart_twitch_flutter/services/twitch_integrity_service.dart';

/// State for integrity harvesting
sealed class IntegrityState {
  const IntegrityState();
}

/// Initial state before harvesting begins
class IntegrityInitial extends IntegrityState {
  const IntegrityInitial();
}

/// Harvesting is in progress
class IntegrityLoading extends IntegrityState {
  /// Whether we've fallen back to visible webview mode
  final bool needsVisibleWebView;

  const IntegrityLoading({this.needsVisibleWebView = false});
}

/// Successfully harvested a session
class IntegrityReady extends IntegrityState {
  final TwitchSession session;

  const IntegrityReady(this.session);
}

/// Failed to harvest session
class IntegrityError extends IntegrityState {
  final String message;
  final Object? error;

  const IntegrityError(this.message, {this.error});
}

/// Notifier for managing integrity state
class IntegrityNotifier extends Notifier<IntegrityState> {
  late final TwitchIntegrityService _service;
  
  @override
  IntegrityState build() {
    // Use ServiceLocator to get the shared instance
    _service = sl<TwitchIntegrityService>();
    
    // Listen for visible webview fallback requests
    _service.onNeedsVisibleWebView = (needsVisible) {
      if (needsVisible) {
        state = const IntegrityLoading(needsVisibleWebView: true);
      }
    };
    
    // Listen for session updates
    _service.onSessionUpdate = (session) {
      state = IntegrityReady(session);
    };
    
    // Note: Don't dispose here - ServiceLocator manages lifecycle
    
    return const IntegrityInitial();
  }
  
  /// Get the underlying service (for visible webview fallback)
  TwitchIntegrityService get service => _service;
  
  /// Initialize the integrity service and begin harvesting.
  ///
  /// This should be called early in the app lifecycle.
  Future<void> initialize() async {
    if (state is IntegrityLoading || state is IntegrityReady) {
      return; // Already initializing or ready
    }
    
    state = const IntegrityLoading();
    
    try {
      final session = await _service.initialize();
      state = IntegrityReady(session);
    } catch (e) {
      if (kDebugMode) {
        print('[IntegrityNotifier] Initialization error: $e');
      }
      state = IntegrityError('Failed to initialize integrity service', error: e);
    }
  }
  
  /// Refresh the session (force re-harvest).
  ///
  /// Call this when a 403 is received from Twitch API.
  Future<void> refresh() async {
    state = const IntegrityLoading();
    
    try {
      final session = await _service.refresh();
      state = IntegrityReady(session);
    } catch (e) {
      if (kDebugMode) {
        print('[IntegrityNotifier] Refresh error: $e');
      }
      state = IntegrityError('Failed to refresh integrity session', error: e);
    }
  }
  
  /// Get the current session, initializing if necessary.
  ///
  /// Returns null if not ready or error occurred.
  Future<TwitchSession?> getSession() async {
    final currentState = state;
    
    if (currentState is IntegrityReady) {
      final session = currentState.session;
      
      // Check if we should proactively refresh
      if (session.shouldRefresh) {
        await refresh();
        final newState = state;
        return newState is IntegrityReady ? newState.session : null;
      }
      
      return session;
    }
    
    // Not ready, try to initialize
    await initialize();
    final newState = state;
    return newState is IntegrityReady ? newState.session : null;
  }
  
  /// Mark that visible webview completed its harvest
  void onVisibleWebViewReady() {
    if (_service.isReady) {
      state = IntegrityReady(_service.currentSession!);
    }
  }
}

/// Main integrity provider
final integrityProvider = NotifierProvider<IntegrityNotifier, IntegrityState>(
  IntegrityNotifier.new,
);

/// Convenience provider for getting the current session
final integritySessionProvider = Provider<TwitchSession?>((ref) {
  final state = ref.watch(integrityProvider);
  
  if (state is IntegrityReady) {
    return state.session;
  }
  
  return null;
});

/// Provider for checking if integrity is ready
final isIntegrityReadyProvider = Provider<bool>((ref) {
  final state = ref.watch(integrityProvider);
  return state is IntegrityReady;
});

/// Provider for checking if visible webview fallback is needed
final needsVisibleWebViewProvider = Provider<bool>((ref) {
  final state = ref.watch(integrityProvider);
  return state is IntegrityLoading && state.needsVisibleWebView;
});

/// Extension to get integrity session in a simple way
extension IntegrityRefExtension on WidgetRef {
  /// Get the current integrity session, or null if not ready.
  TwitchSession? get integritySession {
    final state = watch(integrityProvider);
    return state is IntegrityReady ? state.session : null;
  }
  
  /// Wait for the integrity session to be ready.
  Future<TwitchSession?> waitForIntegrity() async {
    return read(integrityProvider.notifier).getSession();
  }
}
