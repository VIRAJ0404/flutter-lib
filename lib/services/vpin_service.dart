// File: lib/services/vpin_service.dart
// Changes:
// - Added generics for maps and ValueNotifier to ensure type safety.
// - Kept tolerant parsing in latestDouble and onTopic.
// - No behavioral changes to write/onTopic contracts.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'mqtt_service.dart';

class VPinService {
  VPinService._();
  static final VPinService I = VPinService._();

  // Latest values by pin, typed for safety.
  final Map<String, dynamic> _latest = <String, dynamic>{};

  // Public notifier of all values.
  final ValueNotifier<Map<String, dynamic>> values =
      ValueNotifier<Map<String, dynamic>>(<String, dynamic>{});

  double? latestDouble(String pin) {
    final dynamic v = _latest[pin];
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    if (v is Map && v['value'] is num) return (v['value'] as num).toDouble();
    return null;
  }

  Future<void> write(String pin, dynamic value) async {
    await MqttService.I.ensureConnected();
    final String payload = jsonEncode({'pin': pin, 'value': value});
    MqttService.I.publish('vpin/$pin/set', payload);
  }

  // Wire this from MQTT client subscription handler.
  void onTopic(String topic, String payload) {
    final parts = topic.split('/');
    if (parts.isEmpty || parts.first != 'vpin') return;

    final String pin = (parts.length >= 2) ? parts[12] : '';
    if (pin.isEmpty) return;

    dynamic v = payload;

    // Try JSON first.
    try {
      final dynamic d = jsonDecode(payload);
      v = (d is Map && d.containsKey('value')) ? d['value'] : d;
    } catch (_) {
      // Not JSON, try number.
      final double? dv = double.tryParse(payload);
      if (dv != null) v = dv;
    }

    _latest[pin] = v;
    // Publish a new map instance so ValueNotifier listeners are notified.
    values.value = Map<String, dynamic>.from(_latest);
  }
}
