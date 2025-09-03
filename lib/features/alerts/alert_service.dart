// File: lib/features/alerts/alert_service.dart
// Public API: rules getter, addRule, updateRule, removeRuleAt, load/save, start/stop.
// Changes in this step:
// - Strong typing with generics (List<AlertRule>, List<AlertEvent>, StreamController<AlertEvent>).
// - Awaited persistence in mutating methods to avoid races.
// - Solid wildcard topic matching (+ and #) with {device} -> + normalization.
// - Bounded recent queue with keep, and ValueNotifier<int> tick for lightweight UI rebuilds.

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../data/topic_store.dart';
import '../../services/storage_service.dart';

enum AlertLevel { info, warn, alarm }

class AlertRule {
  final String topic;
  final double? min;
  final double? max;
  final double? warnLow;
  final double? warnHigh;

  const AlertRule({
    required this.topic,
    this.min,
    this.max,
    this.warnLow,
    this.warnHigh,
  });

  Map<String, dynamic> toJson() => {
        'topic': topic,
        'min': min,
        'max': max,
        'warnLow': warnLow,
        'warnHigh': warnHigh,
      };

  static AlertRule fromJson(Map m) => AlertRule(
        topic: m['topic'] ?? '',
        min: (m['min'] as num?)?.toDouble(),
        max: (m['max'] as num?)?.toDouble(),
        warnLow: (m['warnLow'] as num?)?.toDouble(),
        warnHigh: (m['warnHigh'] as num?)?.toDouble(),
      );

  AlertRule copyWith({
    String? topic,
    double? min,
    double? max,
    double? warnLow,
    double? warnHigh,
  }) =>
      AlertRule(
        topic: topic ?? this.topic,
        min: min ?? this.min,
        max: max ?? this.max,
        warnLow: warnLow ?? this.warnLow,
        warnHigh: warnHigh ?? this.warnHigh,
      );
}

class AlertEvent {
  final DateTime ts;
  final String topic;
  final AlertLevel level;
  final double? value;
  final String message;

  const AlertEvent({
    required this.ts,
    required this.topic,
    required this.level,
    required this.value,
    required this.message,
  });
}

class AlertService {
  AlertService._();
  static final AlertService I = AlertService._();

  final List<AlertRule> _rules = <AlertRule>[];
  List<AlertRule> get rules => List<AlertRule>.unmodifiable(_rules);

  final StreamController<AlertEvent> _ctrl =
      StreamController<AlertEvent>.broadcast();
  Stream<AlertEvent> get stream => _ctrl.stream;

  final List<AlertEvent> _recent = <AlertEvent>[];
  List<AlertEvent> get recent => List<AlertEvent>.unmodifiable(_recent);

  int keep = 200; // max recent events to keep
  final ValueNotifier<int> tick = ValueNotifier<int>(0);

  StreamSubscription<dynamic>? _sub;

  Future<void> loadRules() async {
    final dynamic list = await StorageService.loadAlertRules();
    _rules
      ..clear()
      ..addAll((list as List).map((e) => AlertRule.fromJson(e as Map)));
  }

  Future<void> saveRules() async {
    await StorageService.saveAlertRules(
      _rules.map((e) => e.toJson()).toList(),
    );
  }

  Future<void> setRules(List<AlertRule> rules) async {
    _rules
      ..clear()
      ..addAll(rules);
    await saveRules();
  }

  Future<void> addRule(AlertRule rule) async {
    _rules.add(rule);
    await saveRules();
  }

  Future<void> updateRule(int index, AlertRule rule) async {
    if (index < 0 || index >= _rules.length) return;
    _rules[index] = rule;
    await saveRules();
  }

  Future<void> removeRuleAt(int index) async {
    if (index < 0 || index >= _rules.length) return;
    _rules.removeAt(index);
    await saveRules();
  }

  void start() {
    _sub?.cancel();
    _sub = TopicStore.I.stream.listen(_onSample);
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  void _onSample(TopicSample s) {
    final int ruleIndex = _findRuleIndexForTopic(s.topic);
    if (ruleIndex == -1 || s.value == null) return;

    final AlertRule r = _rules[ruleIndex];
    final double v = (s.value is num)
        ? (s.value as num).toDouble()
        : double.tryParse('${s.value}') ?? double.nan;

    if (v.isNaN) return;

    AlertEvent? evt;

    if (r.min != null && v < r.min!) {
      evt = AlertEvent(
        ts: s.ts,
        topic: s.topic,
        level: AlertLevel.alarm,
        value: v,
        message: 'Below min ${r.min}',
      );
    } else if (r.max != null && v > r.max!) {
      evt = AlertEvent(
        ts: s.ts,
        topic: s.topic,
        level: AlertLevel.alarm,
        value: v,
        message: 'Above max ${r.max}',
      );
    } else if (r.warnLow != null && v < r.warnLow!) {
      evt = AlertEvent(
        ts: s.ts,
        topic: s.topic,
        level: AlertLevel.warn,
        value: v,
        message: 'Below warn ${r.warnLow}',
      );
    } else if (r.warnHigh != null && v > r.warnHigh!) {
      evt = AlertEvent(
        ts: s.ts,
        topic: s.topic,
        level: AlertLevel.warn,
        value: v,
        message: 'Above warn ${r.warnHigh}',
      );
    }

    if (evt != null) {
      _recent.add(evt);
      if (_recent.length > keep) {
        _recent.removeRange(0, _recent.length - keep);
      }
      _ctrl.add(evt);
      tick.value++;
    }
  }

  int _findRuleIndexForTopic(String topic) {
    for (int i = 0; i < _rules.length; i++) {
      if (_topicMatch(_rules[i].topic, topic)) return i;
    }
    return -1;
  }

  // Supports {device}, + and # wildcards
  bool _topicMatch(String pattern, String topic) {
    final String pat = pattern.contains('{device}')
        ? pattern.replaceAll('{device}', '+')
        : pattern;
    return _wildcardMatch(pat, topic);
  }

  bool _wildcardMatch(String pat, String topic) {
    final List<String> pp = pat.split('/');
    final List<String> tt = topic.split('/');

    int i = 0, j = 0;
    while (i < pp.length) {
      final String seg = pp[i];
      if (seg == '#') {
        // matches the rest
        return true;
      }
      if (j >= tt.length) return false;
      if (seg == '+') {
        i++;
        j++;
        continue;
      }
      if (seg != tt[j]) return false;
      i++;
      j++;
    }
    // pattern consumed: must also consume entire topic for exact match
    return j == tt.length;
  }
}
