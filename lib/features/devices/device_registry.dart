// File: lib/features/devices/device_registry.dart
// DeviceRegistry with a ValueListenable<List<String>> device list for panels.
// Fixes prior conflict by exposing only STATIC ValueListenable getter: DeviceRegistry.deviceList.
// Panels that previously used DeviceRegistry.I.deviceList must read DeviceRegistry.deviceList.

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../services/mqtt_service.dart';

class DeviceRegistry {
  DeviceRegistry._() {
    known.addListener(_recomputeList);
    _recomputeList();
  }
  static final DeviceRegistry I = DeviceRegistry._();

  // ValueListenable of sorted device IDs for UI bindings
  static ValueListenable<List<String>> get deviceList => I._deviceListVN;

  String _prefix = 'esp32server';
  int _deviceIndex = 1;

  final ValueNotifier<Set<String>> known =
      ValueNotifier<Set<String>>(<String>{});
  final ValueNotifier<List<String>> _deviceListVN =
      ValueNotifier<List<String>>(<String>[]);
  final ValueNotifier<String?> selected = ValueNotifier<String?>(null);

  StreamSubscription<List<dynamic>>? _sub;
  bool _running = false;

  void configure({required String prefix, required int deviceIndex}) {
    _prefix = prefix;
    _deviceIndex = deviceIndex;
  }

  Future<void> start() async {
    if (_running) return;
    _running = true;
    MqttService.I.subscribe('$_prefix/+/#');
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    try {
      MqttService.I.unsubscribe('$_prefix/+/#');
    } catch (_) {}
    await _sub?.cancel();
    _sub = null;
  }

  void addTopic(String topic) {
    final id = _extractDeviceId(topic);
    if (id == null || id.isEmpty) return;

    final next = Set<String>.from(known.value);
    if (!next.contains(id)) {
      next.add(id);
      known.value = next; // triggers recompute
      selected.value ??= id;
    }
  }

  void setSelected(String? id) {
    selected.value = id;
  }

  // Internal mirror to list
  void _recomputeList() {
    final list = known.value.toList()..sort();
    _deviceListVN.value = list;
  }

  String? _extractDeviceId(String topic) {
    if (!topic.startsWith('$_prefix/')) return null;
    final parts = topic.split('/');
    if (_deviceIndex < 0 || _deviceIndex >= parts.length) return null;
    final id = parts[_deviceIndex].trim();
    if (id.isEmpty || id == '+') return null;
    return id;
  }
}
