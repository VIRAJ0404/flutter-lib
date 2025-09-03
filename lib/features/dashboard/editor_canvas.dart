// File: lib/features/dashboard/editor_canvas.dart
// Editor Canvas with live vPin locks and robust grid painter.
// - Duplicate: clears vPin and clears vpin-based topics (prevents implicit locks).
// - Remove: unlocks that widget's vPin immediately.
// - Grid painter uses withOpacity for broad SDK compatibility.
// - Bottom sheet opens after popup via addPostFrameCallback for reliability.

import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'models.dart';
import 'widget_settings_sheet.dart';
import '../../services/mqtt_service.dart';
import '../../services/vpin_registry.dart';
import 'widgets_gallery.dart';

typedef WidgetBuilderFn = Widget Function(BuildContext, DashWidget);

class EditorCanvas extends StatefulWidget {
  final Size size;
  final List<DashWidget> items;
  final ValueChanged<List<DashWidget>> onChanged;
  final WidgetBuilderFn widgetBuilder; // kept for compatibility
  final double grid;
  final bool editable;

  const EditorCanvas({
    super.key,
    required this.size,
    required this.items,
    required this.onChanged,
    required this.widgetBuilder,
    this.grid = 8,
    this.editable = true,
  });

  @override
  State<EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends State<EditorCanvas> {
  String? selectedId;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CustomPaint(
            size: widget.size,
            painter: _GridPainter(widget.grid, widget.editable)),
        ...widget.items.map((dw) => _ItemHost(
              key: ValueKey(dw.id),
              canvasSize: widget.size,
              data: dw,
              grid: widget.grid,
              editable: widget.editable,
              selected: selectedId == dw.id,
              onSelect: () => setState(() => selectedId = dw.id),
              onChanged: (d) {
                final idx = widget.items.indexWhere((x) => x.id == d.id);
                if (idx != -1) {
                  widget.items[idx] = d;
                  widget.onChanged(List<DashWidget>.from(widget.items));
                }
              },
              onDuplicate: () {
                final src = dw;
                final copyPos = src.position + const Offset(24, 24);

                // Clear vPin on duplicate; also clear topics if they point to that vPin
                String? newRead = src.readTopic;
                String? newWrite = src.writeTopic;
                if (src.vpin != null && src.vpin!.isNotEmpty) {
                  final rp = 'vpin/${src.vpin}';
                  final wp = 'vpin/${src.vpin}/set';
                  if (newRead == rp) newRead = null;
                  if (newWrite == wp) newWrite = null;
                }

                final newW = DashWidget(
                  id: '${src.id}_${DateTime.now().millisecondsSinceEpoch}',
                  kind: src.kind,
                  title: '${src.title} Copy',
                  position: copyPos,
                  size: src.size,
                  readTopic: newRead,
                  writeTopic: newWrite,
                  vpin: null, // never clone vPin
                  unit: src.unit,
                  min: src.min,
                  max: src.max,
                  thresholdLow: src.thresholdLow,
                  thresholdHigh: src.thresholdHigh,
                  color: src.color,
                  timeRange: src.timeRange,
                  aggregation: src.aggregation,
                  imageUrl: src.imageUrl,
                );

                widget.items.add(newW);
                widget.onChanged(List<DashWidget>.from(widget.items));
                setState(() => selectedId = newW.id);
              },
              onRemove: () {
                if (dw.vpin != null && dw.vpin!.isNotEmpty) {
                  VpinRegistry.I.reserve(
                      oldPin: dw.vpin, newPin: null); // unlock immediately
                }
                widget.items.removeWhere((e) => e.id == dw.id);
                widget.onChanged(List<DashWidget>.from(widget.items));
                if (selectedId == dw.id) selectedId = null;
                setState(() {});
              },
              child: buildWidgetCard(
                context,
                dw,
                MqttService.I,
                editable: widget.editable,
                onEdit: () {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    showWidgetSettingsSheet(
                      context,
                      dw,
                      onApplied: (updated) {
                        final idx =
                            widget.items.indexWhere((x) => x.id == updated.id);
                        if (idx != -1) {
                          widget.items[idx] = updated;
                          widget.onChanged(List<DashWidget>.from(widget.items));
                          setState(() {});
                        }
                      },
                    );
                  });
                },
              ),
            )),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  final double grid;
  final bool show;
  _GridPainter(this.grid, this.show);

  @override
  void paint(Canvas canvas, Size size) {
    if (!show) return;
    final paint = Paint()..color = Colors.grey.withOpacity(0.12);
    for (double x = 0; x <= size.width; x += grid) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += grid) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ItemHost extends StatefulWidget {
  final DashWidget data;
  final Size canvasSize;
  final double grid;
  final bool editable;
  final bool selected;
  final VoidCallback onSelect;
  final ValueChanged<DashWidget> onChanged;
  final VoidCallback onDuplicate;
  final VoidCallback onRemove;
  final Widget child;

  const _ItemHost({
    super.key,
    required this.data,
    required this.canvasSize,
    required this.grid,
    required this.editable,
    required this.selected,
    required this.onSelect,
    required this.onChanged,
    required this.onDuplicate,
    required this.onRemove,
    required this.child,
  });

  @override
  State<_ItemHost> createState() => _ItemHostState();
}

