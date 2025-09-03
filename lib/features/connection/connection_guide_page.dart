// File: lib/features/connection/connection_guide_page.dart
// ignore_for_file: unnecessary_string_escapes
// The Arduino/C snippet intentionally escapes quotes inside JSON strings.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/mqtt_service.dart';

class ConnectionGuidePage extends StatelessWidget {
  const ConnectionGuidePage({super.key});

  void _copy(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = MqttService.I;

    final esp32Snippet = '''
// ========= ESP32 (Arduino) TLS 8883 example =========
// Libraries: WiFi.h, WiFiClientSecure.h, PubSubClient.h
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>

const char* WIFI_SSID = "YOUR_WIFI_SSID";
const char* WIFI_PASS = "YOUR_WIFI_PASS";

// EMQX Cloud broker (TLS)
const char* MQTT_HOST = "${s.host}";
const int   MQTT_PORT = ${s.portTls}; // 8883
const char* MQTT_USER = "${s.username}";
const char* MQTT_PASS = "${s.password}";
const char* CLIENT_ID = "esp32controller1"; // must be authorized in EMQX ACL

// Topics
const char* TOPIC_TELE      = "esp32server/state";
const char* TOPIC_CMD       = "appserver/cmd";
const char* TOPIC_VPIN1     = "vpin/V1";
const char* TOPIC_VPIN1_SET = "vpin/V1/set";

WiFiClientSecure wifiSecure;
PubSubClient mqtt(wifiSecure);

void onMqttMessage(char* topic, byte* payload, unsigned int len) {
  String msg;
  for (unsigned int i = 0; i < len; i++) msg += (char)payload[i];
  // Handle commands sent from app on appserver/cmd or vpin/*/set
  // Example payload: {"pin":"V1","value":45}
}

void ensureWifi() {
  if (WiFi.status() == WL_CONNECTED) return;
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  while (WiFi.status() != WL_CONNECTED) delay(300);
}

void ensureMqtt() {
  if (mqtt.connected()) return;
  // For testing only; use proper CA validation in production.
  wifiSecure.setInsecure();
  mqtt.setServer(MQTT_HOST, MQTT_PORT);
  mqtt.setCallback(onMqttMessage);

  while (!mqtt.connected()) {
    mqtt.connect(CLIENT_ID, MQTT_USER, MQTT_PASS);
    if (!mqtt.connected()) delay(500);
  }
  // Subscriptions
  mqtt.subscribe(TOPIC_CMD);
  mqtt.subscribe("vpin/#");
}

void publishJson(const char* topic, const String& json) {
  mqtt.publish(topic, json.c_str());
}

void setup() {
  ensureWifi();
  ensureMqtt();
  // Send a hello telemetry
  publishJson(TOPIC_TELE, "{\\"device\\":\\"esp32\\",\\"status\\":\\"online\\"}");
}

void loop() {
  ensureWifi();
  ensureMqtt();
  mqtt.loop();

  // Example telemetry on a virtual pin
  static unsigned long last = 0;
  if (millis() - last > 3000) {
    last = millis();
    publishJson(TOPIC_VPIN1, "{\\"value\\":42}");
  }
}
''';

    final allJson = '''
{
  "host": "${s.host}",
  "port_tls": ${s.portTls},
  "port_wss": ${s.portWss},
  "client_id_app": "${s.clientId}",
  "username": "${s.username}",
  "topics": {
    "esp32_to_app": "esp32server/state",
    "app_to_esp32": "appserver/cmd",
    "vpin": "vpin/<pin>",
    "vpin_set": "vpin/<pin>/set"
  }
}
''';

    return Scaffold(
      appBar: AppBar(title: const Text('Connection Guide')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Broker (EMQX Cloud)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _kv(context, 'Host', s.host),
          _kv(context, 'TLS Port (MQTT)', s.portTls.toString()),
          _kv(context, 'WSS Port (WebSocket)', s.portWss.toString()),
          _kv(context, 'Client ID (App)', s.clientId),
          _kv(context, 'Username', s.username),
          const SizedBox(height: 16),
          const Text('Topics', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _copyTile(context, 'ESP32 → Broker (telemetry)', 'esp32server/state'),
          _copyTile(context, 'App → ESP32 (commands)', 'appserver/cmd'),
          _copyTile(context, 'Virtual Pins (telemetry)', 'vpin/<pin>'),
          _copyTile(context, 'Virtual Pins (set command)', 'vpin/<pin>/set'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _copy(context, 'All (JSON)', allJson),
                  icon: const Icon(Icons.copy_all),
                  label: const Text('Copy All (JSON)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('ESP32 (Arduino) Example',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _codeBox(context, esp32Snippet),
          const SizedBox(height: 16),
          const Text(
            'Use TLS on port 8883 with the same username/password; authorize ESP32 client IDs in EMQX ACL; subscribe the device to appserver/cmd and vpin/# to receive commands.',
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    return Card(
      child: ListTile(
        title: Text(k),
        subtitle: SelectableText(v),
        trailing: IconButton(
          icon: const Icon(Icons.copy),
          onPressed: () => _copy(context, k, v),
        ),
      ),
    );
  }

  Widget _copyTile(BuildContext context, String label, String value) {
    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: SelectableText(value),
        trailing: IconButton(
          icon: const Icon(Icons.copy),
          onPressed: () => _copy(context, label, value),
        ),
      ),
    );
  }

  Widget _codeBox(BuildContext context, String code) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Copy',
              icon: const Icon(Icons.copy),
              onPressed: () => _copy(context, 'ESP32 example', code),
            ),
          ),
          SelectableText(code,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ],
      ),
    );
  }
}
