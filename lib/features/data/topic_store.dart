// File: lib/features/data/topic_store.dart
// Topic cache + live stream API for widgets, alerts, and tables.
// Exposes: start(), stream, TopicSample (with .ts getter), tick (ValueNotifier<int>), buffer(), latest().

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class TopicSample {
  final String topic;
  final String raw;
  final double? value;
  final DateTime time;
  const TopicSample(this.topic, this.raw, this.value, this.time);

  // Back-compat for code that expects `.ts`
  DateTime get ts => time;
}

class TopicItem {
  final String topic;
  final String raw;
  final double? value;
  final DateTime time;
  TopicItem(this.topic, this.raw, this.value, this.time);

  DateTime get ts => time;
}

typedef IngestHook = void Function(String topic, String payload);

class TopicStore {
  TopicStore._();
  static final TopicStore I = TopicStore._();

  // Latest per topic and ring buffers for history.
  final Map<String, TopicItem> _latest = {};
  final Map<String, List<TopicSample>> _buffers = {};

  // Live data stream for listeners (alerts, tables).
  final StreamController<TopicSample> _streamCtrl =
      StreamController<TopicSample>.broadcast();
  Stream<TopicSample> get stream => _streamCtrl.stream;

  // Periodic UI tick as a simple counter.
  final ValueNotifier<int> tick = ValueNotifier<int>(0);
  Timer? _tickTimer;

  // Optional hook so services (VPin) can observe ingested traffic.
  IngestHook? onIngest;

  // Start periodic tick; idempotent.
  void start({Duration every = const Duration(seconds: 1)}) {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(every, (_) => tick.value = tick.value + 1);
  }

  void dispose() {
    _tickTimer?.cancel();
    _tickTimer = null;
    _streamCtrl.close();
  }

  // Ingest one message from MQTT.
  void ingest(String topic, String payload) {
    double? v;
    // Try direct numeric.
    final numTry = double.tryParse(payload);
    if (numTry != null) {
      v = numTry;
    } else {
      // Try JSON with { "value": <num> }
      try {
        final obj = jsonDecode(payload);
        if (obj is Map && obj['value'] is num) {
          v = (obj['value'] as num).toDouble();
        }
      } catch (_) {
        // leave v null
      }
    }

    final now = DateTime.now();
    final item = TopicItem(topic, payload, v, now);
    _latest[topic] = item;

    final sample = TopicSample(topic, payload, v, now);
    final buf = _buffers.putIfAbsent(topic, () => <TopicSample>[]);
    buf.add(sample);
    if (buf.length > 500) {
      buf.removeRange(0, buf.length - 500);
    }

    if (!_streamCtrl.isClosed) {
      _streamCtrl.add(sample);
    }

    onIngest?.call(topic, payload);
  }

  // Latest sample wrapper for convenience consumers.
  TopicItem? latest(String topic) => _latest[topic];

  // Return an immutable copy of recent samples for a topic.
  List<TopicSample> buffer(String topic, [int max = 200]) {
    final src = _buffers[topic];
    if (src == null || src.isEmpty) return const <TopicSample>[];
    if (src.length <= max) return List<TopicSample>.unmodifiable(src);
    return List<TopicSample>.unmodifiable(src.sublist(src.length - max));
  }

  void clear() {
    _latest.clear();
    _buffers.clear();
  }
}
