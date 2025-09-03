// File: lib/features/dashboard/widgets_gallery.dart
// FIX: Only show the edit button when 'onEdit' is provided (Edit mode).
// KPI and other headers call _titleRow with an optional onEdit callback.
// Flat visual style (no shadows) kept; withOpacity -> withValues migrated.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/mqtt_service.dart';
import '../../services/vpin_service.dart';
import '../data/topic_store.dart';
import 'models.dart';
import 'widget_settings_sheet.dart';

class FlatBox extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const FlatBox(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(12)});
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surface;
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Colors.black.withValues(alpha: 0.08), width: 1),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

IconData kindIcon(WidgetKind kind) {
  switch (kind) {
    case WidgetKind.button:
      return Icons.touch_app;
    case WidgetKind.styledButton:
      return Icons.lightbulb_outline;
    case WidgetKind.imageButton:
      return Icons.image;
    case WidgetKind.toggle:
      return Icons.toggle_on;
    case WidgetKind.slider:
      return Icons.linear_scale;
    case WidgetKind.verticalSlider:
      return Icons.straighten;
    case WidgetKind.stepSlider:
      return Icons.view_stream;
    case WidgetKind.verticalStepSlider:
      return Icons.stacked_line_chart;
    case WidgetKind.numberInput:
      return Icons.pin;
    case WidgetKind.kpi:
      return Icons.speed;
    case WidgetKind.valueDisplay:
      return Icons.confirmation_num;
    case WidgetKind.labeledDisplay:
      return Icons.text_snippet;
    case WidgetKind.radialGauge:
      return Icons.donut_large;
    case WidgetKind.segmented:
      return Icons.segment;
    case WidgetKind.joystick:
      return Icons.gamepad;
    case WidgetKind.rgb:
      return Icons.palette;
    case WidgetKind.terminal:
      return Icons.terminal;
    case WidgetKind.spacer:
      return Icons.crop_square;
    default:
      return Icons.extension;
  }
}

double? _resolveValue(DashWidget dw) {
  if (dw.vpin != null && dw.vpin!.isNotEmpty) {
    return VPinService.I.latestDouble(dw.vpin!);
  }
  if (dw.readTopic != null && dw.readTopic!.isNotEmpty) {
    return TopicStore.I.latest(dw.readTopic!)?.value;
  }
  return null;
}

String _fmt(double? v, String unit) =>
    v == null ? '-- $unit' : '${v.toStringAsFixed(1)} $unit';

Row _titleRow(DashWidget dw, BuildContext context, {VoidCallback? onEdit}) =>
    Row(
      children: [
        Icon(kindIcon(dw.kind), size: 20),
        const SizedBox(width: 8),
        Expanded(
            child: Text(dw.title,
                style: const TextStyle(fontWeight: FontWeight.bold))),
        if (onEdit != null)
          IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Edit',
              icon: const Icon(Icons.tune),
              onPressed: onEdit),
      ],
    );

