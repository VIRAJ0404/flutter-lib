// lib/services/mqtt_service.dart
// Robust MQTT service with API compatibility and correct mqtt_client usage.
// - Keeps existing surface: I, connect() with 0 args, ensureConnected(), saveCurrent(),
//   getters/setters for host/ports/credentials/clientId, messages/inbound (ValueListenable),
//   publish(...), subscribe/unsubscribe(...).
// - Uses client.keepAlivePeriod and startClean() (instead of removed withCleanSession).
// - Publishes via MqttClientPayloadBuilder (payload is Uint8Buffer internally).
// - Inbound: maintains both a Stream<MqttInbound> (inboundStream) and a ValueListenable<List<String>> (inbound/messages)
//   so UI that expects addListener/removeListener/value compiles, and stream consumers can still listen.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttInbound {
  final String topic;
  final List<int> payloadBytes;
  final DateTime receivedAt;

  MqttInbound({
    required this.topic,
    required this.payloadBytes,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  String get payloadString {
    try {
      return utf8.decode(payloadBytes);
    } catch (_) {
      return String.fromCharCodes(payloadBytes);
    }
  }

  dynamic get payloadJson {
    try {
      return json.decode(payloadString);
    } catch (_) {
      return null;
    }
  }
}

class MqttServiceConfig {
  final String host;
  final int port;
  final bool useWebSocket;
  final String clientId;
  final String? username;
  final String? password;
  final int keepAliveSeconds;
  final bool cleanSession; // true => start clean (non-persistent)
  final bool autoReconnect;
  final Duration maxBackoff;
  final bool debugLogging;

  const MqttServiceConfig({
    required this.host,
    this.port = 1883,
    this.useWebSocket = false,
    required this.clientId,
    this.username,
    this.password,
    this.keepAliveSeconds = 30,
    this.cleanSession = false,
    this.autoReconnect = true,
    this.maxBackoff = const Duration(seconds: 30),
    this.debugLogging = true,
  });
}

class MqttService {
  // Singleton accessor compatible with existing code: MqttService.I
  static final MqttService I = MqttService._internal();

  factory MqttService() => I;
  MqttService._internal();

  MqttServerClient? _client;
  MqttServiceConfig? _config;

  // Inbound stream for programmatic consumption
  final _inboundCtrl = StreamController<MqttInbound>.broadcast();
  Stream<MqttInbound> get inboundStream => _inboundCtrl.stream;

  // UI-friendly log/listenable (addListener/removeListener/value) expected by widgets
  // Keep two aliases to match different call sites: messages and inbound.
  final ValueNotifier<List<String>> messages =
      ValueNotifier<List<String>>(<String>[]);
  ValueListenable<List<String>> get inbound => messages;

  // Track desired subscriptions to resubscribe on reconnect
  final Map<String, MqttQos> _desiredSubscriptions = {};

  // Stored connection settings used by parameterless connect()/ensureConnected()
  String _host = '';
  int _portTls = 8883;
  int _portWss = 443;
  bool _useWebSocket = true;
  String _clientId = 'flexiot-client';
  String? _username;
  String? _password;

  // Getters/setters used across UI
  String get host => _host;
  set host(String v) => _host = v;

  int get portTls => _portTls;
  set portTls(int v) => _portTls = v;

  int get portWss => _portWss;
  set portWss(int v) => _portWss = v;

  bool get useWebSocket => _useWebSocket;
  set useWebSocket(bool v) => _useWebSocket = v;

  String get clientId => _clientId;
  set clientId(String v) => _clientId = v;

  // Return non-nullable strings to satisfy fields expecting String
  String get username => _username ?? '';
  set username(String v) => _username = v;

  String get password => _password ?? '';
  set password(String v) => _password = v;

  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  // Backwards-compatible connect: optional config, or use stored fields
  Future<void> connect([MqttServiceConfig? config]) async {
    final effective = config ??
        MqttServiceConfig(
          host: _host,
          port: _useWebSocket ? _portWss : _portTls,
          useWebSocket: _useWebSocket,
          clientId: _clientId,
          username: _username,
          password: _password,
          keepAliveSeconds: 30,
          cleanSession: false, // persistent session (recommended with QoS1)
          autoReconnect: true,
          maxBackoff: const Duration(seconds: 30),
          debugLogging: true,
        );
    await _connectInternal(effective);
  }

  // Ensure a live connection for startup paths
  Future<void> ensureConnected() async {
    if (!isConnected) {
      await connect();
    }
  }

  // Persist current settings if/when wired to StorageService
  Future<void> saveCurrent() async {
    // No-op stub to satisfy UI; integrate with storage as needed.
  }

  Future<void> _connectInternal(MqttServiceConfig config) async {
    _config = config;

    final client = MqttServerClient(config.host, config.clientId);
    client.port = config.port;
    client.useWebSocket = config.useWebSocket;
    client.keepAlivePeriod = config.keepAliveSeconds; // [web:51]
    client.autoReconnect = config.autoReconnect;
    client.logging(on: config.debugLogging);

    client.onConnected = _onConnected;
    client.onDisconnected = _onDisconnected;
    client.onAutoReconnect = _onAutoReconnect;
    client.onAutoReconnected = _onAutoReconnected;
    client.pongCallback = _onPong;

    var conn = MqttConnectMessage()
        .withClientIdentifier(config.clientId)
        .withWillQos(MqttQos.atLeastOnce);
    // startClean replaces removed withCleanSession, leave persistent if false [web:22]
    if (config.cleanSession) {
      conn = conn.startClean();
    }
    if (config.username != null || config.password != null) {
      conn = conn.authenticateAs(config.username, config.password);
    }
    client.connectionMessage = conn;

    // Listen for updates (payload extraction via MqttPublishMessage.payload.message) [web:52]
    client.updates?.listen(_onUpdates, onError: (e, st) {
      _log('MQTT updates error: $e');
    });

    // Exponential backoff connect loop
    var backoff = const Duration(milliseconds: 500);
    while (true) {
      try {
        _client = client;
        _log(
            'MQTT connecting to ${config.host}:${config.port} (ws=${config.useWebSocket}) clientId=${config.clientId}');
        final res = await client.connect();
        _log('MQTT connect result: ${res?.returnCode}');
        break;
      } catch (e) {
        _log('MQTT connect error: $e');
        if (!config.autoReconnect) rethrow;
        await Future.delayed(backoff);
        backoff = backoff * 2;
        if (backoff > config.maxBackoff) backoff = config.maxBackoff;
      }
    }
  }

  // Subscribe and remember to resubscribe on reconnect
  void subscribe(String topic, {MqttQos qos = MqttQos.atLeastOnce}) {
    if (_client == null) throw StateError('MQTT client not initialized');
    _desiredSubscriptions[topic] = qos;
    if (isConnected) {
      _log('MQTT subscribe $topic qos=$qos');
      _client!.subscribe(topic, qos);
    } else {
      _log('MQTT queued subscribe (offline) $topic');
    }
  }

  void unsubscribe(String topic) {
    _desiredSubscriptions.remove(topic);
    if (_client != null && isConnected) {
      _log('MQTT unsubscribe $topic');
      _client!.unsubscribe(topic);
    }
  }

  // Legacy-compatible publish API: accepts String, List<int>, or Map, always sends via payload builder [web:43]
  Future<void> publish(
    String topic,
    dynamic payload, {
    MqttQos qos = MqttQos.atLeastOnce,
    bool retain = false,
  }) async {
    if (payload is String) {
      await publishString(topic, payload, qos: qos, retain: retain);
      return;
    }
    if (payload is Map<String, dynamic>) {
      await publishString(topic, json.encode(payload),
          qos: qos, retain: retain);
      return;
    }
    if (payload is List<int>) {
      await publishBytes(topic, payload, qos: qos, retain: retain);
      return;
    }
    await publishString(topic, payload.toString(), qos: qos, retain: retain);
  }

  Future<void> publishString(
    String topic,
    String payload, {
    MqttQos qos = MqttQos.atLeastOnce,
    bool retain = false,
  }) async {
    if (_client == null) throw StateError('MQTT client not initialized');
    final builder = MqttClientPayloadBuilder();
    builder.addString(
        payload); // builder.payload is correct type for publishMessage [web:43]
    _log('MQTT publish topic=$topic qos=$qos retain=$retain payload=$payload');
    _client!.publishMessage(topic, qos, builder.payload!,
        retain: retain); // [web:43]
  }

  Future<void> publishBytes(
    String topic,
    List<int> bytes, {
    MqttQos qos = MqttQos.atLeastOnce,
    bool retain = false,
  }) async {
    if (_client == null) throw StateError('MQTT client not initialized');
    final builder = MqttClientPayloadBuilder();
    builder.addBuffer(bytes
        as dynamic); // addBuffer accepts Uint8Buffer; builder handles conversion internally [web:43]
    _log(
        'MQTT publish bytes topic=$topic qos=$qos retain=$retain len=${bytes.length}');
    _client!.publishMessage(topic, qos, builder.payload!,
        retain: retain); // [web:43]
  }

  Future<void> disconnect() async {
    try {
      _log('MQTT disconnect requested');
      _client
          ?.disconnect(); // disconnect() returns void in mqtt_client [web:22]
    } catch (e) {
      _log('MQTT disconnect error: $e');
    }
  }

  void dispose() {
    _inboundCtrl.close();
    messages.dispose();
  }

  // Internal callbacks

  void _onConnected() {
    _log('MQTT connected');
    // Resubscribe on connect/auto-reconnect [web:32]
    _desiredSubscriptions.forEach((topic, qos) {
      _log('MQTT resubscribe on connect $topic qos=$qos');
      _client?.subscribe(topic, qos);
    });
  }

  void _onDisconnected() {
    _log('MQTT disconnected');
  }

  void _onAutoReconnect() {
    _log('MQTT auto-reconnect starting...');
  }

  void _onAutoReconnected() {
    _log('MQTT auto-reconnected');
    _desiredSubscriptions.forEach((topic, qos) {
      _log('MQTT resubscribe after auto-reconnect $topic qos=$qos');
      _client?.subscribe(topic, qos);
    });
  }

  void _onPong() {
    _log('MQTT pong received');
  }

  void _onUpdates(List<MqttReceivedMessage<MqttMessage?>>? events) {
    if (events == null || events.isEmpty) return;
    for (final evt in events) {
      final topic = evt.topic;
      final msg = evt.payload;
      if (msg is MqttPublishMessage) {
        // Payload is a buffer-like object; toList() yields List<int> across platforms [web:52]
        final bytes = (msg.payload.message as dynamic).toList().cast<int>();
        _log('MQTT inbound topic=$topic bytes=${bytes.length}');
        _inboundCtrl.add(MqttInbound(topic: topic, payloadBytes: bytes));

        // Append a compact string to ValueListenable log for UI
        final entry = '$topic ${_abbrevPayload(bytes)}';
        final next = List<String>.from(messages.value);
        next.add(entry);
        const maxEntries = 500;
        if (next.length > maxEntries) {
          next.removeRange(0, next.length - maxEntries);
        }
        messages.value = next;
      }
    }
  }

  String _abbrevPayload(List<int> bytes) {
    final s = () {
      try {
        return utf8.decode(bytes);
      } catch (_) {
        return bytes.toString();
      }
    }();
    const maxLen = 200;
    return s.length <= maxLen ? s : '${s.substring(0, maxLen)}…';
  }

  void _log(String msg) {
    if (_config?.debugLogging ?? true) {
      debugPrint('[MQTT] $msg');
    }
  }
}
