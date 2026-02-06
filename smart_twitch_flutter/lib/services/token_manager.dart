import 'dart:async';
import 'package:smart_twitch_flutter/core/interfaces/disposable.dart';
import 'package:smart_twitch_flutter/services/secure_token_storage.dart';
import 'package:smart_twitch_flutter/services/twitch_auth_service.dart';

/// Manages OAuth token lifecycle including automatic refresh.
/// 
/// This is a singleton that should be initialized once at app startup.
/// It handles:
/// - Loading tokens from secure storage
/// - Automatic refresh before expiration
/// - Providing valid tokens to other services
///
/// Implements [Disposable] for graceful shutdown on window close.
class TokenManager implements Disposable {
  static final TokenManager _instance = TokenManager._internal();
  factory TokenManager() => _instance;
  TokenManager._internal();

  final TwitchAuthService _authService = TwitchAuthService();
  
  Timer? _refreshTimer;
  String? _cachedAccessToken;
  bool _isInitialized = false;
  bool _isRefreshing = false;

  /// Initialize the token manager and start refresh timer if tokens exist
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _isInitialized = true;
    await _loadCachedToken();
    _scheduleRefresh();
  }

  /// Load the cached token from secure storage
  Future<void> _loadCachedToken() async {
    _cachedAccessToken = await SecureTokenStorage.getAccessToken();
  }

  /// Get a valid access token, refreshing if necessary
  /// 
  /// Returns null if user is not authenticated.
  /// Throws [AuthException] if refresh fails (user needs to re-authenticate).
  Future<String?> getValidToken() async {
    // No token stored
    if (!await SecureTokenStorage.hasTokens()) {
      return null;
    }

    // Check if token will expire soon
    if (await SecureTokenStorage.willExpireSoon()) {
      await _refreshTokenIfNeeded();
    }

    // Return cached or freshly loaded token
    _cachedAccessToken ??= await SecureTokenStorage.getAccessToken();
    return _cachedAccessToken;
  }

  /// Force refresh the token
  Future<void> _refreshTokenIfNeeded() async {
    // Prevent concurrent refresh attempts
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      final refreshToken = await SecureTokenStorage.getRefreshToken();
      if (refreshToken == null) {
        throw AuthException('No refresh token available');
      }

      final tokenResponse = await _authService.refreshToken(refreshToken);

      // Save new tokens
      await SecureTokenStorage.saveTokens(
        accessToken: tokenResponse.accessToken,
        refreshToken: tokenResponse.refreshToken,
        expiresIn: tokenResponse.expiresIn,
      );

      _cachedAccessToken = tokenResponse.accessToken;
      _scheduleRefresh();
    } on AuthException {
      // Refresh failed - clear tokens and require re-authentication
      await clearTokens();
      rethrow;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Schedule automatic token refresh before expiration
  void _scheduleRefresh() {
    _refreshTimer?.cancel();

    SecureTokenStorage.getExpiresAt().then((expiresAt) {
      if (expiresAt == null) return;

      final expiresAtTime = DateTime.fromMillisecondsSinceEpoch(expiresAt);
      // Refresh 5 minutes before expiration
      final refreshTime = expiresAtTime.subtract(const Duration(minutes: 5));
      final delay = refreshTime.difference(DateTime.now());

      if (delay.isNegative) {
        // Token is already expired or about to expire, refresh now
        _refreshTokenIfNeeded();
      } else {
        _refreshTimer = Timer(delay, () {
          _refreshTokenIfNeeded();
        });
      }
    });
  }

  /// Save new tokens after successful authentication
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
  }) async {
    await SecureTokenStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: expiresIn,
    );
    _cachedAccessToken = accessToken;
    _scheduleRefresh();
  }

  /// Save user info after token validation
  Future<void> saveUserInfo({
    required String userId,
    required String login,
    String? displayName,
  }) async {
    await SecureTokenStorage.saveUserInfo(
      userId: userId,
      login: login,
      displayName: displayName,
    );
  }

  /// Clear all tokens (logout)
  Future<void> clearTokens() async {
    _refreshTimer?.cancel();
    _cachedAccessToken = null;
    await SecureTokenStorage.clearAll();
  }

  /// Check if user is authenticated (has tokens, not necessarily valid)
  Future<bool> isAuthenticated() async {
    return SecureTokenStorage.hasTokens();
  }

  /// Validate the current token and return user info
  Future<ValidateResponse?> validateCurrentToken() async {
    final token = await getValidToken();
    if (token == null) return null;

    try {
      return await _authService.validateToken(token);
    } on AuthException {
      // Token is invalid, clear it
      await clearTokens();
      return null;
    }
  }

  /// Revoke the current token (for logout)
  Future<void> revokeToken() async {
    final token = _cachedAccessToken ?? await SecureTokenStorage.getAccessToken();
    if (token != null) {
      await _authService.revokeToken(token);
    }
    await clearTokens();
  }

  /// Dispose the token manager, cancelling any pending refresh timers.
  @override
  Future<void> dispose() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _cachedAccessToken = null;
    _isInitialized = false;
  }
}
