// File: lib/services/storage_service.dart
// Centralized key-value persistence using SharedPreferences.
// Features:
// - MQTT settings (host, port, username, password, clientId)
// - Legacy single-canvas layout (for backward compatibility)
// - Multi-page dashboard persistence (DashPageModel with DashWidget list)
// - Selected device id and device parser config
// - Alert rules (as JSON list)
// - pagesChanged notifier: emits a tick whenever layouts/pages are saved so UI can auto-reload.

import 'dart:convert';
import 'dart:ui'; // for Offset, Size in default seeds
import 'package:flutter/foundation.dart'; // for ValueNotifier
import 'package:shared_preferences/shared_preferences.dart';
import '../features/dashboard/models.dart';

class StorageService {
  // Keys
  static const _kMqtt = 'mqtt_settings';
  static const _kLayoutLegacy =
      'dashboard_layout_v1'; // legacy single widget list
  static const _kPages = 'dashboard_pages_v1'; // new multi-page structure
  static const _kDeviceSelected = 'device_selected';
  static const _kDeviceConfig = 'device_config_v1';
  static const _kAlertRules = 'alert_rules_v1';

  // Emits a tick when layouts/pages persist, allowing listeners (Home) to reload.
  static final pagesChanged = ValueNotifier<int>(0);

  // -------------------- MQTT --------------------

  static Future<void> saveMqtt(Map<String, dynamic> json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMqtt, jsonEncode(json));
  }

  static Future<Map<String, dynamic>?> loadMqtt() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kMqtt);
    if (s == null) return null;
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      return m;
    } catch (_) {
      return null;
    }
  }

  // -------------------- Legacy single-canvas layout --------------------

  static Future<void> saveLayout(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLayoutLegacy, jsonEncode(items));
    pagesChanged.value++; // notify anyone listening
  }

  static Future<List<Map<String, dynamic>>?> loadLayout() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kLayoutLegacy);
    if (s == null) return null;
    try {
      final list = jsonDecode(s) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  // -------------------- Multi-page persistence --------------------

  static Future<void> savePages(List<DashPageModel> pages) async {
    final prefs = await SharedPreferences.getInstance();
    final json = {
      'pages': pages.map((p) => p.toJson()).toList(),
    };
    await prefs.setString(_kPages, jsonEncode(json));
    pagesChanged.value++; // notify
  }

  static Future<List<DashPageModel>> loadPages() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kPages);
    if (s != null) {
      try {
        final map = jsonDecode(s) as Map<String, dynamic>;
        final list = (map['pages'] as List<dynamic>? ?? const []);
        return list
            .map((e) => DashPageModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        // fall through to migration/default
      }
    }

    // Migrate legacy layout if present
    final legacy = await loadLayout();
    if (legacy != null) {
      final widgets = legacy.map((e) => DashWidget.fromJson(e)).toList();
      return [
        DashPageModel(id: 'page1', title: 'Page 1', items: widgets),
      ];
    }

    // Fresh default: one page with a KPI widget seed
    return [
      DashPageModel(id: 'page1', title: 'Page 1', items: [
        DashWidget(
          id: 'kpi1',
          kind: WidgetKind.kpi,
          title: 'Temp',
          position: const Offset(24, 24),
          size: const Size(160, 100),
          readTopic: 'esp32server/{device}/temp',
          unit: '°C',
        ),
      ]),
    ];
  }

  // -------------------- Device selection/config --------------------

  static Future<void> saveSelectedDevice(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null || id.isEmpty) {
      await prefs.remove(_kDeviceSelected);
    } else {
      await prefs.setString(_kDeviceSelected, id);
    }
  }

  static Future<String?> loadSelectedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kDeviceSelected);
  }

  static Future<void> saveDeviceConfig(Map<String, dynamic> cfg) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDeviceConfig, jsonEncode(cfg));
  }

  static Future<Map<String, dynamic>?> loadDeviceConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kDeviceConfig);
    if (s == null) return null;
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      return m;
    } catch (_) {
      return null;
    }
  }

  // -------------------- Alert rules --------------------

  static Future<void> saveAlertRules(List<Map<String, dynamic>> rules) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAlertRules, jsonEncode(rules));
  }

  static Future<List<Map<String, dynamic>>> loadAlertRules() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kAlertRules);
    if (s == null) return const [];
    try {
      final list = jsonDecode(s) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return const [];
    }
  }

  // -------------------- Utilities (optional) --------------------

  // Clears only page layout data (useful for debugging)
  static Future<void> clearPages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPages);
    pagesChanged.value++;
  }

  // Clears legacy layout only
  static Future<void> clearLegacyLayout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLayoutLegacy);
    pagesChanged.value++;
  }
}
