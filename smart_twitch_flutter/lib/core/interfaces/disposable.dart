/// Interface for services that hold resources requiring cleanup.
///
/// Desktop apps run for hours/days. Services maintaining connections
/// (Sockets, Databases, Streams, Timers) MUST implement this interface
/// to prevent memory leaks and ensure graceful shutdown.
///
/// Usage:
/// ```dart
/// class MyService implements Disposable {
///   StreamSubscription? _subscription;
///   Timer? _timer;
///
///   @override
///   Future<void> dispose() async {
///     await _subscription?.cancel();
///     _timer?.cancel();
///   }
/// }
/// ```
abstract class Disposable {
  /// Releases all resources held by this service.
  ///
  /// Called during application shutdown or when the service is being replaced.
  /// Implementations should:
  /// - Cancel all [StreamSubscription]s
  /// - Cancel all [Timer]s
  /// - Close database connections
  /// - Close socket connections
  /// - Dispose any controllers
  Future<void> dispose();
}
