// File: lib/features/quick_actions/quick_actions_bar.dart
// Quick connect/disconnect and broadcast actions.

import 'package:flutter/material.dart';
import '../../services/mqtt_service.dart';

class QuickActionsBar extends StatelessWidget {
  const QuickActionsBar({super.key});

  @override
  Widget build(BuildContext context) {
    final mqtt = MqttService.I;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          _ActionChip(
              label: 'Connect', icon: Icons.link, onTap: () => mqtt.connect()),
          _ActionChip(
              label: 'Disconnect',
              icon: Icons.link_off,
              onTap: () => mqtt.disconnect()),
          _ActionChip(
              label: 'All On',
              icon: Icons.power,
              onTap: () => mqtt.publish('appserver/all/cmd', '{"all":"on"}')),
          _ActionChip(
              label: 'All Off',
              icon: Icons.power_off,
              onTap: () => mqtt.publish('appserver/all/cmd', '{"all":"off"}')),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionChip(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
          avatar: Icon(icon, size: 18), label: Text(label), onPressed: onTap),
    );
  }
}
