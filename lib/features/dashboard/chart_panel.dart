// File: lib/features/dashboard/chart_panel.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../services/mqtt_service.dart';

class ChartPanel extends StatefulWidget {
  final String title;
  final String topic;
  final int maxPoints;
  const ChartPanel(
      {super.key,
      required this.title,
      required this.topic,
      this.maxPoints = 500});

  @override
  State<ChartPanel> createState() => _ChartPanelState();
}

class _ChartPanelState extends State<ChartPanel> {
  late List<_Pt> data;
  ChartSeriesController<_Pt, DateTime>? _controller;
  late final MqttService _mqtt;

  @override
  void initState() {
    super.initState();
    data = <_Pt>[];
    _mqtt = MqttService.I;
    _mqtt.messages.addListener(_onMsg);
  }

  @override
  void dispose() {
    _mqtt.messages.removeListener(_onMsg);
    super.dispose();
  }

  // Normalize any dynamic timestamp to a non-null millisecond int.
  int _msOrNow(dynamic nts, int fallbackMs) {
    if (nts == null) return fallbackMs;
    if (nts is int) return nts;
    if (nts is num) return nts.toInt();
    if (nts is String) {
      final n = num.tryParse(nts);
      return (n == null) ? fallbackMs : n.toInt();
    }
    return fallbackMs;
  }

  void _onMsg() {
    for (final line in _mqtt.messages.value.take(5)) {
      final sep = line.indexOf('] ');
      if (sep <= 0) {
        continue;
      }
      final topic = line.substring(1, sep);
      final payload = line.substring(sep + 2);
      if (topic != widget.topic) {
        continue;
      }

      final now = DateTime.now();
      double? v;
      DateTime ts = now;
      try {
        final j = jsonDecode(payload);
        if (j is Map) {
          final num? nv = j['value'] as num?;
          v = nv?.toDouble();
          final int ms = _msOrNow(j['ts'], now.millisecondsSinceEpoch);
          ts = DateTime.fromMillisecondsSinceEpoch(ms);
        } else if (j is num) {
          v = j.toDouble();
          ts = now;
        }
      } catch (_) {
        v = double.tryParse(payload);
        ts = now;
      }
      if (v == null) {
        continue;
      }

      data.add(_Pt(ts, v));
      final exceeded = data.length > widget.maxPoints;
      if (exceeded) {
        data.removeRange(0, data.length - widget.maxPoints);
      }

      if (_controller != null) {
        // Call with different named args to avoid passing null to an int param.
        if (exceeded) {
          _controller!.updateDataSource(
            addedDataIndex: data.length - 1,
            removedDataIndex: 0,
          );
        } else {
          _controller!.updateDataSource(
            addedDataIndex: data.length - 1,
          );
        }
      } else {
        setState(() {});
      }
      break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SfCartesianChart(
          title: ChartTitle(text: widget.title),
          primaryXAxis: const DateTimeAxis(
            intervalType: DateTimeIntervalType.minutes,
            majorGridLines: MajorGridLines(width: 0.5),
          ),
          primaryYAxis: const NumericAxis(
            axisLine: AxisLine(width: 0.5),
            majorGridLines: MajorGridLines(width: 0.5),
          ),
          series: <LineSeries<_Pt, DateTime>>[
            LineSeries<_Pt, DateTime>(
              onRendererCreated: (c) => _controller = c,
              dataSource: data,
              xValueMapper: (p, _) => p.t,
              yValueMapper: (p, _) => p.v,
              color: cs.primary,
              width: 2,
            ),
          ],
          trackballBehavior: TrackballBehavior(
              enable: true, activationMode: ActivationMode.singleTap),
          zoomPanBehavior:
              ZoomPanBehavior(enablePanning: true, enablePinching: true),
        ),
      ),
    );
  }
}

class _Pt {
  final DateTime t;
  final double v;
  _Pt(this.t, this.v);
}
