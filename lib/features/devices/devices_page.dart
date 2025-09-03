// File: lib/features/devices/devices_page.dart
// DevicesPage: overview and controls for discovered ESP32 devices.
// Changes in this step:
// - Added generics to ValueListenableBuilder<Set<String>> for type-safety.
// - Explicit typing for selected value and sorted device list.
// - Kept actions (Select/Subscribe/Unsubscribe/Ping) unchanged.

import 'package:flutter/material.dart';

import '../../services/mqtt_service.dart';
import 'device_registry.dart';
import 'device_filter_bar.dart';

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  void _select(String id) {
    DeviceRegistry.I.setSelected(id);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Selected device: $id')));
    setState(() {});
  }

  void _subscribe(String id) {
    final String t = 'esp32server/$id/#';
    MqttService.I.subscribe(t);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Subscribed $t')));
  }

  void _unsubscribe(String id) {
    final String t = 'esp32server/$id/#';
    MqttService.I.unsubscribe(t);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Unsubscribed $t')));
  }

  void _ping(String id) {
    // Adjust to firmware message contract if different
    MqttService.I.publish('esp32server/$id/cmd', '{"cmd":"status"}');
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Ping sent to $id')));
  }

  @override
  Widget build(BuildContext context) {
    final mqtt = MqttService.I;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        actions: [
          IconButton(
            tooltip: 'Connect',
            onPressed: () => mqtt.connect(),
            icon: const Icon(Icons.link),
          ),
          IconButton(
            tooltip: 'Disconnect',
            onPressed: () => mqtt.disconnect(),
            icon: const Icon(Icons.link_off),
          ),
        ],
      ),
      body: Column(
        children: [
          const DeviceFilterBar(),
          const SizedBox(height: 4),
          Expanded(
            child: ValueListenableBuilder<Set<String>>(
              valueListenable: DeviceRegistry.I.known,
              builder: (_, Set<String> devices, __) {
                if (devices.isEmpty) {
                  return const Center(
                      child: Text('No devices discovered yet.'));
                }

                final String? selected = DeviceRegistry.I.selected.value;
                final List<String> list = devices.toList()..sort();

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, int i) {
                    final String id = list[i];
                    final bool isActive = id == selected;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(id.isNotEmpty
                              ? id.characters.first.toUpperCase()
                              : '?'),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                id,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (isActive)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Chip(
                                  label: const Text('Active'),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text('Topic: esp32server/$id/#'),
                        trailing: Wrap(
                          spacing: 6,
                          children: [
                            IconButton(
                              tooltip: 'Select',
                              onPressed: () => _select(id),
                              icon: const Icon(Icons.check_circle_outline),
                            ),
                            IconButton(
                              tooltip: 'Subscribe',
                              onPressed: () => _subscribe(id),
                              icon: const Icon(Icons.subscriptions),
                            ),
                            IconButton(
                              tooltip: 'Unsubscribe',
                              onPressed: () => _unsubscribe(id),
                              icon: const Icon(Icons.unsubscribe),
                            ),
                            IconButton(
                              tooltip: 'Ping',
                              onPressed: () => _ping(id),
                              icon: const Icon(Icons.waves),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
