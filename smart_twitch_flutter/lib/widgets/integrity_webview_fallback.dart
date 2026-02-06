/// Integrity WebView Widget - Visible Fallback for Windows
///
/// On Windows, headless WebViews sometimes fail to execute JavaScript properly.
/// This widget provides a 1x1 pixel visible WebView that can be hidden using
/// Offstage or Opacity widgets while still allowing integrity harvesting.
///
/// Usage:
/// ```dart
/// // In your root widget
/// if (ref.watch(needsVisibleWebViewProvider)) {
///   return Stack(
///     children: [
///       YourMainApp(),
///       const IntegrityWebViewFallback(),
///     ],
///   );
/// }
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_twitch_flutter/state/integrity_provider.dart';

/// A 1x1 pixel visible WebView for integrity harvesting.
///
/// This widget is used as a fallback when HeadlessInAppWebView fails
/// (common on Windows). It should be wrapped in Offstage or Opacity(0)
/// to hide it from the user.
class IntegrityWebViewFallback extends ConsumerStatefulWidget {
  const IntegrityWebViewFallback({super.key});

  @override
  ConsumerState<IntegrityWebViewFallback> createState() =>
      _IntegrityWebViewFallbackState();
}

class _IntegrityWebViewFallbackState
    extends ConsumerState<IntegrityWebViewFallback> {
  InAppWebViewController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(integrityProvider.notifier);
    final service = notifier.service;

    // Render a minimal 1x1 pixel WebView
    return Positioned(
      left: 0,
      top: 0,
      child: SizedBox(
        width: 1,
        height: 1,
        child: Opacity(
          opacity: 0,
          child: InAppWebView(
            initialUrlRequest: service.initialUrlRequest,
            initialSettings: service.createVisibleWebViewSettings(),
            shouldInterceptRequest: service.handleVisibleWebViewRequest,
            onWebViewCreated: (controller) {
              _controller = controller;
            },
            onLoadStop: (controller, url) async {
              await service.handleVisibleWebViewLoadStop(controller, url);
              if (service.isReady) {
                notifier.onVisibleWebViewReady();
              }
            },
          ),
        ),
      ),
    );
  }
}

/// Wrapper widget that automatically includes the integrity fallback if needed.
///
/// Wrap your main app with this to automatically handle the Windows fallback:
/// ```dart
/// IntegrityWrapper(
///   child: MyApp(),
/// )
/// ```
class IntegrityWrapper extends ConsumerWidget {
  final Widget child;

  const IntegrityWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needsFallback = ref.watch(needsVisibleWebViewProvider);

    if (!needsFallback) {
      return child;
    }

    return Stack(
      children: [
        child,
        const IntegrityWebViewFallback(),
      ],
    );
  }
}

/// Initializer widget that starts integrity harvesting on startup.
///
/// Place this widget early in your widget tree to start harvesting
/// as soon as possible:
/// ```dart
/// ProviderScope(
///   child: IntegrityInitializer(
///     child: MyApp(),
///   ),
/// )
/// ```
class IntegrityInitializer extends ConsumerStatefulWidget {
  final Widget child;

  /// Whether to show a loading indicator while harvesting
  final bool showLoadingIndicator;

  /// Custom loading widget to show while harvesting
  final Widget? loadingWidget;

  const IntegrityInitializer({
    super.key,
    required this.child,
    this.showLoadingIndicator = false,
    this.loadingWidget,
  });

  @override
  ConsumerState<IntegrityInitializer> createState() =>
      _IntegrityInitializerState();
}

class _IntegrityInitializerState extends ConsumerState<IntegrityInitializer> {
  @override
  void initState() {
    super.initState();
    // Start integrity harvesting on mount
    Future.microtask(() {
      ref.read(integrityProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(integrityProvider);

    // Show loading if requested and not ready
    if (widget.showLoadingIndicator && state is IntegrityLoading) {
      return widget.loadingWidget ??
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.purple),
                SizedBox(height: 16),
                Text(
                  'Initializing Twitch connection...',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          );
    }

    // Wrap with fallback handler
    return IntegrityWrapper(child: widget.child);
  }
}