class _ItemHostState extends State<_ItemHost> {
  late Offset pos;
  late Size size;

  late Offset _startPos;
  double _moveDx = 0;
  double _moveDy = 0;

  late Size _startSize;
  double _resizeDx = 0;
  double _resizeDy = 0;

  static const double _minW = 120;
  static const double _minH = 80;

  @override
  void initState() {
    super.initState();
    pos = widget.data.position;
    size = _applyMin(widget.data.size);
  }

  Offset _snap(Offset o) => Offset(
        (o.dx / widget.grid).round() * widget.grid,
        (o.dy / widget.grid).round() * widget.grid,
      );

  Size _snapSize(Size s) => Size(
        (s.width / widget.grid).round() * widget.grid,
        (s.height / widget.grid).round() * widget.grid,
      );

  Size _applyMin(Size s) => Size(
        s.width < _minW ? _minW : s.width,
        s.height < _minH ? _minH : s.height,
      );

  Offset _keepInBounds(Offset p, Size sz) {
    double x = p.dx;
    double y = p.dy;
    final double maxX = math.max(0.0, widget.canvasSize.width - sz.width);
    final double maxY = math.max(0.0, widget.canvasSize.height - sz.height);
    x = x.clamp(0.0, maxX);
    y = y.clamp(0.0, maxY);
    return Offset(x, y);
  }

  Size _limitSizeToCanvas(Offset p, Size sz) {
    final double maxW = math.max(_minW, widget.canvasSize.width - p.dx);
    final double maxH = math.max(_minH, widget.canvasSize.height - p.dy);
    final double w = sz.width.clamp(_minW, maxW);
    final double h = sz.height.clamp(_minH, maxH);
    return Size(w, h);
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.editable && widget.selected
        ? Theme.of(context).colorScheme.primary
        : Colors.transparent;

    final core = Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          children: [
            Positioned.fill(child: widget.child),
            if (widget.editable)
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: (_) {
                    _startSize = size;
                    _resizeDx = 0;
                    _resizeDy = 0;
                  },
                  onPanUpdate: (d) {
                    _resizeDx += d.delta.dx;
                    _resizeDy += d.delta.dy;
                    final raw = Size(_startSize.width + _resizeDx,
                        _startSize.height + _resizeDy);
                    final limited = _limitSizeToCanvas(pos, _applyMin(raw));
                    setState(() => size = limited);
                    widget.onChanged(widget.data.copyWith(size: size));
                  },
                  onPanEnd: (_) {
                    final snapped = _snapSize(size);
                    final limited = _limitSizeToCanvas(pos, snapped);
                    setState(() => size = limited);
                    widget.onChanged(widget.data.copyWith(size: size));
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.bottomRight,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.28),
                      borderRadius:
                          const BorderRadius.only(topLeft: Radius.circular(8)),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.only(right: 4, bottom: 4),
                      child: Icon(Icons.open_in_full,
                          size: 20, color: Colors.white),
                    ),
                  ),
                ),
              ),
            if (widget.editable)
              Positioned(
                right: 6,
                top: 6,
                child: Material(
                  color: Colors.transparent,
                  child: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          showWidgetSettingsSheet(
                            context,
                            widget.data,
                            onApplied: (updated) {
                              widget.onChanged(updated);
                              setState(() {});
                            },
                          );
                        });
                      } else if (v == 'dup') {
                        widget.onDuplicate();
                      } else if (v == 'del') {
                        widget.onRemove();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                              leading: Icon(Icons.tune), title: Text('Edit'))),
                      PopupMenuItem(
                          value: 'dup',
                          child: ListTile(
                              leading: Icon(Icons.copy),
                              title: Text('Duplicate'))),
                      PopupMenuItem(
                          value: 'del',
                          child: ListTile(
                              leading: Icon(Icons.delete_outline),
                              title: Text('Remove'))),
                    ],
                    icon: const Icon(Icons.more_vert, size: 18),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (!widget.editable) {
      return Positioned(left: pos.dx, top: pos.dy, child: core);
    }

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTap: widget.onSelect,
        onPanStart: (_) {
          _startPos = pos;
          _moveDx = 0;
          _moveDy = 0;
        },
        onPanUpdate: (d) {
          _moveDx += d.delta.dx;
          _moveDy += d.delta.dy;
          final raw = _startPos + Offset(_moveDx, _moveDy);
          final bounded = _keepInBounds(raw, size);
          setState(() => pos = bounded);
          widget.onChanged(widget.data.copyWith(position: pos));
        },
        onPanEnd: (_) {
          final snapped = _snap(pos);
          final bounded = _keepInBounds(snapped, size);
          setState(() => pos = bounded);
          widget.onChanged(widget.data.copyWith(position: pos));
        },
        child: core,
      ),
    );
  }
}
