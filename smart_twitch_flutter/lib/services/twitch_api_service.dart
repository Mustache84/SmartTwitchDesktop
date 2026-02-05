import 'package:dio/dio.dart';
import 'token_manager.dart';
import '../config/twitch_constants.dart';

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
  /// Uses the registered OAuth client ID for all requests.
  /// If authenticated, includes Bearer token for subscriber features.
  Future<PlaybackToken> getPlaybackToken(String channelLogin) async {
    final query = _liveTokenQueryTemplate.replaceAll('%LOGIN%', channelLogin.toLowerCase());

    // Check if user is authenticated
    final accessToken = await _tokenManager.getValidToken();

    // GraphQL requires "blessed" client ID (not our OAuth client ID)
    final headers = {
      'Client-ID': twitchGqlClientId,
      'Content-Type': 'application/json',
    };

    // Add auth token if available (for subscriber features)
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
      print('[TwitchApiService] Using authenticated request for $channelLogin');
    } else {
      print('[TwitchApiService] Using anonymous request for $channelLogin');
    }

    try {
      final response = await _dio.post(
        twitchGqlEndpoint,
        data: query,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final token = _parsePlaybackToken(response.data, channelLogin);
        print('[TwitchApiService] Successfully got playback token for $channelLogin');
        return token;
      }

      throw TwitchApiException('Unexpected status code: ${response.statusCode}');
    } on DioException catch (e) {
      throw TwitchApiException(
        'Failed to get playback token: ${e.message}',
        statusCode: e.response?.statusCode,
        originalError: e,
      );
    }
  }
  
  /// Parse playback token from GQL response
  PlaybackToken _parsePlaybackToken(dynamic data, String channelLogin) {
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
        '$twitchHelixEndpoint/users',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Client-ID': twitchClientId,
          },
        ),
      );

      final userId = userResponse.data['data'][0]['id'];

      // Then get followed channels
      final followsResponse = await _dio.get(
        '$twitchHelixEndpoint/channels/followed',
        queryParameters: {
          'user_id': userId,
          'first': 100,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Client-ID': twitchClientId,
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
        '$twitchHelixEndpoint/users',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Client-ID': twitchClientId,
          },
        ),
      );

      final userId = userResponse.data['data'][0]['id'];

      // Check subscription
      final subResponse = await _dio.get(
        '$twitchHelixEndpoint/subscriptions/user',
        queryParameters: {
          'broadcaster_id': broadcasterId,
          'user_id': userId,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Client-ID': twitchClientId,
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
