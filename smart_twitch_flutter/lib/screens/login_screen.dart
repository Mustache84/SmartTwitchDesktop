import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/auth_provider.dart';

/// Login screen implementing Twitch Device Code Grant Flow.
/// 
/// Shows a user code that must be entered at twitch.tv/activate.
/// The app polls for authorization in the background.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final authNotifier = ref.read(authProvider.notifier);

    // Listen for successful authentication and navigate to home
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated && !(previous?.isAuthenticated ?? false)) {
        // Successfully logged in - navigate to home
        Navigator.of(context).pushReplacementNamed('/home');
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E10),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Twitch logo placeholder
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF9146FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              
              // App title
              const Text(
                'SmartTwitch Desktop',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              Text(
                'Sign in with your Twitch account',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 48),

              // Show different UI based on state
              if (authState.isLoading && authState.userCode == null)
                _buildLoadingState()
              else if (authState.userCode != null)
                _buildDeviceCodeState(context, authState, authNotifier)
              else if (authState.error != null)
                _buildErrorState(authState, authNotifier)
              else
                _buildInitialState(authNotifier),

              const SizedBox(height: 48),

              // Skip login option
              TextButton(
                onPressed: () {
                  // Navigate to home without auth
                  Navigator.of(context).pushReplacementNamed('/home');
                },
                child: Text(
                  'Continue without signing in',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Column(
      children: [
        CircularProgressIndicator(
          color: Color(0xFF9146FF),
        ),
        SizedBox(height: 16),
        Text(
          'Preparing login...',
          style: TextStyle(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildDeviceCodeState(
    BuildContext context,
    AuthState authState,
    AuthNotifier authNotifier,
  ) {
    return Column(
      children: [
        // Instructions
        Text(
          'Enter this code at',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        
        // Verification URL button
        TextButton(
          onPressed: () => authNotifier.openVerificationUrl(),
          child: const Text(
            'twitch.tv/activate',
            style: TextStyle(
              color: Color(0xFF9146FF),
              fontSize: 18,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // User code display
        GestureDetector(
          onTap: () {
            // Copy code to clipboard
            Clipboard.setData(ClipboardData(text: authState.userCode!));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Code copied to clipboard'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F23),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF9146FF).withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  authState.userCode!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.copy,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        
        Text(
          'Click to copy',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 32),

        // Polling indicator
        if (authState.isPolling) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF9146FF),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Waiting for authorization...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Cancel button
        TextButton(
          onPressed: () => authNotifier.cancelLogin(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(AuthState authState, AuthNotifier authNotifier) {
    return Column(
      children: [
        Icon(
          Icons.error_outline,
          color: Colors.red.shade400,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          authState.error ?? 'An error occurred',
          style: TextStyle(
            color: Colors.red.shade400,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => authNotifier.startLogin(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF9146FF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
          child: const Text('Try Again'),
        ),
      ],
    );
  }

  Widget _buildInitialState(AuthNotifier authNotifier) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () => authNotifier.startLogin(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF9146FF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.login, size: 20),
              SizedBox(width: 8),
              Text(
                'Sign in with Twitch',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Sign in to access your followed channels,\nsend chat messages, and more.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
