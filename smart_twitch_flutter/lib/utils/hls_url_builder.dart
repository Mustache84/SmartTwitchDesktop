import 'dart:math';

/// Builds HLS manifest URLs for Twitch streams
/// Implements Twitch's required URL parameters for stream playback
class HlsUrlBuilder {
  static const _usherBase = 'https://usher.ttvnw.net/api/channel/hls/';
  static final _random = Random();
  
  /// Constructs the full HLS manifest URL for live streams
  /// Uses Twitch's required parameters for successful playback
  static String buildStreamUrl({
    required String channel,
    required String token,
    required String signature,
  }) {
    // Generate random values for session tracking
    final randomInt = _random.nextInt(100000000);
    final randomId1 = _random.nextInt(1 << 32);
    final randomId2 = _random.nextInt(1 << 32);
    final playSessionId = '$randomId1$randomId2$randomId1$randomId2';
    
    // Token must be URL-encoded, signature must NOT be encoded
    final encodedToken = Uri.encodeComponent(token);
    
    // Build URL with token and sig first, then required parameters
    final url = '$_usherBase${channel.toLowerCase()}.m3u8'
        '?token=$encodedToken'
        '&sig=$signature'
        '&player_backend=mediaplayer'
        '&reassignments_supported=true'
        '&playlist_include_framerate=true'
        '&allow_source=true'
        '&fast_bread=false'
        '&cdm=wv'
        '&acmb=e30%3D'
        '&p=$randomInt'
        '&play_session_id=$playSessionId'
        '&player_version=1.13.0'
        '&supported_codecs=h264';
    
    print('[HlsUrlBuilder] Generated URL for $channel');
    print('[HlsUrlBuilder] URL: $url');
    
    return url;
  }
}

