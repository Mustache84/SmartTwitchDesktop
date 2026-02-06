/// Twitch Integrity Service - Headless Browser Token Harvester
///
/// This service spawns a hidden WebView to harvest Twitch's Client-Integrity
/// tokens and session cookies. These are required to bypass Twitch's API
/// hardening which now rejects static/hardcoded client IDs.
///
/// Architecture:
/// 1. Spawn a HeadlessInAppWebView pointing to twitch.tv
/// 2. Block video segment downloads (bandwidth protection)
/// 3. Intercept POST requests to gql.twitch.tv/gql
/// 4. Extract Client-ID, Client-Integrity, Authorization, X-Device-Id headers
/// 5. Extract session cookies via CookieManager
/// 6. Expose harvested session via IntegrityNotifier (Riverpod)
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:smart_twitch_flutter/models/twitch_session.dart';
import 'package:smart_twitch_flutter/utils/browser_constants.dart';

/// Callback for when a visible webview is needed (Windows fallback)
typedef VisibleWebViewCallback = void Function(bool needsVisible);

/// Callback for session updates
typedef SessionUpdateCallback = void Function(TwitchSession session);

/// Service responsible for harvesting Twitch integrity tokens.
///
/// Usage:
/// ```dart
/// final service = TwitchIntegrityService();
/// await service.initialize();
/// final session = await service.getSession();
/// ```
class TwitchIntegrityService {
  /// Headless webview instance (primary harvester)
  HeadlessInAppWebView? _headlessWebView;

  /// Cookie manager for extracting session cookies
  final CookieManager _cookieManager = CookieManager.instance();

  /// Session builder for incrementally constructing the session
  final TwitchSessionBuilder _sessionBuilder = TwitchSessionBuilder();

  /// Completer for the initial session harvest
  Completer<TwitchSession>? _sessionCompleter;

  /// Timer for headless fallback detection
  Timer? _fallbackTimer;

  /// Whether we've fallen back to visible webview mode
  bool _usingVisibleWebView = false;

  /// Callback when a visible webview is needed (for Windows fallback)
  VisibleWebViewCallback? onNeedsVisibleWebView;

  /// Callback when session is updated
  SessionUpdateCallback? onSessionUpdate;

  /// Current harvested session
  TwitchSession? _currentSession;

  /// Whether the service has been initialized
  bool _isInitialized = false;

  /// Whether harvesting is in progress
  bool _isHarvesting = false;

  /// Get the current session (may be null if not harvested yet)
  TwitchSession? get currentSession => _currentSession;

  /// Check if service is ready (has a valid session)
  bool get isReady => _currentSession != null && !_currentSession!.isExpired;

  /// Initialize the integrity service.
  ///
  /// This spawns the headless webview and begins harvesting.
  /// Returns a Future that completes when the first valid session is ready.
  Future<TwitchSession> initialize() async {
    if (_isInitialized && _currentSession != null && !_currentSession!.isExpired) {
      return _currentSession!;
    }

    _isInitialized = true;
    return _startHarvest();
  }

  /// Start the harvesting process
  Future<TwitchSession> _startHarvest() async {
    if (_isHarvesting) {
      // Already harvesting, wait for completion
      return _sessionCompleter?.future ?? 
          Future.error(StateError('Harvesting in progress but no completer'));
    }

    _isHarvesting = true;
    _sessionBuilder.reset();
    _sessionCompleter = Completer<TwitchSession>();

    // Start fallback timer (10 seconds)
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(const Duration(seconds: 10), _onFallbackTimeout);

    try {
      await _createHeadlessWebView();
    } catch (e) {
      _isHarvesting = false;
      _sessionCompleter?.completeError(e);
      rethrow;
    }

    return _sessionCompleter!.future;
  }

