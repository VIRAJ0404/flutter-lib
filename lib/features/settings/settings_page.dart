// File: lib/features/settings/settings_page.dart
// Settings screen: MQTT + Theme + ESP32 Device ID (discovery-aware).
// Preserves previous functionality and adds:
// - "ESP32 Device ID" section: shows discovered IDs, allows manual entry, and "Use Selected".
// - Live badge indicating whether the entered ID is discovered right now.
// - When "Use Selected" is pressed, DeviceRegistry updates the active deviceId.
//
// Requires:
//   import '../devices/device_registry.dart';
// Ensure DeviceRegistry is wired to TopicStore ingest once at app init:
//   TopicStore.I.onIngest = (t, p) { DeviceRegistry.I.addTopic(t); /* existing hooks... */ };

import 'package:flutter/material.dart';
import '../../services/mqtt_service.dart';
import '../../services/theme_service.dart';
import '../devices/device_registry.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // MQTT
  late final TextEditingController hostCtrl =
      TextEditingController(text: MqttService.I.host);
  late final TextEditingController portTlsCtrl =
      TextEditingController(text: MqttService.I.portTls.toString());
  late final TextEditingController portWssCtrl =
      TextEditingController(text: MqttService.I.portWss.toString());
  late final TextEditingController userCtrl =
      TextEditingController(text: MqttService.I.username);
  late final TextEditingController passCtrl =
      TextEditingController(text: MqttService.I.password);
  late final TextEditingController clientCtrl =
      TextEditingController(text: MqttService.I.clientId);

  // Theme
  late ThemeMode _mode = ThemeController.I.mode.value;

  // Device ID (ESP32)
  late final TextEditingController deviceIdCtrl =
      TextEditingController(text: DeviceRegistry.I.selected.value ?? '');

  @override
  void initState() {
    super.initState();
    // Ensure discovery is running
    DeviceRegistry.I.configure(prefix: 'esp32server', deviceIndex: 1);
    DeviceRegistry.I.start();

    // Keep the text field in sync if selection changes elsewhere
    DeviceRegistry.I.selected.addListener(_syncSelected);
  }

  void _syncSelected() {
    final cur = DeviceRegistry.I.selected.value ?? '';
    if (deviceIdCtrl.text != cur) {
      deviceIdCtrl.text = cur;
      setState(() {});
    }
  }

  @override
  void dispose() {
    hostCtrl.dispose();
    portTlsCtrl.dispose();
    portWssCtrl.dispose();
    userCtrl.dispose();
    passCtrl.dispose();
    clientCtrl.dispose();
    deviceIdCtrl.dispose();
    DeviceRegistry.I.selected.removeListener(_syncSelected);
    super.dispose();
  }

  Future<void> _saveMqtt() async {
    final s = MqttService.I;
    s.host = hostCtrl.text.trim();
    s.portTls = int.tryParse(portTlsCtrl.text.trim()) ?? 8883;
    s.portWss = int.tryParse(portWssCtrl.text.trim()) ?? 8084;
    s.username = userCtrl.text.trim();
    s.password = passCtrl.text;
    s.clientId =
        clientCtrl.text.trim().isEmpty ? s.clientId : clientCtrl.text.trim();
    await s.saveCurrent();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Saved MQTT settings')));
  }

  Future<void> _applyTheme() async {
    await ThemeController.I.set(_mode);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Theme updated')));
  }

  void _useSelectedDevice() {
    final id = deviceIdCtrl.text.trim();
    DeviceRegistry.I.setSelected(id.isEmpty ? null : id);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Active device: ${DeviceRegistry.I.selected.value ?? 'None'}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mqtt = MqttService.I;
    final pad = MediaQuery.of(context).size.width < 360 ? 12.0 : 16.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: EdgeInsets.all(pad),
        children: [
          // Appearance
          const Text('Appearance',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
                onPressed: _applyTheme, child: const Text('Apply Theme')),
          ),
          const SizedBox(height: 24),
          const Divider(),

          // MQTT
          const Text('Broker & Transport',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: hostCtrl,
            decoration: const InputDecoration(labelText: 'Host / Address'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: portTlsCtrl,
                  decoration:
                      const InputDecoration(labelText: 'TLS Port (8883)'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: portWssCtrl,
                  decoration:
                      const InputDecoration(labelText: 'WSS Port (8084)'),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: userCtrl,
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: passCtrl,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: clientCtrl,
            decoration: const InputDecoration(labelText: 'Client ID (App)'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                    onPressed: _saveMqtt, child: const Text('Save')),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                  onPressed: () => mqtt.connect(),
                  child: const Text('Connect')),
              const SizedBox(width: 8),
              FilledButton.tonal(
                  onPressed: () => mqtt.disconnect(),
                  child: const Text('Disconnect')),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),

          // ESP32 Device ID
          const Text('ESP32 Device ID',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ValueListenableBuilder<Set<String>>(
            valueListenable: DeviceRegistry.I.known,
            builder: (_, devices, __) {
              final entered = deviceIdCtrl.text.trim();
              final isKnown = entered.isNotEmpty && devices.contains(entered);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: deviceIdCtrl,
                    decoration: InputDecoration(
                      labelText:
                          'Device ID (from topic: esp32server/{deviceId}/...)',
                      suffixIcon: (entered.isEmpty)
                          ? const Icon(Icons.info_outline)
                          : Icon(
                              isKnown ? Icons.verified : Icons.error_outline,
                              color: isKnown
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.error,
                            ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  if (devices.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: devices
                          .map(
                            (d) => InputChip(
                              selected: DeviceRegistry.I.selected.value == d,
                              label: Text(d),
                              onPressed: () {
                                deviceIdCtrl.text = d;
                                _useSelectedDevice();
                              },
                            ),
                          )
                          .toList(),
                    )
                  else
                    const Text(
                      'No devices discovered yet. Ensure your ESP32 publishes any topic under esp32server/{deviceId}/...',
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _useSelectedDevice,
                          icon: const Icon(Icons.check),
                          label: const Text('Use Selected'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
