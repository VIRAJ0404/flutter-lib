// File: lib/features/collections/collection_panel.dart
// Collection Panel (fix: use DeviceRegistry.deviceList as ValueListenable<List<String>>)
// - Resolves: argument_type_not_assignable and instance_access_to_static_member.
// - Provides a simple device selector and a placeholder area to show collection cards.

import 'package:flutter/material.dart';
import '../devices/device_registry.dart';

class CollectionPanel extends StatelessWidget {
  const CollectionPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Device selector bound to ValueListenable<List<String>>
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              const Text('Device:'),
              const SizedBox(width: 8),
              // Listen to DeviceRegistry.deviceList (static ValueListenable<List<String>>)
              ValueListenableBuilder<List<String>>(
                valueListenable: DeviceRegistry.deviceList,
                builder: (_, list, __) {
                  final selected = DeviceRegistry.I.selected.value;
                  return DropdownButton<String>(
                    value: (selected != null && list.contains(selected))
                        ? selected
                        : null,
                    hint: const Text('Select device'),
                    items: list
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (v) => DeviceRegistry.I.setSelected(v),
                  );
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Body placeholder
        Expanded(
          child: Center(
            child: Text(
              'Collections for device: ${DeviceRegistry.I.selected.value ?? 'None'}',
            ),
          ),
        ),
      ],
    );
  }
}
