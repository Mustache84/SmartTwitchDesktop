import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/token_manager.dart';
import '../services/twitch_auth_service.dart';
import '../services/secure_token_storage.dart';

/// Authentication state
class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? userId;
  final String? userLogin;
  final String? userDisplayName;
  final String? error;

  // Device code flow state
  final String? userCode;
  final String? verificationUri;
  final bool isPolling;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = true,
    this.userId,
    this.userLogin,
    this.userDisplayName,
    this.error,
    this.userCode,
    this.verificationUri,
    this.isPolling = false,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? userId,
    String? userLogin,
    String? userDisplayName,
    String? error,
    String? userCode,
    String? verificationUri,
    bool? isPolling,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      userId: userId ?? this.userId,
      userLogin: userLogin ?? this.userLogin,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      error: error,  // Allow clearing error by passing null
      userCode: userCode,  // Allow clearing
      verificationUri: verificationUri,  // Allow clearing
      isPolling: isPolling ?? this.isPolling,
    );
  }

  /// Initial loading state
  static const loading = AuthState(isLoading: true);

  /// Logged out state
  static const loggedOut = AuthState(isAuthenticated: false, isLoading: false);
}

/// Notifier for authentication state
class AuthNotifier extends Notifier<AuthState> {
  final TwitchAuthService _authService = TwitchAuthService();
  final TokenManager _tokenManager = TokenManager();
  
  Timer? _pollingTimer;

  @override
  AuthState build() {
    // Check for existing authentication on startup
    _checkExistingAuth();
    return AuthState.loading;
  }

  /// Check if user is already authenticated from stored tokens
  Future<void> _checkExistingAuth() async {
    try {
      await _tokenManager.initialize();
      
      if (!await _tokenManager.isAuthenticated()) {
        state = AuthState.loggedOut;
        return;
      }

      // Validate the stored token
      final validation = await _tokenManager.validateCurrentToken();
      if (validation != null) {
        state = AuthState(
          isAuthenticated: true,
          isLoading: false,
          userId: validation.userId,
          userLogin: validation.login,
        );
        
        // Also load display name if stored
        final displayName = await SecureTokenStorage.getUserDisplayName();
        if (displayName != null) {
          state = state.copyWith(userDisplayName: displayName);
        }
      } else {
        state = AuthState.loggedOut;
      }
    } catch (e) {
      state = AuthState(
        isAuthenticated: false,
        isLoading: false,
        error: 'Failed to check authentication: $e',
      );
    }
  }

  /// Start the device code authentication flow
  Future<void> startLogin() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Request device code
      final deviceCode = await _authService.requestDeviceCode();
      
      state = state.copyWith(
        isLoading: false,
        userCode: deviceCode.userCode,
        verificationUri: deviceCode.verificationUri,
        isPolling: true,
      );

      // Start polling for authorization
      _startPolling(deviceCode.deviceCode, deviceCode.interval);

    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
    }
  }

  /// Open the verification URL in the browser
  Future<void> openVerificationUrl() async {
    final uri = state.verificationUri;
    if (uri == null) return;

    final url = Uri.parse(uri);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  /// Start polling for token
  void _startPolling(String deviceCode, int interval) {
    _pollingTimer?.cancel();
    
    _pollingTimer = Timer.periodic(Duration(seconds: interval), (_) async {
      if (!state.isPolling) {
        _pollingTimer?.cancel();
        return;
      }

      try {
        final tokenResponse = await _authService.pollForToken(deviceCode);
        
        if (tokenResponse != null) {
          // Successfully authorized!
          _pollingTimer?.cancel();
          
          // Save tokens
          await _tokenManager.saveTokens(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresIn: tokenResponse.expiresIn,
          );

          // Validate to get user info
          final validation = await _authService.validateToken(tokenResponse.accessToken);
          
          await _tokenManager.saveUserInfo(
            userId: validation.userId,
            login: validation.login,
          );

          state = AuthState(
            isAuthenticated: true,
            isLoading: false,
            userId: validation.userId,
            userLogin: validation.login,
          );
        }
        // If null, authorization is still pending - keep polling
        
      } on AuthException catch (e) {
        _pollingTimer?.cancel();
        state = state.copyWith(
          isPolling: false,
          error: e.message,
        );
      }
    });
  }

  /// Cancel the login flow
  void cancelLogin() {
    _pollingTimer?.cancel();
    state = AuthState.loggedOut;
  }

  /// Logout the user
  Future<void> logout() async {
    _pollingTimer?.cancel();
    
    try {
      await _tokenManager.revokeToken();
    } finally {
      state = AuthState.loggedOut;
    }
  }

  /// Get the current access token (for API calls)
  Future<String?> getAccessToken() async {
    return _tokenManager.getValidToken();
  }
}

/// Provider for authentication state
final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

/// Convenience provider for checking if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

/// Convenience provider for current user login
final currentUserLoginProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).userLogin;
});