// Build a widget card; 'editable' controls whether header edit button appears.
// EditorCanvas also overlays its own menu; Home will pass editable=false so no edit affordance is shown.
Widget buildWidgetCard(
  BuildContext context,
  DashWidget dw,
  MqttService mqtt, {
  bool editable = false,
  VoidCallback? onEdit,
  VoidCallback? onDuplicate,
  VoidCallback? onRemove,
}) {
  Widget content;

  switch (dw.kind) {
    case WidgetKind.button:
      content = Center(
        child: FilledButton(
          onPressed: () {
            if (dw.vpin != null && dw.vpin!.isNotEmpty) {
              VPinService.I.write(dw.vpin!, 1);
            } else {
              mqtt.publish(dw.writeTopic ?? 'app/cmd', '{"btn":"${dw.id}"}');
            }
          },
          child: Text(dw.title),
        ),
      );
      break;

    case WidgetKind.styledButton:
      content = Center(
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              side: BorderSide(color: dw.color, width: 1.5),
              foregroundColor: dw.color),
          icon: const Icon(Icons.bolt),
          label: Text(dw.title),
          onPressed: () {
            if (dw.vpin != null && dw.vpin!.isNotEmpty) {
              VPinService.I.write(dw.vpin!, 1);
            } else {
              mqtt.publish(dw.writeTopic ?? 'app/cmd', '{"styled":"${dw.id}"}');
            }
          },
        ),
      );
      break;

    case WidgetKind.imageButton:
      content = Stack(
        fit: StackFit.expand,
        children: [
          if (dw.imageUrl != null && dw.imageUrl!.isNotEmpty)
            Image.network(dw.imageUrl!, fit: BoxFit.cover)
          else
            Container(color: Theme.of(context).colorScheme.surfaceVariant),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (dw.vpin != null && dw.vpin!.isNotEmpty) {
                  VPinService.I.write(dw.vpin!, 1);
                } else {
                  mqtt.publish(
                      dw.writeTopic ?? 'app/cmd', '{"imgbtn":"${dw.id}"}');
                }
              },
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: Colors.black.withValues(alpha: 0.3),
              padding: const EdgeInsets.all(6),
              child: Text(dw.title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
      break;

    case WidgetKind.toggle:
      content = _ToggleCard(dw: dw, mqtt: mqtt);
      break;

    case WidgetKind.slider:
      content = _SliderCard(dw: dw, mqtt: mqtt, vertical: false, steps: 0);
      break;

    case WidgetKind.verticalSlider:
      content = _SliderCard(dw: dw, mqtt: mqtt, vertical: true, steps: 0);
      break;

    case WidgetKind.stepSlider:
      content = _SliderCard(dw: dw, mqtt: mqtt, vertical: false, steps: 10);
      break;

    case WidgetKind.verticalStepSlider:
      content = _SliderCard(dw: dw, mqtt: mqtt, vertical: true, steps: 10);
      break;

    case WidgetKind.numberInput:
      content = _NumberInputCard(dw: dw, mqtt: mqtt);
      break;

    case WidgetKind.kpi:
      {
        final v = _resolveValue(dw);
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titleRow(dw, context, onEdit: editable ? onEdit : null),
            const Spacer(),
            Text(_fmt(v, dw.unit),
                style: Theme.of(context).textTheme.headlineMedium),
          ],
        );
        break;
      }

    case WidgetKind.valueDisplay:
      {
        final v = _resolveValue(dw);
        content = Center(
            child: Text(v?.toStringAsFixed(2) ?? '--',
                style: Theme.of(context).textTheme.headlineLarge));
        break;
      }

    case WidgetKind.labeledDisplay:
      {
        final v = _resolveValue(dw);
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titleRow(dw, context, onEdit: editable ? onEdit : null),
            const SizedBox(height: 8),
            Text(v?.toStringAsFixed(2) ?? '--'),
            if (dw.unit.isNotEmpty) Text(dw.unit),
          ],
        );
        break;
      }

    case WidgetKind.segmented:
      content = _SegmentedCard(dw: dw, mqtt: mqtt);
      break;

    case WidgetKind.joystick:
      content = Center(
        child: _JoystickLite(
          onChanged: (x, y) {
            final data = {'x': x, 'y': y};
            if (dw.vpin != null && dw.vpin!.isNotEmpty) {
              VPinService.I.write(dw.vpin!, data);
            } else {
              mqtt.publish(dw.writeTopic ?? 'app/cmd',
                  '{"joystick":"${dw.id}","x":$x,"y":$y}');
            }
          },
        ),
      );
      break;

    case WidgetKind.rgb:
      content = _RgbCard(dw: dw, mqtt: mqtt);
      break;

    case WidgetKind.terminal:
      content = Padding(
        padding: const EdgeInsets.all(8),
        child: ValueListenableBuilder<List<String>>(
          valueListenable: MqttService.I.messages,
          builder: (_, items, __) => ListView.builder(
            itemCount: items.length.clamp(0, 50),
            itemBuilder: (_, i) => Text(items[i],
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
        ),
      );
      break;

    case WidgetKind.spacer:
      content = const SizedBox.expand();
      break;

    case WidgetKind.radialGauge:
      {
        final v = _resolveValue(dw) ?? 0;
        final min = dw.min ?? 0;
        final max = dw.max ?? 100;
        content = _RadialGaugeLite(
            value: v.clamp(min, max).toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            unit: dw.unit);
        break;
      }

    case WidgetKind.gauge:
    case WidgetKind.lineChart:
    case WidgetKind.barChart:
    case WidgetKind.led:
    case WidgetKind.text:
      content = _basicFallback(context, dw, mqtt);
      break;
  }

  return FlatBox(child: content);
}

