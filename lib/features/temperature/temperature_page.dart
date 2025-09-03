// File: lib/features/temperature/temperature_page.dart
// Dedicated temperature page (was on Home). Shows chart and table, scoped to selected device.

import 'package:flutter/material.dart';
import '../devices/device_registry.dart';
import '../dashboard/chart_panel.dart';
import '../dashboard/temp_table.dart';

class TemperaturePage extends StatelessWidget {
  const TemperaturePage({super.key});

  @override
  Widget build(BuildContext context) {
    final dev = DeviceRegistry.I.selected.value;
    final topic = (dev == null) ? 'esp32server/temp' : 'esp32server/$dev/temp';
    return Scaffold(
      appBar: AppBar(title: const Text('Temperature')),
      body: Column(
        children: [
          SizedBox(
            height: 280,
            child: Row(
              children: [
                Expanded(
                    child: ChartPanel(
                        title: 'Temperature', topic: topic, maxPoints: 1000)),
              ],
            ),
          ),
          Expanded(child: TempTable(topic: topic, rows: 20)),
        ],
      ),
    );
  }
}
