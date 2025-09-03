// File: lib/features/alerts/alerts_panel.dart
// Changes:
// - Added generics to ValueListenableBuilder<int> for type-safety.
// - Replaced items.length.clamp(0, 5) with math.min(items.length, 5) to ensure int itemCount.
// - Minor cleanups and explicit types.

import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'alert_service.dart';

class AlertsPanel extends StatelessWidget {
  const AlertsPanel({super.key});

  Color _color(AlertLevel lvl, ColorScheme cs) {
    switch (lvl) {
      case AlertLevel.info:
        return cs.primary;
      case AlertLevel.warn:
        return cs.tertiary;
      case AlertLevel.alarm:
        return cs.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = AlertService.I;
    return ValueListenableBuilder<int>(
      valueListenable: svc.tick,
      builder: (_, __, ___) {
        final List<AlertEvent> items = svc.recent.reversed.toList();
        final cs = Theme.of(context).colorScheme;
        return Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: math.min(items.length, 5),
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final e = items[i];
              return Row(
                children: [
                  Icon(Icons.report, color: _color(e.level, cs)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${e.topic} ${e.value ?? '-'} ${e.message}'),
                  ),
                  Text(TimeOfDay.fromDateTime(e.ts).format(context)),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