Widget _basicFallback(BuildContext context, DashWidget dw, MqttService mqtt) {
  switch (dw.kind) {
    case WidgetKind.text:
      return Padding(padding: const EdgeInsets.all(12), child: Text(dw.title));
    case WidgetKind.led:
      return Center(child: Icon(Icons.circle, color: dw.color, size: 18));
    case WidgetKind.gauge:
      return Center(
          child: Text('Gauge\n${dw.title}', textAlign: TextAlign.center));
    case WidgetKind.lineChart:
      return Center(
          child: Text('Line Chart\n${dw.title}', textAlign: TextAlign.center));
    case WidgetKind.barChart:
      return Center(
          child: Text('Bar Chart\n${dw.title}', textAlign: TextAlign.center));
    default:
      return const SizedBox.shrink();
  }
}

class _ToggleCard extends StatefulWidget {
  final DashWidget dw;
  final MqttService mqtt;
  const _ToggleCard({required this.dw, required this.mqtt});
  @override
  State<_ToggleCard> createState() => _ToggleCardState();
}

class _ToggleCardState extends State<_ToggleCard> {
  bool on = false;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SwitchListTile(
        title: Text(widget.dw.title),
        value: on,
        onChanged: (v) {
          setState(() => on = v);
          if (widget.dw.vpin != null && widget.dw.vpin!.isNotEmpty) {
            VPinService.I.write(widget.dw.vpin!, v ? 1 : 0);
          } else {
            widget.mqtt.publish(widget.dw.writeTopic ?? 'app/cmd',
                '{"toggle":"${widget.dw.id}","on":$v}');
          }
        },
      ),
    );
  }
}

class _SliderCard extends StatefulWidget {
  final DashWidget dw;
  final MqttService mqtt;
  final bool vertical;
  final int steps;
  const _SliderCard(
      {required this.dw,
      required this.mqtt,
      required this.vertical,
      required this.steps});
  @override
  State<_SliderCard> createState() => _SliderCardState();
}

class _SliderCardState extends State<_SliderCard> {
  double value = 50;
  @override
  Widget build(BuildContext context) {
    final min = widget.dw.min ?? 0;
    final max = widget.dw.max ?? 100;
    final divisions = widget.steps > 0 ? widget.steps : null;
    final slider = Slider(
      value: value.clamp(min, max),
      min: min,
      max: max,
      divisions: divisions,
      onChanged: (v) => setState(() => value = v),
      onChangeEnd: (v) {
        if (widget.dw.vpin != null && widget.dw.vpin!.isNotEmpty) {
          VPinService.I.write(widget.dw.vpin!, v);
        } else {
          widget.mqtt.publish(widget.dw.writeTopic ?? 'app/cmd',
              '{"slider":"${widget.dw.id}","value":$v}');
        }
      },
    );
    return widget.vertical
        ? Row(children: [
            Row(children: [
              Icon(kindIcon(widget.dw.kind), size: 18),
              const SizedBox(width: 6),
              Text(widget.dw.title,
                  style: const TextStyle(fontWeight: FontWeight.bold))
            ]),
            const SizedBox(width: 12),
            Expanded(child: RotatedBox(quarterTurns: 3, child: slider)),
            const SizedBox(width: 8),
            Text(value.toStringAsFixed(0)),
          ])
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Row(children: [
                Icon(kindIcon(widget.dw.kind), size: 18),
                const SizedBox(width: 6)
              ]),
              Expanded(
                  child: Text(widget.dw.title,
                      style: const TextStyle(fontWeight: FontWeight.bold))),
              Text(value.toStringAsFixed(0)),
            ]),
            slider,
          ]);
  }
}

