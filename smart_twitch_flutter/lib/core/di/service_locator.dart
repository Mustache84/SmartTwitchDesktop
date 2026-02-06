import 'package:get_it/get_it.dart' hide Disposable;
import 'package:smart_twitch_flutter/core/interfaces/disposable.dart';
import 'package:smart_twitch_flutter/services/hls_manifest_service.dart';
import 'package:smart_twitch_flutter/services/low_latency_service.dart';
import 'package:smart_twitch_flutter/services/preview_player_manager.dart';
import 'package:smart_twitch_flutter/services/settings_service.dart';
import 'package:smart_twitch_flutter/services/token_manager.dart';
import 'package:smart_twitch_flutter/services/twitch_api_service.dart';
import 'package:smart_twitch_flutter/services/twitch_auth_service.dart';
import 'package:smart_twitch_flutter/services/twitch_browse_service.dart';
import 'package:smart_twitch_flutter/services/twitch_integrity_service.dart';

/// Global GetIt instance for dependency injection.
final GetIt sl = GetIt.instance;

/// Service Locator for managing dependency injection.
///
/// Registers all services as lazy singletons and provides graceful shutdown
/// for services implementing [Disposable].
///
/// Usage:
/// ```dart
/// // In main.dart before runApp:
/// await ServiceLocator.initialize();
///
/// // Access services anywhere:
/// final authService = sl<TwitchAuthService>();
///
/// // On app shutdown:
/// await ServiceLocator.disposeAll();
/// ```
class ServiceLocator {
  ServiceLocator._();

  static bool _isInitialized = false;

  /// Initialize all service registrations.
  ///
  /// Call this once in [main] before [runApp].
  static Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    // =========================================================================
    // CORE SERVICES (No dependencies)
    // =========================================================================

    // Settings must be initialized first as other services depend on it
    await SettingsService.initialize();
    sl.registerLazySingleton<SettingsService>(
      () => SettingsService.instance,
    );

    // =========================================================================
    // AUTH & TOKEN SERVICES
    // =========================================================================

    sl.registerLazySingleton<TwitchAuthService>(
      () => TwitchAuthService(),
    );

    sl.registerLazySingleton<TokenManager>(
      () => TokenManager(),
      dispose: (service) => service.dispose(),
    );

    // =========================================================================
    // INTEGRITY SERVICE (Must be before API services)
    // =========================================================================

    sl.registerLazySingleton<TwitchIntegrityService>(
      () => TwitchIntegrityService(),
      dispose: (service) => service.dispose(),
    );

    // =========================================================================
    // API SERVICES
    // =========================================================================

    sl.registerLazySingleton<TwitchApiService>(
      () => TwitchApiService(integrityService: sl<TwitchIntegrityService>()),
    );

    sl.registerLazySingleton<TwitchBrowseService>(
      () => TwitchBrowseService(),
    );

    sl.registerLazySingleton<HlsManifestService>(
      () => HlsManifestService(),
    );

    // =========================================================================
    // PLAYER SERVICES
    // =========================================================================

    sl.registerLazySingleton<LowLatencyService>(
      () => LowLatencyService.instance,
      dispose: (service) => service.dispose(),
    );

    sl.registerLazySingleton<PreviewPlayerManager>(
      () => PreviewPlayerManager(),
      dispose: (service) => service.disposePlayer(),
    );

    _isInitialized = true;
  }

  /// Dispose all registered services that implement [Disposable].
  ///
  /// Call this on application shutdown (window close) to gracefully
  /// release resources like database connections, sockets, and streams.
  ///
  /// GetIt will automatically call dispose callbacks registered during
  /// [registerLazySingleton] for any instantiated services.
  static Future<void> disposeAll() async {
    if (!_isInitialized) {
      return;
    }

    // GetIt's reset() calls dispose on all registered singletons
    // that have a dispose callback. We iterate manually for Disposable
    // interface compliance and logging.
    final disposables = <Disposable>[];

    // Collect all registered services that implement Disposable
    if (sl.isRegistered<TokenManager>()) {
      final service = sl<TokenManager>();
      if (service is Disposable) {
        disposables.add(service as Disposable);
      }
    }

    if (sl.isRegistered<PreviewPlayerManager>()) {
      final service = sl<PreviewPlayerManager>();
      if (service is Disposable) {
        disposables.add(service as Disposable);
      }
    }

    if (sl.isRegistered<LowLatencyService>()) {
      final service = sl<LowLatencyService>();
      if (service is Disposable) {
        disposables.add(service as Disposable);
      }
    }

    // Dispose TwitchIntegrityService (not Disposable but has dispose method)
    if (sl.isRegistered<TwitchIntegrityService>()) {
      try {
        await sl<TwitchIntegrityService>().dispose();
      } catch (e) {
        // ignore: avoid_print
        print('[ServiceLocator] Error disposing TwitchIntegrityService: $e');
      }
    }

    // Dispose all Disposable services
    for (final disposable in disposables) {
      try {
        await disposable.dispose();
      } catch (e) {
        // Log error but continue disposing other services
        // ignore: avoid_print
        print('[ServiceLocator] Error disposing ${disposable.runtimeType}: $e');
      }
    }

    // Reset GetIt to unregister all services
    await sl.reset();
    _isInitialized = false;
  }

  /// Check if services have been initialized.
  static bool get isInitialized => _isInitialized;

  /// Reset for testing purposes.
  ///
  /// Disposes all services and resets the initialized state.
  static Future<void> reset() async {
    await disposeAll();
  }
}
