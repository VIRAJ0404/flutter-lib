// File: lib/features/dashboard/widget_settings_sheet.dart
// vPin Settings Sheet with hard locks and live updates (V0..V100).
// - Disallows selecting a vPin already in use by another widget.
// - Live reacts to VpinRegistry.usedPins; locks/unlocks reflect add/edit/remove immediately.
// - Auto-fills topics when a vPin is chosen: read=vpin/<PIN>, write=vpin/<PIN>/set.
// - Uses DropdownButtonFormField.initialValue (or value fallback for older SDKs).

import 'package:flutter/material.dart';
import 'models.dart';
import '../../services/vpin_registry.dart';

typedef WidgetApplied = void Function(DashWidget updated);

void showWidgetSettingsSheet(
  BuildContext context,
  DashWidget dw, {
  required WidgetApplied onApplied,
}) {
  VpinRegistry.I.start();

  final titleCtrl = TextEditingController(text: dw.title);
  final readCtrl = TextEditingController(text: dw.readTopic ?? '');
  final writeCtrl = TextEditingController(text: dw.writeTopic ?? '');
  final unitCtrl = TextEditingController(text: dw.unit);
  final minCtrl = TextEditingController(text: dw.min?.toString() ?? '');
  final maxCtrl = TextEditingController(text: dw.max?.toString() ?? '');
  final lowCtrl =
      TextEditingController(text: dw.thresholdLow?.toString() ?? '');
  final highCtrl =
      TextEditingController(text: dw.thresholdHigh?.toString() ?? '');
  final imgCtrl = TextEditingController(text: dw.imageUrl ?? '');
  String aggregation = dw.aggregation;

  final registry = VpinRegistry.I;
  String? selectedVpin = dw.vpin;

  void _autofillFromVpin() {
    if (selectedVpin == null || selectedVpin!.isEmpty) return;
    if (readCtrl.text.trim().isEmpty) readCtrl.text = 'vpin/${selectedVpin!}';
    if (writeCtrl.text.trim().isEmpty)
      writeCtrl.text = 'vpin/${selectedVpin!}/set';
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void apply() {
    if (selectedVpin != null &&
        selectedVpin!.isNotEmpty &&
        registry.isUsed(selectedVpin!) &&
        selectedVpin != dw.vpin) {
      _snack('vPin ${selectedVpin!} is in use. Choose a free one or None.');
      return;
    }

    _autofillFromVpin();

    final oldPin = dw.vpin;
    dw.title = titleCtrl.text.trim();
    dw.vpin =
        (selectedVpin == null || selectedVpin!.isEmpty) ? null : selectedVpin;
    dw.readTopic = readCtrl.text.trim().isEmpty ? null : readCtrl.text.trim();
    dw.writeTopic =
        writeCtrl.text.trim().isEmpty ? null : writeCtrl.text.trim();
    dw.unit = unitCtrl.text.trim();
    dw.min = double.tryParse(minCtrl.text.trim());
    dw.max = double.tryParse(maxCtrl.text.trim());
    dw.thresholdLow = double.tryParse(lowCtrl.text.trim());
    dw.thresholdHigh = double.tryParse(highCtrl.text.trim());
    dw.imageUrl = imgCtrl.text.trim().isEmpty ? null : imgCtrl.text.trim();
    dw.aggregation = aggregation;

    // Update locks
    registry.reserve(oldPin: oldPin, newPin: dw.vpin);

    onApplied(dw);
    Navigator.pop(context);
  }

  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => StatefulBuilder(
      builder: (ctx, setModalState) {
        List<String?> _options(Set<String> used) {
          // "None", current (if any), then all registry pins (unique).
          final out = <String?>[null];
          if (selectedVpin != null &&
              selectedVpin!.isNotEmpty &&
              !out.contains(selectedVpin)) {
            out.add(selectedVpin);
          }
          for (final p in registry.allPins) {
            if (!out.contains(p)) out.add(p);
          }
          return out;
        }

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text('Edit Widget', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 12),
              ValueListenableBuilder<Set<String>>(
                valueListenable: registry.usedPins,
                builder: (_, used, __) {
                  final items = _options(used).map((pin) {
                    if (pin == null) {
                      return const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('None'),
                      );
                    }
                    final takenByAnother = used.contains(pin) && pin != dw.vpin;
                    final style = takenByAnother
                        ? const TextStyle(color: Colors.grey)
                        : const TextStyle();
                    return DropdownMenuItem<String?>(
                      value: pin,
                      child: Row(
                        children: [
                          Expanded(child: Text(pin, style: style)),
                          if (takenByAnother)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(Icons.lock,
                                  size: 16, color: Colors.grey),
                            ),
                        ],
                      ),
                    );
                  }).toList();

                  final values = items.map((e) => e.value).toList();
                  final initial =
                      values.contains(selectedVpin) ? selectedVpin : null;

                  // Use initialValue for newer SDKs; keep value for older (backward compatibility).
                  return DropdownButtonFormField<String?>(
                    key: ValueKey('${selectedVpin}_${used.length}'),
                    isExpanded: true,
                    initialValue: initial, // preferred in recent SDKs
                    value: initial, // fallback for older SDKs
                    items: items,
                    onChanged: (v) {
                      if (v != null && registry.isUsed(v) && v != dw.vpin) {
                        _snack('vPin $v is locked by another widget.');
                        return;
                      }
                      setModalState(() {
                        selectedVpin = v;
                        _autofillFromVpin();
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'vPin (V0..V100)',
                      helperText:
                          'Locked pins show a lock icon and cannot be selected',
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: readCtrl,
                decoration: const InputDecoration(
                    labelText: 'Read topic (fallback if no vPin)'),
              ),
              TextField(
                controller: writeCtrl,
                decoration: const InputDecoration(
                    labelText: 'Write topic (fallback if no vPin)'),
              ),
              const SizedBox(height: 8),
              TextField(
                  controller: unitCtrl,
                  decoration: const InputDecoration(labelText: 'Unit')),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: minCtrl,
                    decoration: const InputDecoration(labelText: 'Min'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: maxCtrl,
                    decoration: const InputDecoration(labelText: 'Max'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ]),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: lowCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Threshold Low'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: highCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Threshold High'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ]),
              if (dw.kind == WidgetKind.imageButton)
                TextField(
                    controller: imgCtrl,
                    decoration: const InputDecoration(labelText: 'Image URL')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey(aggregation),
                initialValue: aggregation, // new SDKs
                value: aggregation, // fallback
                items: const [
                  DropdownMenuItem(value: 'raw', child: Text('Raw')),
                  DropdownMenuItem(value: 'avg', child: Text('Average')),
                  DropdownMenuItem(value: 'min', child: Text('Min')),
                  DropdownMenuItem(value: 'max', child: Text('Max')),
                  DropdownMenuItem(value: 'sum', child: Text('Sum')),
                  DropdownMenuItem(value: 'count', child: Text('Count')),
                ],
                onChanged: (v) => aggregation = v ?? 'raw',
                decoration: const InputDecoration(labelText: 'Aggregation'),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    child: FilledButton(
                        onPressed: apply, child: const Text('Apply'))),
              ]),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ),
  );
}
