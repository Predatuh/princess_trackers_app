import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/video_transition_screen.dart';
import 'screens/main_shell.dart';
import 'screens/block_detail_screen.dart';
import 'screens/ifc_viewer_screen.dart';

void main() {
  runApp(
    DevicePreview(
      enabled: kIsWeb, // only show the device frame when running as web
      builder: (_) => ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const PrincessTrackersApp(),
      ),
    ),
  );
}

class PrincessTrackersApp extends StatelessWidget {
  const PrincessTrackersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Princess Trackers',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/video':
            return PageRouteBuilder(
              settings: settings,
              transitionDuration: const Duration(milliseconds: 520),
              reverseTransitionDuration: Duration.zero,
              pageBuilder: (_, __, ___) => const VideoTransitionScreen(),
              transitionsBuilder: (_, __, ___, child) => child,
            );
          case '/home':
            return MaterialPageRoute(builder: (_) => const MainShell());
          case '/block':
            return MaterialPageRoute(
              builder: (_) => const BlockDetailScreen(),
              settings: settings,
            );
          case '/ifc':
            return MaterialPageRoute(
              builder: (_) => const IfcViewerScreen(),
              settings: settings,
            );
          default:
            return MaterialPageRoute(builder: (_) => const LoginScreen());
        }
      },
    );
  }
}

