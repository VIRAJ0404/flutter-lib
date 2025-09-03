// lib/services/vpin_service.dart
// vPin MQTT binding: subscribes to base wildcards, parses messages, updates registry,
// exposes ValueListenable values, and provides write/latestDouble helpers used by widgets.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'mqtt_service.dart';
import 'vpin_registry.dart';

class VPinEvent {
  final String vpinId;
  final String topic;
  final dynamic value; // parsed JSON value or string
  final DateTime receivedAt;

  VPinEvent({
    required this.vpinId,
    required this.topic,
    required this.value,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();
}

class VPinServiceConfig {
  // Topic scheme:
  // - state:  {base}/{id}/state
  // - lock:   {base}/{id}/lock
  // - cmd:    {base}/{id}/cmd
  final String base; // default 'vpin'
  final bool retainStatePublishes;

  const VPinServiceConfig({
    this.base = 'vpin',
    this.retainStatePublishes = false,
  });

  String stateTopic(String vpinId) => '$base/$vpinId/state';
  String lockTopic(String vpinId) => '$base/$vpinId/lock';
  String cmdTopic(String vpinId) => '$base/$vpinId/cmd';

  String allStateWildcard() => '$base/+/state';
  String allLockWildcard() => '$base/+/lock';
}

class VPinService {
  // Singleton accessor for convenience in UI
  static final VPinService I = VPinService._internal();

  final MqttService _mqtt;
  final VpinRegistry _registry;
  final VPinServiceConfig _cfg;

  // Latest values by vpinId for quick lookup and ValueListenable UI bindings
  final ValueNotifier<Map<String, dynamic>> values =
      ValueNotifier<Map<String, dynamic>>({});

  final _eventsCtrl = StreamController<VPinEvent>.broadcast();
  Stream<VPinEvent> get events => _eventsCtrl.stream;

  factory VPinService() => I;

  VPinService._internal({
    MqttService? mqtt,
    VpinRegistry? registry,
    VPinServiceConfig cfg = const VPinServiceConfig(),
  })  : _mqtt = (mqtt ?? MqttService.I),
        _registry = (registry ?? VpinRegistry.I),
        _cfg = cfg;

  VPinService._withDeps({
    required MqttService mqtt,
    required VpinRegistry registry,
    VPinServiceConfig cfg = const VPinServiceConfig(),
  })  : _mqtt = mqtt,
        _registry = registry,
        _cfg = cfg;

  bool _subscribed = false;

  void ensureSubscribed() {
    if (_subscribed) return;
    // Subscribe with QoS1 to avoid losing updates across reconnects
    _mqtt.subscribe(_cfg.allStateWildcard(), qos: MqttQos.atLeastOnce);
    _mqtt.subscribe(_cfg.allLockWildcard(), qos: MqttQos.atLeastOnce);

    _mqtt.inboundStream.listen(_onInbound, onError: (e, st) {
      debugPrint('[vPin] inbound error: $e');
    });
    _subscribed = true;
  }

  // Publish command to vPin
  Future<void> sendCommand(String vpinId, Map<String, dynamic> jsonPayload,
      {MqttQos qos = MqttQos.atLeastOnce}) async {
    final topic = _cfg.cmdTopic(vpinId);
    final payload = json.encode(jsonPayload);
    await _mqtt.publish(topic, payload, qos: qos, retain: false);
  }

  // Convenience API used by widgets: write a simple value or a full command map
  Future<void> write(String vpinId, dynamic value,
      {MqttQos qos = MqttQos.atLeastOnce}) async {
    if (value is Map<String, dynamic>) {
      await sendCommand(vpinId, value, qos: qos);
    } else {
      await sendCommand(vpinId, {'value': value}, qos: qos);
    }
  }

  // Publish state
  Future<void> publishState(String vpinId, dynamic value,
      {MqttQos qos = MqttQos.atLeastOnce}) async {
    final topic = _cfg.stateTopic(vpinId);
    final String payload =
        value is String ? value : json.encode({'value': value});
    await _mqtt.publish(topic, payload,
        qos: qos, retain: _cfg.retainStatePublishes);
  }

  // Request/release lock
  Future<void> setLock(String vpinId, bool locked,
      {String? owner,
      DateTime? expiresAt,
      MqttQos qos = MqttQos.atLeastOnce}) async {
    final topic = _cfg.lockTopic(vpinId);
    final payload = json.encode({
      'vpinId': vpinId,
      'locked': locked,
      if (owner != null) 'owner': owner,
      if (expiresAt != null) 'expiresAt': expiresAt.toUtc().toIso8601String(),
    });
    await _mqtt.publish(topic, payload, qos: qos, retain: false);
  }

  VpinRegistry get registry => _registry;

  // Returns a non-null double for UI convenience to avoid nullable toDouble() errors in widgets_gallery.
  double latestDouble(String vpinId, {double fallback = 0.0}) {
    final v = values.value[vpinId];
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    if (v is String) {
      final parsed = double.tryParse(v);
      return parsed ?? fallback;
    }
    if (v is Map<String, dynamic>) {
      final inner = v['value'];
      if (inner is num) return inner.toDouble();
      if (inner is String) return double.tryParse(inner) ?? fallback;
    }
    return fallback;
  }

  // Internal routing for inbound messages
  void _onInbound(MqttInbound msg) {
    final topic = msg.topic;
    if (!topic.startsWith('${_cfg.base}/')) return;

    final parts = topic.split('/');
    if (parts.length < 3) return;
    final id = parts[1];
    final type = parts[2];

    final str = msg.payloadString;
    final dynamic jsonVal = msg.payloadJson;

    if (type == 'state') {
      final dynamic val = jsonVal ?? str;
      // Update values notifier map
      final next = Map<String, dynamic>.from(values.value);
      next[id] = val is Map<String, dynamic> && val.containsKey('value')
          ? val['value']
          : val;
      values.value = next;

      _eventsCtrl.add(VPinEvent(
        vpinId: id,
        topic: topic,
        value: val,
      ));
    } else if (type == 'lock') {
      _registry.applyLockMessage(id, str);
      _eventsCtrl.add(VPinEvent(
        vpinId: id,
        topic: topic,
        value: jsonVal ?? str,
      ));
    }
  }

  void dispose() {
    _eventsCtrl.close();
    values.dispose();
  }
}
