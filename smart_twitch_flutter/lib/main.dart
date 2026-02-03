import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/home_screen.dart';
import 'utils/ui_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize window manager for desktop
  await windowManager.ensureInitialized();
  
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Colors.black,
    titleBarStyle: TitleBarStyle.normal,
    title: 'SmartTwitch Desktop',
  );
  
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  
  runApp(const ProviderScope(child: SmartTwitchApp()));
}

class SmartTwitchApp extends StatelessWidget {
  const SmartTwitchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartTwitch Desktop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: UIConfig.twitchDarkBg,
        colorScheme: const ColorScheme.dark(
          primary: UIConfig.twitchPurple,
          secondary: UIConfig.twitchPurple,
          surface: UIConfig.twitchSurface,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: UIConfig.twitchSurface,
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