  /// Create and start the headless webview
  Future<void> _createHeadlessWebView() async {
    if (kDebugMode) {
      print('[IntegrityService] Creating headless webview...');
    }

    _headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(TwitchIntegrityUrls.baseUrl),
      ),
      initialSettings: InAppWebViewSettings(
        // Debug mode only
        isInspectable: kDebugMode,

        // Prevent auto-play and audio
        mediaPlaybackRequiresUserGesture: true,
        allowsInlineMediaPlayback: false,

        // Desktop-specific settings
        userAgent: kBrowserUserAgent,

        // JavaScript must be enabled for integrity script
        javaScriptEnabled: true,

        // Disable caching to ensure fresh tokens
        cacheEnabled: false,
        clearCache: true,

        // Block unnecessary resources
        blockNetworkImage: true,

        // Disable geolocation and other features
        geolocationEnabled: false,

        // Windows-specific: Use shared process
        isTextInteractionEnabled: false,
      ),

      // Intercept requests to block video segments and capture headers
      shouldInterceptRequest: _shouldInterceptRequest,

      onWebViewCreated: (controller) async {
        if (kDebugMode) {
          print('[IntegrityService] Headless WebView created');
        }
      },

      onLoadStart: (controller, url) {
        if (kDebugMode) {
          print('[IntegrityService] Loading: $url');
        }
      },

      onLoadStop: (controller, url) async {
        if (kDebugMode) {
          print('[IntegrityService] Loaded: $url');
        }

        // Extract cookies after page load
        await _extractCookies();
      },

      onReceivedError: (controller, request, error) {
        if (kDebugMode) {
          print('[IntegrityService] Error: ${error.description}');
        }
      },

