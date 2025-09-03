// File: lib/features/dashboard/widget_gallery_panel.dart
// Simple add-widget bottom sheet listing widget kinds to insert.

import 'package:flutter/material.dart';
import 'models.dart';

typedef AddWidgetFn = void Function(DashWidget w);

Future<void> showWidgetGallery(BuildContext context, AddWidgetFn onAdd) async {
  final entries = <Map<String, dynamic>>[
    {'label': 'KPI', 'kind': WidgetKind.kpi},
    {'label': 'Styled Button', 'kind': WidgetKind.styledButton},
    {'label': 'Image Button', 'kind': WidgetKind.imageButton},
    {'label': 'Toggle', 'kind': WidgetKind.toggle},
    {'label': 'Slider', 'kind': WidgetKind.slider},
    {'label': 'Vertical Slider', 'kind': WidgetKind.verticalSlider},
    {'label': 'Step Slider', 'kind': WidgetKind.stepSlider},
    {'label': 'Vertical Step Slider', 'kind': WidgetKind.verticalStepSlider},
    {'label': 'Number Input', 'kind': WidgetKind.numberInput},
    {'label': 'Segmented', 'kind': WidgetKind.segmented},
    {'label': 'Radial Gauge', 'kind': WidgetKind.radialGauge},
    {'label': 'Joystick', 'kind': WidgetKind.joystick},
    {'label': 'RGB Control', 'kind': WidgetKind.rgb},
    {'label': 'Value Display', 'kind': WidgetKind.valueDisplay},
    {'label': 'Labeled Display', 'kind': WidgetKind.labeledDisplay},
    {'label': 'Terminal', 'kind': WidgetKind.terminal},
    {'label': 'Spacer', 'kind': WidgetKind.spacer},
    // legacy placeholders
    {'label': 'Text', 'kind': WidgetKind.text},
    {'label': 'LED', 'kind': WidgetKind.led},
  ];

  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final e = entries[i];
        return ListTile(
          leading: const Icon(Icons.add_circle_outline),
          title: Text(e['label'] as String),
          onTap: () {
            final kind = e['kind'] as WidgetKind;
            final w = DashWidget(
              id: '${kind.name}_${DateTime.now().millisecondsSinceEpoch}',
              kind: kind,
              title: e['label'] as String,
              position: const Offset(24, 24),
              size: const Size(160, 100),
              readTopic:
                  (kind == WidgetKind.kpi || kind == WidgetKind.radialGauge)
                      ? 'esp32server/{device}/temp'
                      : null,
              unit: (kind == WidgetKind.kpi || kind == WidgetKind.radialGauge)
                  ? '°C'
                  : '',
              min: (kind == WidgetKind.slider ||
                      kind == WidgetKind.verticalSlider ||
                      kind == WidgetKind.stepSlider ||
                      kind == WidgetKind.verticalStepSlider)
                  ? 0
                  : null,
              max: (kind == WidgetKind.slider ||
                      kind == WidgetKind.verticalSlider ||
                      kind == WidgetKind.stepSlider ||
                      kind == WidgetKind.verticalStepSlider)
                  ? 100
                  : null,
            );
            Navigator.pop(context);
            onAdd(w);
          },
        );
      },
    ),
  );
}
