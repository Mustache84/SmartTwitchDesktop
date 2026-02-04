import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for OAuth tokens using platform-native secure storage:
/// - macOS: Keychain
/// - Windows: Windows Credential Manager
/// - Linux: libsecret (GNOME Keyring/KWallet)
class SecureTokenStorage {
  // For macOS sandboxed apps, we MUST use the useDataProtectionKeyChain option
  // This stores items in the app's sandboxed keychain without requiring
  // keychain-access-groups entitlement or code signing with a team.
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(
      // Use Data Protection Keychain (macOS 10.15+) which works with sandbox
      useDataProtectionKeyChain: true,
    ),
  );

  // Storage keys
  static const _accessTokenKey = 'twitch_access_token';
  static const _refreshTokenKey = 'twitch_refresh_token';
  static const _expiresAtKey = 'twitch_expires_at';
  static const _userIdKey = 'twitch_user_id';
  static const _userLoginKey = 'twitch_user_login';
  static const _userDisplayNameKey = 'twitch_user_display_name';

  /// Save OAuth tokens after successful authentication
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
  }) async {
    final expiresAt = DateTime.now()
        .add(Duration(seconds: expiresIn))
        .millisecondsSinceEpoch;

    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
      _storage.write(key: _expiresAtKey, value: expiresAt.toString()),
    ]);
  }

  /// Save user info from token validation
  static Future<void> saveUserInfo({
    required String userId,
    required String login,
    String? displayName,
  }) async {
    await Future.wait([
      _storage.write(key: _userIdKey, value: userId),
      _storage.write(key: _userLoginKey, value: login),
      if (displayName != null)
        _storage.write(key: _userDisplayNameKey, value: displayName),
    ]);
  }

  /// Get stored access token (may be expired)
  static Future<String?> getAccessToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  /// Get stored refresh token
  static Future<String?> getRefreshToken() async {
    return _storage.read(key: _refreshTokenKey);
  }

  /// Get token expiration timestamp (milliseconds since epoch)
  static Future<int?> getExpiresAt() async {
    final value = await _storage.read(key: _expiresAtKey);
    return value != null ? int.tryParse(value) : null;
  }

  /// Get stored user ID
  static Future<String?> getUserId() async {
    return _storage.read(key: _userIdKey);
  }

  /// Get stored user login
  static Future<String?> getUserLogin() async {
    return _storage.read(key: _userLoginKey);
  }

  /// Get stored user display name
  static Future<String?> getUserDisplayName() async {
    return _storage.read(key: _userDisplayNameKey);
  }

  /// Check if token will expire within the given duration
  static Future<bool> willExpireSoon({Duration threshold = const Duration(minutes: 5)}) async {
    final expiresAt = await getExpiresAt();
    if (expiresAt == null) return true;

    final expiresAtTime = DateTime.fromMillisecondsSinceEpoch(expiresAt);
    final thresholdTime = DateTime.now().add(threshold);

    return expiresAtTime.isBefore(thresholdTime);
  }

  /// Check if we have stored tokens (doesn't validate them)
  static Future<bool> hasTokens() async {
    final accessToken = await getAccessToken();
    return accessToken != null && accessToken.isNotEmpty;
  }

  /// Clear all stored tokens and user info (logout)
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Update only the access token and expiration (after refresh)
  static Future<void> updateAccessToken({
    required String accessToken,
    required int expiresIn,
  }) async {
    final expiresAt = DateTime.now()
        .add(Duration(seconds: expiresIn))
        .millisecondsSinceEpoch;

    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(key: _expiresAtKey, value: expiresAt.toString()),
    ]);
  }
}