      onConsoleMessage: (controller, consoleMessage) {
        if (kDebugMode) {
          print('[IntegrityService] Console: ${consoleMessage.message}');
        }
      },
    );

    // Run the headless webview
    await _headlessWebView!.run();

    if (kDebugMode) {
      print('[IntegrityService] Headless WebView running');
    }
  }

  /// Request interceptor - blocks video segments and captures integrity headers
  Future<WebResourceResponse?> _shouldInterceptRequest(
    InAppWebViewController controller,
    WebResourceRequest request,
  ) async {
    final url = request.url.toString();

    // Block video segment downloads (bandwidth protection)
    if (BlockedResourcePatterns.shouldBlockUrl(url)) {
      if (kDebugMode) {
        print('[IntegrityService] Blocking video resource: $url');
      }
      // Return 404 to block the request
      return WebResourceResponse(
        statusCode: 404,
        reasonPhrase: 'Blocked by IntegrityService',
      );
    }

    // Intercept GQL requests to extract headers
    if (url.contains('gql.twitch.tv/gql')) {
      await _extractHeadersFromRequest(request);
    }

    // Allow other requests to proceed
    return null;
  }

  /// Extract integrity headers from an intercepted GQL request
  Future<void> _extractHeadersFromRequest(WebResourceRequest request) async {
    final headers = request.headers ?? {};

    if (kDebugMode) {
      print('[IntegrityService] Intercepted GQL request with headers: '
          '${headers.keys.toList()}');
    }

    // Extract required headers
    if (headers.containsKey('Client-ID') || headers.containsKey('client-id')) {
      _sessionBuilder.setClientId(
        headers['Client-ID'] ?? headers['client-id'] ?? '',
      );
    }

    if (headers.containsKey('Client-Integrity') ||
        headers.containsKey('client-integrity')) {
      _sessionBuilder.setIntegrityToken(
        headers['Client-Integrity'] ?? headers['client-integrity'] ?? '',
      );
      if (kDebugMode) {
        print('[IntegrityService] Got Client-Integrity token!');
      }
    }

    if (headers.containsKey('Authorization') ||
        headers.containsKey('authorization')) {
      _sessionBuilder.setAuthorization(
        headers['Authorization'] ?? headers['authorization'] ?? '',
      );
    }

    if (headers.containsKey('X-Device-Id') ||
        headers.containsKey('x-device-id')) {
      _sessionBuilder.setDeviceId(
        headers['X-Device-Id'] ?? headers['x-device-id'] ?? '',
      );
    }

    // Try to build the session
    await _tryCompleteSession();
  }

  /// Extract cookies from the WebView
  Future<void> _extractCookies() async {
    try {
      final cookies = await _cookieManager.getCookies(
        url: WebUri(TwitchIntegrityUrls.baseUrl),
      );

      for (final cookie in cookies) {
        if (TwitchSessionCookies.requiredCookies.contains(cookie.name)) {
          _sessionBuilder.addCookie(cookie.name, cookie.value);
          if (kDebugMode) {
            print('[IntegrityService] Got cookie: ${cookie.name}');
          }
        }
      }

      await _tryCompleteSession();
    } catch (e) {
      if (kDebugMode) {
        print('[IntegrityService] Error extracting cookies: $e');
      }
    }
  }

  /// Try to complete the session if all required data is available
  Future<void> _tryCompleteSession() async {
    if (!_sessionBuilder.isComplete) {
      if (kDebugMode) {
        print('[IntegrityService] Session incomplete. '
            'Missing: ${_sessionBuilder.missingFields}');
      }
      return;
    }

    final session = _sessionBuilder.build();
    if (session == null) return;

    _currentSession = session;
    _isHarvesting = false;
    _fallbackTimer?.cancel();

    if (kDebugMode) {
      print('[IntegrityService] Session complete! $session');
    }

    // Notify listeners
    onSessionUpdate?.call(session);

    // Complete the awaiting future
    if (_sessionCompleter != null && !_sessionCompleter!.isCompleted) {
      _sessionCompleter!.complete(session);
    }
  }

  /// Fallback timeout - switch to visible webview if headless fails
  void _onFallbackTimeout() {
    if (_isHarvesting && !_sessionBuilder.isComplete) {
      if (kDebugMode) {
        print('[IntegrityService] Headless timeout! '
            'Missing: ${_sessionBuilder.missingFields}');
        print('[IntegrityService] Requesting visible WebView fallback...');
      }

      _usingVisibleWebView = true;

      // Dispose headless and request visible webview
      _headlessWebView?.dispose();
      _headlessWebView = null;

      // Notify UI that we need a visible webview
      onNeedsVisibleWebView?.call(true);
    }
  }

  /// Create settings for a visible webview (fallback mode).
  ///
  /// On Windows, headless WebViews sometimes fail to execute JS properly.
  /// This returns settings for a 1x1 pixel visible WebView that can be
  /// hidden with Offstage or Opacity widgets.
  InAppWebViewSettings createVisibleWebViewSettings() {
    return InAppWebViewSettings(
      isInspectable: kDebugMode,
      mediaPlaybackRequiresUserGesture: true,
      allowsInlineMediaPlayback: false,
      userAgent: kBrowserUserAgent,
      javaScriptEnabled: true,
      cacheEnabled: false,
      blockNetworkImage: true,
      geolocationEnabled: false,
      // Mute audio in visible mode
      isFraudulentWebsiteWarningEnabled: false,
    );
  }

  /// Handle visible webview request interception (for fallback mode)
  Future<WebResourceResponse?> handleVisibleWebViewRequest(
    InAppWebViewController controller,
    WebResourceRequest request,
  ) async {
    return _shouldInterceptRequest(controller, request);
  }

  /// Handle visible webview load complete (for fallback mode)
  Future<void> handleVisibleWebViewLoadStop(
    InAppWebViewController controller,
    WebUri? url,
  ) async {
    await _extractCookies();
  }

  /// Refresh the session (force re-harvest).
  ///
  /// Call this when a 403 is received from Twitch API.
  Future<TwitchSession> refresh() async {
    if (kDebugMode) {
      print('[IntegrityService] Refreshing session...');
    }

    // Dispose existing webview
    await dispose();

    // Reset state
    _isInitialized = false;
    _usingVisibleWebView = false;
    _currentSession = null;

    // Start fresh harvest
    return initialize();
  }

  /// Get the current session, initializing if necessary.
  Future<TwitchSession> getSession() async {
    if (isReady) {
      return _currentSession!;
    }

    // Check if we should proactively refresh
    if (_currentSession?.shouldRefresh ?? false) {
      return refresh();
    }

    return initialize();
  }

  /// Dispose of resources.
  ///
  /// MUST be called when the app closes to prevent memory leaks.
  Future<void> dispose() async {
    if (kDebugMode) {
      print('[IntegrityService] Disposing...');
    }

    _fallbackTimer?.cancel();
    _fallbackTimer = null;

    await _headlessWebView?.dispose();
    _headlessWebView = null;

    _isHarvesting = false;
    _isInitialized = false;
  }

  /// Check if we're using the visible webview fallback
  bool get isUsingVisibleWebView => _usingVisibleWebView;

  /// Get the initial URL request for visible webview fallback
  URLRequest get initialUrlRequest => URLRequest(
        url: WebUri(TwitchIntegrityUrls.baseUrl),
      );

  // ===========================================================================
  // BEHAVIORAL NOISE METHODS (Phase 1.9b)
  // ===========================================================================

  /// Internal controller reference for behavioral noise
  InAppWebViewController? _webViewController;

  /// Load a URL in the Ghost Browser for behavioral noise.
  ///
  /// This navigates the hidden WebView to the specified URL while
  /// maintaining all resource blocking rules (no video segments).
  ///
  /// Used by [BehavioralNoiseService] for shadow navigation.
  Future<void> loadUrl(String url) async {
    if (!_isInitialized) {
      if (kDebugMode) {
        print('[IntegrityService] Cannot loadUrl - not initialized');
      }
      return;
    }

    if (kDebugMode) {
      print('[IntegrityService] Loading URL for behavioral noise: $url');
    }

    // If using visible webview, the controller is set externally
    if (_webViewController != null) {
      await _webViewController!.loadUrl(
        urlRequest: URLRequest(url: WebUri(url)),
      );
      return;
    }

    // For headless mode, we need to recreate with new URL
    // This is less efficient but maintains the resource blocking
    if (_headlessWebView != null) {
      await _headlessWebView!.webViewController?.loadUrl(
        urlRequest: URLRequest(url: WebUri(url)),
      );
    }
  }

  /// Execute JavaScript in the Ghost Browser for behavioral noise.
  ///
  /// Used by [BehavioralNoiseService] for heartbeat actions.
  Future<void> executeJavaScript(String script) async {
    if (!_isInitialized) {
      if (kDebugMode) {
        print('[IntegrityService] Cannot execute JS - not initialized');
      }
      return;
    }

    if (kDebugMode) {
      print('[IntegrityService] Executing JS for behavioral noise');
    }

    try {
      if (_webViewController != null) {
        await _webViewController!.evaluateJavascript(source: script);
      } else if (_headlessWebView != null) {
        await _headlessWebView!.webViewController?.evaluateJavascript(
          source: script,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('[IntegrityService] JS execution error: $e');
      }
    }
  }

  /// Set the WebView controller reference (for visible fallback mode).
  ///
  /// Called by the fallback widget when it creates a visible WebView.
  void setWebViewController(InAppWebViewController controller) {
    _webViewController = controller;
  }

  /// Get the current URL in the Ghost Browser.
  Future<String?> getCurrentUrl() async {
    try {
      if (_webViewController != null) {
        final url = await _webViewController!.getUrl();
        return url?.toString();
      } else if (_headlessWebView != null) {
        final url = await _headlessWebView!.webViewController?.getUrl();
        return url?.toString();
      }
    } catch (e) {
      if (kDebugMode) {
        print('[IntegrityService] Error getting current URL: $e');
      }
    }
    return null;
  }
}

/// Mixin for widgets that need to provide a visible WebView fallback.
///
/// Use this when the headless harvester fails (common on Windows).
mixin TwitchIntegrityWebViewMixin {
  /// Build a 1x1 pixel visible webview for integrity harvesting.
  ///
  /// This should be wrapped in Offstage or Opacity(0) to hide it.
  InAppWebView buildIntegrityWebView({
    required TwitchIntegrityService service,
    required void Function() onSessionReady,
  }) {
    return InAppWebView(
      initialUrlRequest: service.initialUrlRequest,
      initialSettings: service.createVisibleWebViewSettings(),
      shouldInterceptRequest: service.handleVisibleWebViewRequest,
      onLoadStop: (controller, url) async {
        await service.handleVisibleWebViewLoadStop(controller, url);
        if (service.isReady) {
          onSessionReady();
        }
      },
    );
  }
}