class _NumberInputCard extends StatefulWidget {
  final DashWidget dw;
  final MqttService mqtt;
  const _NumberInputCard({required this.dw, required this.mqtt});
  @override
  State<_NumberInputCard> createState() => _NumberInputCardState();
}

class _NumberInputCardState extends State<_NumberInputCard> {
  late final TextEditingController ctrl;
  @override
  void initState() {
    super.initState();
    ctrl = TextEditingController();
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Icon(Icons.numbers, size: 18),
      const SizedBox(width: 6),
      Expanded(
        child: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
              labelText: widget.dw.title, suffixText: widget.dw.unit),
          onSubmitted: (t) {
            final v = double.tryParse(t);
            if (v == null) return;
            if (widget.dw.vpin != null && widget.dw.vpin!.isNotEmpty) {
              VPinService.I.write(widget.dw.vpin!, v);
            } else {
              widget.mqtt.publish(widget.dw.writeTopic ?? 'app/cmd',
                  '{"number":"${widget.dw.id}","value":$v}');
            }
          },
        ),
      ),
    ]);
  }
}

class _SegmentedCard extends StatefulWidget {
  final DashWidget dw;
  final MqttService mqtt;
  const _SegmentedCard({required this.dw, required this.mqtt});
  @override
  State<_SegmentedCard> createState() => _SegmentedCardState();
}

class _SegmentedCardState extends State<_SegmentedCard> {
  Set<int> selected = {0};
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, label: Text('A')),
          ButtonSegment(value: 1, label: Text('B')),
          ButtonSegment(value: 2, label: Text('C')),
        ],
        selected: selected,
        onSelectionChanged: (s) {
          setState(() => selected = s);
          final val = s.first;
          if (widget.dw.vpin != null && widget.dw.vpin!.isNotEmpty) {
            VPinService.I.write(widget.dw.vpin!, val);
          } else {
            widget.mqtt.publish(widget.dw.writeTopic ?? 'app/cmd',
                '{"seg":"${widget.dw.id}","value":$val}');
          }
        },
      ),
    );
  }
}

class _RgbCard extends StatefulWidget {
  final DashWidget dw;
  final MqttService mqtt;
  const _RgbCard({required this.dw, required this.mqtt});
  @override
  State<_RgbCard> createState() => _RgbCardState();
}

class _RgbCardState extends State<_RgbCard> {
  double r = 0, g = 0, b = 0;
  void _send() {
    final data = {'r': r.round(), 'g': g.round(), 'b': b.round()};
    if (widget.dw.vpin != null && widget.dw.vpin!.isNotEmpty) {
      VPinService.I.write(widget.dw.vpin!, data);
    } else {
      widget.mqtt.publish(widget.dw.writeTopic ?? 'app/cmd',
          '{"rgb":"${widget.dw.id}","r":${data['r']},"g":${data['g']},"b":${data['b']}}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        const Icon(Icons.palette, size: 18),
        const SizedBox(width: 6),
        Text(widget.dw.title,
            style: const TextStyle(fontWeight: FontWeight.bold))
      ]),
      Row(children: [
        const Text('R'),
        Expanded(
            child: Slider(
          value: r,
          min: 0,
          max: 255,
          onChanged: (v) {
            setState(() => r = v);
          },
          onChangeEnd: (_) => _send(),
        ))
      ]),
      Row(children: [
        const Text('G'),
        Expanded(
            child: Slider(
          value: g,
          min: 0,
          max: 255,
          onChanged: (v) {
            setState(() => g = v);
          },
          onChangeEnd: (_) => _send(),
        ))
      ]),
      Row(children: [
        const Text('B'),
        Expanded(
            child: Slider(
          value: b,
          min: 0,
          max: 255,
          onChanged: (v) {
            setState(() => b = v);
          },
          onChangeEnd: (_) => _send(),
        ))
      ]),
    ]);
  }
}

