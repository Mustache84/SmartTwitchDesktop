/// Browser Constants - Single Source of Truth for User-Agent
///
/// CRITICAL: This User-Agent string MUST be identical across:
/// 1. TwitchIntegrityService (Headless WebView)
/// 2. VideoWidget (fvp/MPV player)
/// 3. Any HTTP requests to Twitch CDN
///
/// If these differ by even ONE character, Twitch will reject the request.
/// Update this when Chrome releases major versions.
library;

/// Desktop Chrome User-Agent string.
///
/// This mimics a real Chrome browser on Windows 10 to pass Twitch's
/// integrity checks. The WebView and video player MUST use this exact string.
///
/// Last updated: Chrome 122 (February 2026)
const String kBrowserUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/122.0.0.0 Safari/537.36';

/// Alternative macOS User-Agent (if Windows UA causes issues on macOS)
const String kBrowserUserAgentMacOS =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/122.0.0.0 Safari/537.36';

/// URL patterns that should be blocked in the headless browser.
///
/// These patterns prevent the integrity harvester from downloading
/// video segments (bandwidth protection).
class BlockedResourcePatterns {
  BlockedResourcePatterns._();

  /// Video segment file extensions
  static const List<String> videoExtensions = [
    '.ts',
    '.m3u8',
    '.m4s',
    '.mp4',
  ];

  /// URL path patterns for video delivery
  static const List<String> videoPathPatterns = [
    'video-weaver',
    'video-edge',
    'usher.ttvnw.net',
    'hls.ttvnw.net',
  ];

  /// Check if a URL should be blocked
  static bool shouldBlockUrl(String url) {
    final lowerUrl = url.toLowerCase();

    // Block video file extensions
    for (final ext in videoExtensions) {
      if (lowerUrl.endsWith(ext)) {
        return true;
      }
    }

    // Block video delivery paths
    for (final pattern in videoPathPatterns) {
      if (lowerUrl.contains(pattern)) {
        return true;
      }
    }

    return false;
  }
}

/// Twitch-specific URLs for integrity harvesting
class TwitchIntegrityUrls {
  TwitchIntegrityUrls._();

  /// Base Twitch URL for initial page load
  static const String baseUrl = 'https://www.twitch.tv/';

  /// GraphQL endpoint for intercepting integrity headers
  static const String gqlEndpoint = 'https://gql.twitch.tv/gql';

  /// Regex pattern for GQL endpoint matching
  static final RegExp gqlPattern = RegExp(r'gql\.twitch\.tv/gql');
}

/// Cookies required for session emulation
class TwitchSessionCookies {
  TwitchSessionCookies._();

  /// Essential cookies to extract from the WebView
  static const List<String> requiredCookies = [
    'api_token',
    'unique_id',
    'server_session_id',
    'auth-token', // If user is logged in via browser
  ];

  /// Format cookies as HTTP header string
  ///
  /// MPV/fvp expects cookies in the format: "key=value; key2=value2"
  static String formatCookieString(Map<String, String> cookies) {
    return cookies.entries
        .map((e) => '${e.key}=${e.value}')
        .join('; ');
  }
}
