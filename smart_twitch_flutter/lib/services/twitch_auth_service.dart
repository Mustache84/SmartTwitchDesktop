import 'dart:async';
import 'package:dio/dio.dart';
import '../config/twitch_constants.dart';

/// Response from device code request
class DeviceCodeResponse {
  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final int expiresIn;
  final int interval;

  DeviceCodeResponse({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.expiresIn,
    required this.interval,
  });

  factory DeviceCodeResponse.fromJson(Map<String, dynamic> json) {
    return DeviceCodeResponse(
      deviceCode: json['device_code'] as String,
      userCode: json['user_code'] as String,
      verificationUri: json['verification_uri'] as String,
      expiresIn: json['expires_in'] as int,
      interval: json['interval'] as int,
    );
  }
}

/// Response from token endpoint (initial or refresh)
class TokenResponse {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final List<String> scopes;
  final String tokenType;

  TokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.scopes,
    required this.tokenType,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int,
      scopes: (json['scope'] as List<dynamic>?)?.cast<String>() ?? [],
      tokenType: json['token_type'] as String,
    );
  }
}

/// Response from token validation
class ValidateResponse {
  final String clientId;
  final String login;
  final List<String> scopes;
  final String userId;
  final int expiresIn;

  ValidateResponse({
    required this.clientId,
    required this.login,
    required this.scopes,
    required this.userId,
    required this.expiresIn,
  });

  factory ValidateResponse.fromJson(Map<String, dynamic> json) {
    return ValidateResponse(
      clientId: json['client_id'] as String,
      login: json['login'] as String,
      scopes: (json['scopes'] as List<dynamic>?)?.cast<String>() ?? [],
      userId: json['user_id'] as String,
      expiresIn: json['expires_in'] as int,
    );
  }
}

/// Exception thrown during authentication
class AuthException implements Exception {
  final String message;
  final String? error;

  AuthException(this.message, {this.error});

  @override
  String toString() => 'AuthException: $message${error != null ? ' ($error)' : ''}';
}

/// Twitch OAuth service using Device Code Grant Flow
///
/// This is the same flow used by the original SmartTwitchTV - secure for
/// desktop apps because no client secret is stored in the binary.
class TwitchAuthService {
  static const _deviceCodeUrl = 'https://id.twitch.tv/oauth2/device';
  static const _tokenUrl = 'https://id.twitch.tv/oauth2/token';
  static const _validateUrl = 'https://id.twitch.tv/oauth2/validate';
  static const _revokeUrl = 'https://id.twitch.tv/oauth2/revoke';

  final Dio _dio;

  TwitchAuthService({Dio? dio}) : _dio = dio ?? Dio();

  /// Step 1: Request a device code from Twitch
  ///
  /// Returns a [DeviceCodeResponse] containing:
  /// - userCode: The code to show the user (e.g., "ABCD-1234")
  /// - verificationUri: URL where user enters the code (twitch.tv/activate)
  /// - deviceCode: Internal code used for polling
  /// - interval: How often to poll (usually 5 seconds)
  Future<DeviceCodeResponse> requestDeviceCode() async {
    try {
      final response = await _dio.post(
        _deviceCodeUrl,
        data: {
          'client_id': twitchClientId,
          'scopes': twitchOAuthScopes.join(' '),
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      return DeviceCodeResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(
        'Failed to request device code',
        error: e.response?.data?.toString(),
      );
    }
  }

  /// Step 2: Poll for token after user authorizes
  ///
  /// Returns null if authorization is still pending.
  /// Returns [TokenResponse] when user has authorized.
  /// Throws [AuthException] on errors (expired, denied, etc.)
  Future<TokenResponse?> pollForToken(String deviceCode) async {
    try {
      final response = await _dio.post(
        _tokenUrl,
        data: {
          'client_id': twitchClientId,
          'device_code': deviceCode,
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200) {
        return TokenResponse.fromJson(response.data as Map<String, dynamic>);
      }

      if (response.statusCode == 400) {
        final data = response.data as Map<String, dynamic>;
        final error = data['message'] as String?;

        switch (error) {
          case 'authorization_pending':
            // User hasn't authorized yet, keep polling
            return null;
          case 'slow_down':
            // We're polling too fast, wait longer next time
            return null;
          case 'expired_token':
            throw AuthException('Device code expired. Please try again.');
          case 'access_denied':
            throw AuthException('Authorization was denied by the user.');
          default:
            throw AuthException('Authorization failed: $error');
        }
      }

      throw AuthException('Unexpected response: ${response.statusCode}');
    } on DioException catch (e) {
      throw AuthException(
        'Network error during authorization',
        error: e.message,
      );
    }
  }

  /// Refresh an expired access token using a refresh token
  Future<TokenResponse> refreshToken(String refreshToken) async {
    try {
      final response = await _dio.post(
        _tokenUrl,
        data: {
          'client_id': twitchClientId,
          'refresh_token': refreshToken,
          'grant_type': 'refresh_token',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      return TokenResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 400 || statusCode == 401) {
        throw AuthException(
          'Refresh token is invalid. Please log in again.',
          error: e.response?.data?.toString(),
        );
      }
      throw AuthException(
        'Failed to refresh token',
        error: e.message,
      );
    }
  }

  /// Validate an access token and get user info
  /// 
  /// Returns [ValidateResponse] with user ID, login, and scopes.
  /// Throws [AuthException] if token is invalid.
  Future<ValidateResponse> validateToken(String accessToken) async {
    try {
      final response = await _dio.get(
        _validateUrl,
        options: Options(
          headers: {'Authorization': 'OAuth $accessToken'},
        ),
      );

      return ValidateResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw AuthException('Token is invalid or expired');
      }
      throw AuthException(
        'Failed to validate token',
        error: e.message,
      );
    }
  }

  /// Revoke a token (for logout)
  Future<void> revokeToken(String accessToken) async {
    try {
      await _dio.post(
        _revokeUrl,
        data: {
          'client_id': twitchClientId,
          'token': accessToken,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );
    } on DioException {
      // Revoke failures are not critical - token will expire anyway
    }
  }
}