class _JoystickLite extends StatefulWidget {
  final void Function(double x, double y) onChanged;
  const _JoystickLite({required this.onChanged});
  @override
  State<_JoystickLite> createState() => _JoystickLiteState();
}

class _JoystickLiteState extends State<_JoystickLite> {
  final double size = 140;
  Offset offset = Offset.zero;
  void _update(Offset local) {
    final r = size / 2;
    final center = Offset(r, r);
    Offset d = local - center;
    if (d.distance > r) d = Offset.fromDirection(d.direction, r);
    setState(() => offset = d);
    final x = (d.dx / r).clamp(-1.0, 1.0);
    final y = (d.dy / r).clamp(-1.0, 1.0);
    widget.onChanged(
        double.parse(x.toStringAsFixed(2)), double.parse(y.toStringAsFixed(2)));
  }

  void _end() {
    setState(() => offset = Offset.zero);
    widget.onChanged(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: GestureDetector(
        onPanStart: (d) => _update(d.localPosition),
        onPanUpdate: (d) => _update(d.localPosition),
        onPanEnd: (_) => _end(),
        onPanCancel: _end,
        child: CustomPaint(
            painter: _JoystickLitePainter(
                offset: offset,
                radius: size / 2,
                color: Theme.of(context).colorScheme.primary)),
      ),
    );
  }
}

class _JoystickLitePainter extends CustomPainter {
  final Offset offset;
  final double radius;
  final Color color;
  _JoystickLitePainter(
      {required this.offset, required this.radius, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(radius, radius);
    final bg = Paint()..color = Colors.grey.shade300;
    canvas.drawCircle(center, radius, bg);
    final grid = Paint()
      ..color = Colors.grey.shade500
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius * 0.66, grid);
    canvas.drawCircle(center, radius * 0.33, grid);
    canvas.drawLine(Offset(center.dx - radius, center.dy),
        Offset(center.dx + radius, center.dy), grid);
    canvas.drawLine(Offset(center.dx, center.dy - radius),
        Offset(center.dx, center.dy + radius), grid);
    final thumb = Paint()..color = color;
    canvas.drawCircle(center + offset, radius * 0.18, thumb);
  }

  @override
  bool shouldRepaint(covariant _JoystickLitePainter old) =>
      old.offset != offset || old.color != color || old.radius != radius;
}

class _RadialGaugeLite extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final String unit;
  const _RadialGaugeLite(
      {required this.value,
      required this.min,
      required this.max,
      required this.unit});
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.6,
      child: CustomPaint(
        painter: _GaugePainter(
            value: value,
            min: min,
            max: max,
            unit: unit,
            textStyle:
                Theme.of(context).textTheme.bodyMedium ?? const TextStyle()),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final double min;
  final double max;
  final String unit;
  final TextStyle textStyle;
  _GaugePainter(
      {required this.value,
      required this.min,
      required this.max,
      required this.unit,
      required this.textStyle});
  static const double pi = 3.1415926535897932;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.9);
    final radius = size.height * 0.8;
    final arcRect = Rect.fromCircle(center: center, radius: radius);
    final base = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawArc(arcRect, pi, pi, false, base);
    final t = ((value - min) / (max - min)).clamp(0, 1);
    final angle = pi + t * pi;
    final len = radius - 12;
    final end = Offset(
        center.dx + len * math.cos(angle), center.dy + len * math.sin(angle));
    final needle = Paint()
      ..color = Colors.black87
      ..strokeWidth = 3;
    canvas.drawLine(center, end, needle);
    canvas.drawCircle(center, 5, Paint()..color = Colors.black87);
    final tp = TextPainter(
        text: TextSpan(
            text: '${value.toStringAsFixed(1)} $unit',
            style: textStyle.copyWith(fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(
        canvas, Offset(center.dx - tp.width / 2, center.dy - radius * 0.55));
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.value != value ||
      old.min != min ||
      old.max != max ||
      old.unit != unit ||
      old.textStyle != textStyle;
}
