// File: lib/features/devices/device_filter_bar.dart
// DeviceFilterBar: compact selector and controls for ESP32 device IDs.
// - Shows discovered device chips with selection highlighting.
// - Manual entry field to type/paste a device ID.
// - Actions: Use Selected, Clear, Refresh (ask devices to announce), Copy.
// - Listens to DeviceRegistry for live discovery and selection updates.
//
// Drop this widget at the top of DevicesPage or any screen that needs a quick
// device selector.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/mqtt_service.dart';
import 'device_registry.dart';

class DeviceFilterBar extends StatefulWidget {
  const DeviceFilterBar({super.key});

  @override
  State<DeviceFilterBar> createState() => _DeviceFilterBarState();
}

class _DeviceFilterBarState extends State<DeviceFilterBar> {
  late final TextEditingController _idCtrl =
      TextEditingController(text: DeviceRegistry.I.selected.value ?? '');

  @override
  void initState() {
    super.initState();
    // Keep the field synced with selection changes
    DeviceRegistry.I.selected.addListener(_syncFromRegistry);
    // Ensure discovery is running
    DeviceRegistry.I.configure(prefix: 'esp32server', deviceIndex: 1);
    DeviceRegistry.I.start();
  }

  void _syncFromRegistry() {
    final cur = DeviceRegistry.I.selected.value ?? '';
    if (_idCtrl.text != cur) {
      _idCtrl.text = cur;
      setState(() {});
    }
  }

  @override
  void dispose() {
    DeviceRegistry.I.selected.removeListener(_syncFromRegistry);
    _idCtrl.dispose();
    super.dispose();
  }

  void _applySelection() {
    final id = _idCtrl.text.trim();
    DeviceRegistry.I.setSelected(id.isEmpty ? null : id);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Active device: ${DeviceRegistry.I.selected.value ?? 'None'}')),
    );
  }

  void _clearSelection() {
    _idCtrl.clear();
    DeviceRegistry.I.setSelected(null);
    setState(() {});
  }

  void _copy() {
    final id = _idCtrl.text.trim();
    if (id.isEmpty) return;
    Clipboard.setData(ClipboardData(text: id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Device ID copied')),
    );
  }

  // Optional: publish a broadcast "hello" to prompt devices to send telemetry.
  void _refresh() {
    try {
      // Adjust to firmware contract if different
      MqttService.I.publish('esp32server/all/cmd', '{"cmd":"hello"}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Discovery ping sent')),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _idCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ESP32 Device ID',
                      hintText: 'e.g. dev01',
                    ),
                    onSubmitted: (_) => _applySelection(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _applySelection,
                  icon: const Icon(Icons.check),
                  label: const Text('Use'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Clear',
                  onPressed: _clearSelection,
                  icon: const Icon(Icons.backspace),
                ),
                IconButton(
                  tooltip: 'Copy',
                  onPressed: _copy,
                  icon: const Icon(Icons.copy),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: ValueListenableBuilder<Set<String>>(
                valueListenable: DeviceRegistry.I.known,
                builder: (_, devices, __) {
                  if (devices.isEmpty) {
                    return Text(
                      'No devices discovered yet. Devices appear when they publish under esp32server/{deviceId}/...',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    );
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: devices.map((d) {
                        final sel = DeviceRegistry.I.selected.value == d;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InputChip(
                            selected: sel,
                            label: Text(d),
                            onPressed: () {
                              _idCtrl.text = d;
                              _applySelection();
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
