// File: lib/services/mqtt_service.dart
// Secure MQTT client for EMQX Cloud (TLS 8883 / WSS 8084), with vPin bridge to VPinService.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../features/data/topic_store.dart' as ts;
import 'vpin_service.dart';

enum MqttTransport { tcpTls, wss }

class MqttService {
  MqttService._();
  static final MqttService I = MqttService._();

  // Broker
  String host = 'm644c068.ala.asia-southeast1.emqxsl.com';
  int portTls = 8883;
  int portWss = 8084;
  String clientId = 'smartsolar';
  String username = 'Viraj23';
  String password = 'VIRAJ23';
  MqttTransport transport = MqttTransport.tcpTls;

  // Auto-subscribe filters
  final List<String> subscribeTopics = <String>[
    'vpin/#', // all virtual pin topics
    'esp32server/#', // legacy device streams
    'testtopic/#', // tester
  ];

  // Command base normalization (optional)
  String appCommandBase = 'appserver';

  // Terminal feed
  final ValueNotifier<List<String>> messages =
      ValueNotifier<List<String>>(<String>[]);

  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _sub;

  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  Future<void> ensureConnected() async {
    if (!isConnected) await connect();
  }

  Future<void> connect() async {
    await _teardown();

    final int port = (transport == MqttTransport.tcpTls) ? portTls : portWss;
    final client = MqttServerClient.withPort(host, clientId, port);
    _client = client;

    if (transport == MqttTransport.wss) {
      client.useWebSocket = true;
      client.secure = true;
      client.websocketProtocols =
          MqttClientConstants.protocolsSingleDefault; // 'mqtt'
    } else {
      client.secure = true;
    }

    client.keepAlivePeriod = 30;
    client.autoReconnect = true;
    client.resubscribeOnAutoReconnect = true;
    client.logging(on: false);

    // Dev-only: accept any cert (replace with CA pinning for prod)
    client.onBadCertificate = (dynamic _) => true;

    client.onConnected = () => _log('connected (${transport.name})');
    client.onDisconnected = () {
      final st = client.connectionStatus;
      _log('disconnected state=${st?.state} rc=${st?.returnCode}');
    };
    client.onAutoReconnected = () => _log('auto-reconnected');

    final willTopic = 'app/clients/$clientId/lastwill';
    final conn = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillTopic(willTopic)
        .withWillMessage('offline')
        .withWillQos(MqttQos.atLeastOnce);
    client.connectionMessage = conn;

    try {
      _log('connecting to $host:$port as $clientId ...');
      await client.connect(username, password);
    } on NoConnectionException catch (e) {
      _log('NoConnectionException: $e');
      client.disconnect();
      rethrow;
    } on SocketException catch (e) {
      _log('SocketException: $e');
      client.disconnect();
      rethrow;
    }

    final st = client.connectionStatus;
    _log('status state=${st?.state} rc=${st?.returnCode}');
    if (!isConnected) {
      throw StateError('MQTT connect failed: ${client.connectionStatus}');
    }

    // Subscribe filters
    for (final t in subscribeTopics) {
      client.subscribe(t, MqttQos.atLeastOnce);
    }

    // Inbound messages
    _sub = client.updates?.listen(_onMessage, onError: (e, st) {
      _log('stream error: $e');
    });
  }

  void publish(String topic, String payload,
      {MqttQos qos = MqttQos.atLeastOnce, bool retain = false}) {
    if (!isConnected) return;
    if (topic == 'app/cmd') topic = '$appCommandBase/cmd';
    final b = MqttClientPayloadBuilder()..addString(payload);
    _client!.publishMessage(topic, qos, b.payload!, retain: retain);
  }

  void subscribe(String topic, {MqttQos qos = MqttQos.atLeastOnce}) {
    if (!isConnected) return;
    _client!.subscribe(topic, qos);
  }

  void unsubscribe(String topic) {
    if (!isConnected) return;
    _client!.unsubscribe(topic);
  }

  void disconnect() {
    _client?.disconnect();
  }

  Future<void> saveCurrent() async {
    _log('settings saved (memory only)');
  }

  // ------- internals -------

  void _onMessage(List<MqttReceivedMessage<MqttMessage>>? events) {
    if (events == null || events.isEmpty) return;
    final rec = events.first;
    final topic = rec.topic;
    final msg = rec.payload as MqttPublishMessage;

    // Decode UTF-8 bytes to string safely
    final payload = MqttPublishPayload.bytesToStringAsString(
        msg.payload.message); // utf8 [web]

    // 1) Feed generic TopicStore for terminal/analytics
    ts.TopicStore.I.ingest(topic, payload);

    // 2) Bridge vPin topics so KPI/LED/Labeled widgets update
    if (topic.startsWith('vpin/')) {
      VPinService.I.onTopic(topic, payload);
    }

    // 3) Append to terminal (cap 100)
    final list = List<String>.from(messages.value);
    list.insert(0, '$topic $payload');
    if (list.length > 100) list.removeLast();
    messages.value = list;
  }

  Future<void> _teardown() async {
    await _sub?.cancel();
    _sub = null;
    try {
      _client?.disconnect();
    } catch (_) {}
    _client = null;
  }

  void _log(String m) => debugPrint('[MQTT] $m');
}
