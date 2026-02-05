/// Single Source of Truth for non-localized string constants.
///
/// This class contains internal strings that should NOT be translated:
/// - App identifiers and internal IDs
/// - Route names
/// - Asset paths
/// - Cache keys
/// - Storage keys
///
/// For user-facing strings that need localization, use the l10n system.
///
/// API keys and secrets should remain in `lib/config/` for security reasons.
abstract final class AppStrings {
  // Prevent instantiation
  AppStrings._();

  // ============================================================
  // App Identity
  // ============================================================

  /// Application name
  static const String appName = 'SmartTwitch Desktop';

  /// Application identifier (for storage, analytics, etc.)
  static const String appId = 'smart_twitch_desktop';

  // ============================================================
  // Route Names
  // ============================================================

  /// Login route
  static const String routeLogin = '/login';

  /// Home route
  static const String routeHome = '/home';

  /// Player route prefix (append channel login)
  static const String routePlayerPrefix = '/player/';

  /// Settings route
  static const String routeSettings = '/settings';

  // ============================================================
  // Storage Keys
  // ============================================================

  /// Key for storing auth token
  static const String keyAuthToken = 'auth_token';

  /// Key for storing user preferences
  static const String keyUserPrefs = 'user_preferences';

  /// Key for storing followed channels cache
  static const String keyFollowedCache = 'followed_channels_cache';

  // ============================================================
  // Asset Paths
  // ============================================================

  /// Path to app logo
  static const String assetLogo = 'assets/images/logo.png';

  /// Path to placeholder thumbnail
  static const String assetPlaceholder = 'assets/images/placeholder.png';

  // ============================================================
  // Default Text (Non-Localized Internal Use)
  // ============================================================

  /// Default loading text
  static const String textLoading = 'Loading...';

  /// Unknown user placeholder
  static const String textUnknownUser = 'Unknown User';

  /// Offline status
  static const String textOffline = 'Offline';

  // ============================================================
  // External URLs
  // ============================================================

  /// Twitch website base URL
  static const String urlTwitchBase = 'https://www.twitch.tv';

  /// Twitch static CDN for images
  static const String urlTwitchStatic = 'https://static-cdn.jtvnw.net';
}
