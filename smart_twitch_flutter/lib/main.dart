import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'core/core.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/player_screen.dart';
import 'services/settings_service.dart';
import 'state/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize settings service (shared_preferences)
  await SettingsService.initialize();
  
  // Register fvp with low latency option for player controls phase
  fvp.registerWith(options: {
    'lowLatency': 1,
  });
  
  // Initialize window manager for desktop
  await windowManager.ensureInitialized();
  
  WindowOptions windowOptions = const WindowOptions(
    size: Size(AppDimens.windowDefaultWidth, AppDimens.windowDefaultHeight),
    minimumSize: Size(AppDimens.windowMinWidth, AppDimens.windowMinHeight),
    center: true,
    backgroundColor: AppColors.background,
    titleBarStyle: TitleBarStyle.normal,
    title: AppStrings.appName,
  );
  
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  
  runApp(const ProviderScope(child: SmartTwitchApp()));
}

class SmartTwitchApp extends ConsumerWidget {
  const SmartTwitchApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: AppColors.surface,
          contentTextStyle: TextStyle(color: AppColors.textPrimary),
        ),
      ),
      // Named routes for navigation
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
      onGenerateRoute: (settings) {
        // Handle /player/:channelLogin route
        if (settings.name?.startsWith('/player/') ?? false) {
          final channelLogin = settings.name!.substring('/player/'.length);
          return MaterialPageRoute(
            builder: (context) => PlayerScreen(channelLogin: channelLogin),
          );
        }
        return null;
      },
      // Show loading screen while checking auth, then route appropriately
      home: authState.isLoading
          ? const _AuthLoadingScreen()
          : const HomeScreen(),  // Always go to home, login is optional
    );
  }
}

/// Loading screen shown while checking authentication status
class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppColors.primary,
            ),
            SizedBox(height: AppDimens.paddingMedium),
            Text(
              AppStrings.textLoading,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
