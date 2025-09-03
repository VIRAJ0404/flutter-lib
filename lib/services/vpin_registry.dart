// File: lib/services/vpin_registry.dart
// Persistent, live-locking VPin registry with V0..V100 support.
// - Global locks: any widget using a vPin makes it unavailable in others.
// - Live updates: reserve({oldPin,newPin}) updates locks immediately.
// - Persistence: start() rebuilds from saved pages; call rebuildFromPages(pages) after Save or edits.
// - Parsing: reads .vpin and also extracts from readTopic/writeTopic like "vpin/<PIN>".

import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';

class VpinRegistry {
  VpinRegistry._();
  static final VpinRegistry I = VpinRegistry._();

  // V0..V100 inclusive
  final List<String> allPins = List<String>.generate(101, (i) => 'V$i');

  // Live set of used pins
  final ValueNotifier<Set<String>> usedPins =
      ValueNotifier<Set<String>>(<String>{});

  bool _bootstrapped = false;

  // Idempotent: loads pages and rebuilds locks
  void start() {
    if (_bootstrapped) {
      _refreshFromStorage();
    } else {
      _bootstrapped = true;
      _refreshFromStorage();
    }
  }

  Future<void> _refreshFromStorage() async {
    try {
      final pages = await StorageService.loadPages();
      rebuildFromPages(pages);
    } catch (_) {
      // ignore storage issues; keep current locks
    }
  }

  // Recompute locks from pages (list of page models or map-like)
  void rebuildFromPages(List<dynamic> pages) {
    final next = <String>{};
    for (final p in pages) {
      final items = _readItems(p);
      for (final w in items) {
        for (final pin in _extractPinsFromWidget(w)) {
          next.add(pin);
        }
      }
    }
    if (!_setEquals(next, usedPins.value)) {
      usedPins.value = next;
    }
  }

  // Validate and return duplicates (pin -> count > 1)
  Map<String, int> validateUnique(List<dynamic> pages) {
    final counts = <String, int>{};
    for (final p in pages) {
      final items = _readItems(p);
      for (final w in items) {
        for (final pin in _extractPinsFromWidget(w)) {
          counts.update(pin, (c) => c + 1, ifAbsent: () => 1);
        }
      }
    }
    final dup = <String, int>{};
    counts.forEach((pin, c) {
      if (c > 1) dup[pin] = c;
    });
    return dup;
  }

  // Runtime lock management (immediate)
  void reserve({String? oldPin, String? newPin}) {
    final next = Set<String>.from(usedPins.value);
    if (oldPin != null && oldPin.isNotEmpty) next.remove(oldPin);
    if (newPin != null && newPin.isNotEmpty) next.add(newPin);
    if (!_setEquals(next, usedPins.value)) {
      usedPins.value = next;
    }
  }

  bool isUsed(String pin) => usedPins.value.contains(pin);
  bool isAvailable(String pin) => !isUsed(pin);

  // -------- internals --------

  List<dynamic> _readItems(dynamic page) {
    try {
      final v = page.items;
      if (v is List) return v;
    } catch (_) {}
    if (page is Map && page['items'] is List) {
      return List<dynamic>.from(page['items'] as List);
    }
    return const <dynamic>[];
  }

  Iterable<String> _extractPinsFromWidget(dynamic widgetModel) sync* {
    // vpin field
    try {
      final v = widgetModel.vpin?.toString();
      if (_isSupported(v)) yield v!;
    } catch (_) {
      if (widgetModel is Map) {
        final v = widgetModel['vpin']?.toString();
        if (_isSupported(v)) yield v!;
      }
    }
    // parse from topics
    String? readT;
    String? writeT;
    try {
      readT = widgetModel.readTopic?.toString();
    } catch (_) {
      if (widgetModel is Map) readT = widgetModel['readTopic']?.toString();
    }
    try {
      writeT = widgetModel.writeTopic?.toString();
    } catch (_) {
      if (widgetModel is Map) writeT = widgetModel['writeTopic']?.toString();
    }
    final r = _parsePinFromTopic(readT);
    if (_isSupported(r)) yield r!;
    final w = _parsePinFromTopic(writeT);
    if (_isSupported(w)) yield w!;
  }

  String? _parsePinFromTopic(String? t) {
    if (t == null) return null;
    final s = t.trim();
    if (s.isEmpty) return null;
    final m = RegExp(r'^vpin/([A-Za-z0-9_]+)(?:/.*)?$').firstMatch(s);
    return m?.group(1);
  }

  bool _isSupported(String? pin) {
    if (pin == null || pin.isEmpty) return false;
    return allPins.contains(pin);
  }

  bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    for (final e in a) {
      if (!b.contains(e)) return false;
    }
    return true;
  }
}
