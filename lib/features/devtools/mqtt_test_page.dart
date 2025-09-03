// File: lib/features/devtools/mqtt_test_page.dart
// Removed unused dart:io import; onBadCertificate uses dynamic.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

enum TestTransport { wss8084, tls8883 }

class MqttTestPage extends StatefulWidget {
  const MqttTestPage({super.key});
  @override
  State<MqttTestPage> createState() => _MqttTestPageState();
}

class _MqttTestPageState extends State<MqttTestPage> {
  final hostC =
      TextEditingController(text: 'm644c068.ala.asia-southeast1.emqxsl.com');
  final clientIdC = TextEditingController(text: 'smartsolar');
  final userC = TextEditingController(text: 'Viraj23');
  final passC = TextEditingController(text: 'VIRAJ23');
  final topicSubC = TextEditingController(text: 'testtopic/1');
  final topicPubC = TextEditingController(text: 'testtopic/1');
  final payloadC =
      TextEditingController(text: '{"type":"state","pin":"V1","value":45}');

  TestTransport transport = TestTransport.tls8883;

  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage?>>>? _sub;
  bool get _connected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  final List<String> _log = <String>[];

  String _normalizeHost(String raw) {
    var h = raw.trim();
    h = h.replaceFirst(RegExp(r'^\s*https?://', caseSensitive: false), '');
    final slash = h.indexOf('/');
    if (slash != -1) h = h.substring(0, slash);
    final colon = h.indexOf(':');
    if (colon != -1) h = h.substring(0, colon);
    return h;
  }

  void _logLine(String s) {
    setState(() {
      _log.insert(0, s);
      if (_log.length > 400) _log.removeLast();
    });
  }

  Future<void> _connect() async {
    await _disconnect();

    final host = _normalizeHost(hostC.text);
    final clientId = clientIdC.text.trim();
    final username = userC.text.trim();
    final password = passC.text;
    final port = transport == TestTransport.wss8084 ? 8084 : 8883;

    final c = MqttServerClient.withPort(host, clientId, port);
    _client = c;

    if (transport == TestTransport.wss8084) {
      c.useWebSocket = true;
      c.secure = true;
      c.websocketProtocols =
          MqttClientConstants.protocolsSingleDefault; // 'mqtt'
    } else {
      c.secure = true;
    }

    c.keepAlivePeriod = 30;
    c.autoReconnect = true;
    c.resubscribeOnAutoReconnect = true;
    c.logging(on: false);
    c.onBadCertificate = (dynamic _) => true; // no dart:io import needed

    c.onConnected = () => _logLine('Connected (${transport.name})');
    c.onDisconnected = () {
      final st = c.connectionStatus;
      _logLine(
          'Disconnected. state=${st?.state} rc=${st?.returnCode} (${st?.returnCode?.name})');
    };
    c.onAutoReconnected = () => _logLine('Auto-reconnected');

    final will = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillTopic('app/clients/$clientId/lastwill')
        .withWillMessage('offline')
        .withWillQos(MqttQos.atLeastOnce);
    c.connectionMessage = will;

    try {
      _logLine('Connecting to $host:$port as $clientId ...');
      await c.connect(username, password);
    } catch (e) {
      _logLine('Connect exception: $e');
      try {
        c.disconnect();
      } catch (_) {}
      return;
    }

    final st = c.connectionStatus;
    _logLine('ConnectionStatus: state=${st?.state} rc=${st?.returnCode}');
    if (!_connected) {
      _logLine('Connect failed, closing.');
      try {
        c.disconnect();
      } catch (_) {}
      return;
    }

    _sub = c.updates?.listen((events) {
      if (events.isEmpty) return;
      final msg = events.first.payload as MqttPublishMessage;
      final t = events.first.topic;
      final p = MqttPublishPayload.bytesToStringAsString(msg.payload.message);
      _logLine('<= [$t] $p');
    }, onError: (e, st) {
      _logLine('Stream error: $e');
    });
  }

  void _subscribe(String topic) {
    if (!_connected || topic.isEmpty) return;
    _client!.subscribe(topic, MqttQos.atLeastOnce);
    _logLine('Subscribed $topic');
  }

  void _publish() {
    if (!_connected) return;
    final t = topicPubC.text.trim();
    final p = payloadC.text;
    final b = MqttClientPayloadBuilder()..addString(p);
    _client!.publishMessage(t, MqttQos.atLeastOnce, b.payload!);
    _logLine('=> [$t] $p');
  }

  Future<void> _quickTest() async {
    await _connect();
    if (!_connected) return;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    _subscribe(topicSubC.text.trim());
    await Future<void>.delayed(const Duration(milliseconds: 250));
    _publish();
  }

  Future<void> _disconnect() async {
    await _sub?.cancel();
    _sub = null;
    try {
      _client?.disconnect();
    } catch (_) {}
    _client = null;
  }

  @override
  void dispose() {
    _disconnect();
    hostC.dispose();
    clientIdC.dispose();
    userC.dispose();
    passC.dispose();
    topicSubC.dispose();
    topicPubC.dispose();
    payloadC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = _connected;
    return Scaffold(
      appBar: AppBar(title: const Text('MQTT Connection Tester')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: hostC,
                          decoration: const InputDecoration(
                              labelText: 'Host (emqx endpoint)'))),
                  const SizedBox(width: 12),
                  DropdownButton<TestTransport>(
                    value: transport,
                    onChanged: (v) =>
                        setState(() => transport = v ?? TestTransport.tls8883),
                    items: const [
                      DropdownMenuItem(
                          value: TestTransport.wss8084,
                          child: Text('WSS 8084')),
                      DropdownMenuItem(
                          value: TestTransport.tls8883,
                          child: Text('TLS 8883')),
                    ],
                  ),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: clientIdC,
                          decoration: const InputDecoration(
                              labelText: 'Client ID (authorized)'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextField(
                          controller: userC,
                          decoration:
                              const InputDecoration(labelText: 'Username'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextField(
                          controller: passC,
                          decoration:
                              const InputDecoration(labelText: 'Password'),
                          obscureText: true)),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: topicSubC,
                          decoration: const InputDecoration(
                              labelText: 'Subscribe Topic'),
                          onSubmitted: _subscribe)),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                      onPressed: () => _subscribe(topicSubC.text.trim()),
                      icon: const Icon(Icons.subscriptions),
                      label: const Text('Subscribe')),
                ]),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: topicPubC,
                          decoration: const InputDecoration(
                              labelText: 'Publish Topic'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextField(
                          controller: payloadC,
                          decoration:
                              const InputDecoration(labelText: 'Payload'))),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                      onPressed: _publish,
                      icon: const Icon(Icons.send),
                      label: const Text('Publish')),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  FilledButton.icon(
                    onPressed: connected ? null : _connect,
                    icon: const Icon(Icons.cloud_done),
                    label: Text(connected ? 'Connected' : 'Connect'),
                  ),
                  OutlinedButton.icon(
                    onPressed: connected ? _disconnect : null,
                    icon: const Icon(Icons.link_off),
                    label: const Text('Disconnect'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _quickTest,
                    icon: const Icon(Icons.flash_on),
                    label: const Text('Quick Test'),
                  ),
                ]),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _log.length,
              itemBuilder: (_, i) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(_log[i],
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
