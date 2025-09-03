// File: lib/services/theme_service.dart
// Theme controller with persistence (System/Light/Dark) using SharedPreferences.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  ThemeController._();
  static final ThemeController I = ThemeController._();

  final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  static const _kThemeMode = 'app_theme_mode'; // 'system' | 'light' | 'dark'

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kThemeMode) ?? 'system';
    switch (s) {
      case 'light':
        mode.value = ThemeMode.light;
        break;
      case 'dark':
        mode.value = ThemeMode.dark;
        break;
      default:
        mode.value = ThemeMode.system;
    }
  }

  Future<void> set(ThemeMode m) async {
    mode.value = m;
    final prefs = await SharedPreferences.getInstance();
    final s = m == ThemeMode.light
        ? 'light'
        : m == ThemeMode.dark
            ? 'dark'
            : 'system';
    await prefs.setString(_kThemeMode, s);
  }
}
