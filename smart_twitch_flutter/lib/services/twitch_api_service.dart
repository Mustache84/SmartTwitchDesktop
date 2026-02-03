import 'package:dio/dio.dart';

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
  
  // Client ID from original app - decoded from Chat_token base64
  // Original base64: 'a2QxdW5iNGIzcTR0NThmd2xwY2J6Y2JubTc2YThmcA=='
  static const _primaryClientId = 'kd1unb4b3q4t58fwlpcbzcbnm76a8fp';
  
  // Fallback client IDs in case primary gets rate-limited
  static const _fallbackClientIds = [
    'kd1unb4b3q4t58fwlpcbzcbnm76a8fp',  // Primary (Chat_token decoded)
    'ue666qo983tsx6so1t0vnawi233wa',     // AddCode_backup_client_id decoded
    'kimne78kx3ncx6brgo4mv6wki5h1ko',   // Old Twitch web client
  ];
  
  static const _gqlEndpoint = 'https://gql.twitch.tv/gql';
  
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
  
  /// Fetches playback access token for a live channel
  /// Port of PlayHLS_GetToken() from PlayHLS.js
  Future<PlaybackToken> getPlaybackToken(String channelLogin) async {
    final query = _liveTokenQueryTemplate.replaceAll('%LOGIN%', channelLogin.toLowerCase());
    
    TwitchApiException? lastException;
    
    // Try each client ID until one works
    for (final clientId in _fallbackClientIds) {
      try {
        print('[TwitchApiService] Trying client ID: ${clientId.substring(0, 8)}...');
        
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
          final data = response.data;
          final accessToken = data['data']?['streamPlaybackAccessToken'];
          
          if (accessToken == null) {
            throw TwitchApiException(
              'Channel "$channelLogin" is offline or does not exist',
              statusCode: response.statusCode,
            );
          }
          
          print('[TwitchApiService] Success! Got token for $channelLogin');
          return PlaybackToken(
            token: accessToken['value'] as String,
            signature: accessToken['signature'] as String,
          );
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
}
