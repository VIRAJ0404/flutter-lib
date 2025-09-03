// File: lib/features/dashboard/models.dart
// Changes:
// - Serialize color via color.toARGB32() (wide-gamut migration).
// - Parse color from stored 32-bit ARGB int.

import 'package:flutter/material.dart';

enum WidgetKind {
  button,
  toggle,
  slider,
  gauge,
  kpi,
  lineChart,
  barChart,
  led,
  text,
  // new kinds
  numberInput,
  segmented,
  verticalSlider,
  stepSlider,
  verticalStepSlider,
  radialGauge,
  joystick,
  rgb,
  styledButton,
  imageButton,
  valueDisplay,
  labeledDisplay,
  terminal,
  spacer,
}

class DashWidget {
  final String id;
  WidgetKind kind;
  String title;
  Offset position;
  Size size;
  String? readTopic;
  String? writeTopic;
  String? vpin;
  String unit;
  double? min;
  double? max;
  double? thresholdLow;
  double? thresholdHigh;
  Color color;
  Duration? timeRange;
  String aggregation;
  String? imageUrl;

  DashWidget({
    required this.id,
    required this.kind,
    required this.title,
    required this.position,
    required this.size,
    this.readTopic,
    this.writeTopic,
    this.vpin,
    this.unit = '',
    this.min,
    this.max,
    this.thresholdLow,
    this.thresholdHigh,
    this.color = const Color(0xFF0066CC),
    this.timeRange,
    this.aggregation = 'raw',
    this.imageUrl,
  });

  DashWidget copyWith({
    WidgetKind? kind,
    String? title,
    Offset? position,
    Size? size,
    String? readTopic,
    String? writeTopic,
    String? vpin,
    String? unit,
    double? min,
    double? max,
    double? thresholdLow,
    double? thresholdHigh,
    Color? color,
    Duration? timeRange,
    String? aggregation,
    String? imageUrl,
  }) =>
      DashWidget(
        id: id,
        kind: kind ?? this.kind,
        title: title ?? this.title,
        position: position ?? this.position,
        size: size ?? this.size,
        readTopic: readTopic ?? this.readTopic,
        writeTopic: writeTopic ?? this.writeTopic,
        vpin: vpin ?? this.vpin,
        unit: unit ?? this.unit,
        min: min ?? this.min,
        max: max ?? this.max,
        thresholdLow: thresholdLow ?? this.thresholdLow,
        thresholdHigh: thresholdHigh ?? this.thresholdHigh,
        color: color ?? this.color,
        timeRange: timeRange ?? this.timeRange,
        aggregation: aggregation ?? this.aggregation,
        imageUrl: imageUrl ?? this.imageUrl,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'x': position.dx,
        'y': position.dy,
        'w': size.width,
        'h': size.height,
        'read': readTopic,
        'write': writeTopic,
        'vpin': vpin,
        'unit': unit,
        'min': min,
        'max': max,
        'thLow': thresholdLow,
        'thHigh': thresholdHigh,
        'color': color.toARGB32(), // sRGB 32-bit
        'agg': aggregation,
        'tr': timeRange?.inSeconds,
        'imageUrl': imageUrl,
      };

  static DashWidget fromJson(Map m) => DashWidget(
        id: m['id'],
        kind: WidgetKind.values.firstWhere((e) => e.name == m['kind']),
        title: m['title'] ?? '',
        position:
            Offset((m['x'] as num).toDouble(), (m['y'] as num).toDouble()),
        size: Size((m['w'] as num).toDouble(), (m['h'] as num).toDouble()),
        readTopic: m['read'],
        writeTopic: m['write'],
        vpin: m['vpin'],
        unit: m['unit'] ?? '',
        min: (m['min'] as num?)?.toDouble(),
        max: (m['max'] as num?)?.toDouble(),
        thresholdLow: (m['thLow'] as num?)?.toDouble(),
        thresholdHigh: (m['thHigh'] as num?)?.toDouble(),
        color: Color((m['color'] as num?)?.toInt() ??
            const Color(0xFF0066CC).toARGB32()),
        timeRange: (m['tr'] as num?) != null
            ? Duration(seconds: (m['tr'] as num).toInt())
            : null,
        aggregation: m['agg'] ?? 'raw',
        imageUrl: m['imageUrl'],
      );
}

class DashPageModel {
  String id;
  String title;
  List<DashWidget> items;

  DashPageModel({required this.id, required this.title, required this.items});

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'items': items.map((e) => e.toJson()).toList(),
      };

  static DashPageModel fromJson(Map m) => DashPageModel(
        id: m['id'],
        title: m['title'] ?? 'Page',
        items: (m['items'] as List? ?? const [])
            .map((e) => DashWidget.fromJson(e as Map))
            .toList(),
      );
}
