import 'package:dio/dio.dart';
import 'token_manager.dart';

class PlaybackToken {
  final String token;
  final String signature;
  
  PlaybackToken({required this.token, required this.signature});
  
  @override
  String toString() => 'PlaybackToken(sig: $signature)';
}

/// Custom exception for Twitch API errors
class TwitchApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? originalError;
  
  TwitchApiException(this.message, {this.statusCode, this.originalError});
  
  @override
  String toString() => 'TwitchApiException: $message (status: $statusCode)';
}

class TwitchApiService {
  final Dio _dio;
  final TokenManager _tokenManager = TokenManager();
  
  // Client ID from original app - decoded from Chat_token base64
  // Original base64: 'a2QxdW5iNGIzcTR0NThmd2xwY2J6Y2JubTc2YThmcA=='
  static const _primaryClientId = 'kd1unb4b3q4t58fwlpcbzcbnm76a8fp';
  
  // OAuth Client ID (for authenticated requests)
  static const _oauthClientId = 'vrhsf9gxj2y4jntunres6mzber1fg1';
  
  // Fallback client IDs in case primary gets rate-limited (anonymous only)
  static const _fallbackClientIds = [
    'kd1unb4b3q4t58fwlpcbzcbnm76a8fp',  // Primary (Chat_token decoded)
    'ue666qo983tsx6so1t0vnawi233wa',     // AddCode_backup_client_id decoded
    'kimne78kx3ncx6brgo4mv6wki5h1ko',   // Old Twitch web client
  ];
  
  static const _gqlEndpoint = 'https://gql.twitch.tv/gql';
  static const _helixEndpoint = 'https://api.twitch.tv/helix';
  
  // Port from PlayHLS.js: Play_live_token - MUST be single-line compact JSON
  static const _liveTokenQueryTemplate = 
      '{"extensions":{"persistedQuery":{"sha256Hash":"ed230aa1e33e07eebb8928504583da78a5173989fadfb1ac94be06a04f3cdbe9","version":1}},"operationName":"PlaybackAccessToken","variables":{"isLive":true,"isVod":false,"login":"%LOGIN%","platform":"web","playerType":"site","vodID":""}}';
  
  TwitchApiService() : _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  )) {
    // Add logging interceptor for debugging
    _dio.interceptors.add(LogInterceptor(
      requestHeader: true,
      requestBody: true,
      responseBody: true,
      error: true,
      logPrint: (obj) => print('[Dio] $obj'),
    ));
  }
  
  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    return await _tokenManager.isAuthenticated();
  }
  
  /// Fetches playback access token for a live channel
  /// Port of PlayHLS_GetToken() from PlayHLS.js
  /// 
  /// If authenticated, uses OAuth token for potentially better quality/features.
  /// Falls back to anonymous client IDs if not authenticated or on failure.
  Future<PlaybackToken> getPlaybackToken(String channelLogin) async {
    final query = _liveTokenQueryTemplate.replaceAll('%LOGIN%', channelLogin.toLowerCase());
    
    TwitchApiException? lastException;
    
    // Try authenticated request first if available
    final accessToken = await _tokenManager.getValidToken();
    if (accessToken != null) {
      try {
        print('[TwitchApiService] Trying authenticated request...');
        
        final response = await _dio.post(
          _gqlEndpoint,
          data: query,
          options: Options(
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Client-ID': _oauthClientId,
              'Content-Type': 'application/json',
            },
          ),
        );
        
        if (response.statusCode == 200) {
          final token = _parsePlaybackToken(response.data, channelLogin);
          if (token != null) {
            print('[TwitchApiService] Authenticated request succeeded for $channelLogin');
            return token;
          }
        }
      } on DioException catch (e) {
        print('[TwitchApiService] Authenticated request failed: ${e.message}');
        // Fall through to anonymous requests
      }
    }
    
    // Try each anonymous client ID until one works
    for (final clientId in _fallbackClientIds) {
      try {
        print('[TwitchApiService] Trying anonymous client ID: ${clientId.substring(0, 8)}...');
        
        final response = await _dio.post(
          _gqlEndpoint,
          data: query,
          options: Options(
            headers: {
              'Client-ID': clientId,
              'Content-Type': 'application/json',
            },
          ),
        );
        
        if (response.statusCode == 200) {
          final token = _parsePlaybackToken(response.data, channelLogin);
          if (token != null) {
            print('[TwitchApiService] Success! Got token for $channelLogin');
            return token;
          }
        }
      } on DioException catch (e) {
        print('[TwitchApiService] Failed with client ID ${clientId.substring(0, 8)}...: ${e.message}');
        lastException = TwitchApiException(
          'Network error: ${e.message}',
          statusCode: e.response?.statusCode,
          originalError: e,
        );
        // Continue to next client ID
        continue;
      } on TwitchApiException {
        rethrow; // Channel offline - don't try other client IDs
      }
    }
    
    throw lastException ?? TwitchApiException('All client IDs failed');
  }
  
  /// Parse playback token from GQL response
  PlaybackToken? _parsePlaybackToken(dynamic data, String channelLogin) {
    final accessToken = data['data']?['streamPlaybackAccessToken'];
    
    if (accessToken == null) {
      throw TwitchApiException(
        'Channel "$channelLogin" is offline or does not exist',
      );
    }
    
    return PlaybackToken(
      token: accessToken['value'] as String,
      signature: accessToken['signature'] as String,
    );
  }
  
  /// Get user's followed channels (requires authentication)
  /// Returns list of channel logins that the user follows
  Future<List<String>> getFollowedChannels() async {
    final accessToken = await _tokenManager.getValidToken();
    if (accessToken == null) {
      throw TwitchApiException('Not authenticated');
    }
    
    try {
      // First get the user ID
      final userResponse = await _dio.get(
        '$_helixEndpoint/users',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Client-ID': _oauthClientId,
          },
        ),
      );
      
      final userId = userResponse.data['data'][0]['id'];
      
      // Then get followed channels
      final followsResponse = await _dio.get(
        '$_helixEndpoint/channels/followed',
        queryParameters: {
          'user_id': userId,
          'first': 100,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Client-ID': _oauthClientId,
          },
        ),
      );
      
      final follows = followsResponse.data['data'] as List;
      return follows
          .map((f) => f['broadcaster_login'] as String)
          .toList();
    } on DioException catch (e) {
      throw TwitchApiException(
        'Failed to get followed channels: ${e.message}',
        statusCode: e.response?.statusCode,
        originalError: e,
      );
    }
  }
  
  /// Check if user is subscribed to a channel (for DVR access)
  Future<bool> isSubscribedTo(String broadcasterId) async {
    final accessToken = await _tokenManager.getValidToken();
    if (accessToken == null) {
      return false;
    }
    
    try {
      // First get the user ID
      final userResponse = await _dio.get(
        '$_helixEndpoint/users',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Client-ID': _oauthClientId,
          },
        ),
      );
      
      final userId = userResponse.data['data'][0]['id'];
      
      // Check subscription
      final subResponse = await _dio.get(
        '$_helixEndpoint/subscriptions/user',
        queryParameters: {
          'broadcaster_id': broadcasterId,
          'user_id': userId,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Client-ID': _oauthClientId,
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      
      // 200 means subscribed, 404 means not subscribed
      return subResponse.statusCode == 200 && 
             (subResponse.data['data'] as List).isNotEmpty;
    } on DioException {
      return false;
    }
  }
}
