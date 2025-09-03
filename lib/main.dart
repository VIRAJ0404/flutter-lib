// File: lib/main.dart
// Wires ThemeController into MaterialApp.themeMode and loads it before runApp.
// Keeps previous routes and structure.

import 'package:flutter/material.dart';
import 'app/theme.dart';
import 'app/splash.dart';
import 'app/shell.dart';
import 'features/dashboard/edit_home_page.dart';
import 'features/settings/settings_page.dart';
import 'features/history/history_page.dart';
import 'features/alerts/alert_rules_page.dart';
import 'features/devices/devices_page.dart';
import 'features/temperature/temperature_page.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.I.load();
  runApp(const FlexIoTApp());
}

class FlexIoTApp extends StatelessWidget {
  const FlexIoTApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.I.mode,
      builder: (_, mode, __) {
        return MaterialApp(
          title: 'FlexIoT',
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: mode, // System/Light/Dark
          home: const SplashScreen(),
          routes: {
            '/home': (_) => const HomeShell(),
            '/edit': (_) => const EditHomePage(),
            '/settings': (_) => const SettingsPage(),
            '/history': (_) => const HistoryPage(),
            '/alerts': (_) => const AlertRulesPage(),
            '/devices': (_) => const DevicesPage(),
            '/temperature': (_) => const TemperaturePage(),
          },
        );
      },
    );
  }
}
