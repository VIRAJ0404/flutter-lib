// File: lib/features/alerts/alert_rules_page.dart
// Uses public AlertService APIs; no private (_rules) access.

import 'package:flutter/material.dart';
import 'alert_service.dart';

class AlertRulesPage extends StatefulWidget {
  const AlertRulesPage({super.key});
  @override
  State<AlertRulesPage> createState() => _AlertRulesPageState();
}

class _AlertRulesPageState extends State<AlertRulesPage> {
  final List<AlertRule> _rules = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await AlertService.I.loadRules();
    setState(() {
      _rules
        ..clear()
        ..addAll(AlertService.I.rules);
    });
  }

  void _add() {
    setState(() {
      _rules.add(const AlertRule(
          topic: 'esp32server/{device}/temp', warnHigh: 50, max: 60));
    });
    AlertService.I.setRules(_rules);
  }

  Future<void> _apply(
      int i,
      TextEditingController topicCtrl,
      TextEditingController minCtrl,
      TextEditingController maxCtrl,
      TextEditingController wlCtrl,
      TextEditingController whCtrl) async {
    final updated = AlertRule(
      topic: topicCtrl.text.trim(),
      min: double.tryParse(minCtrl.text.trim()),
      max: double.tryParse(maxCtrl.text.trim()),
      warnLow: double.tryParse(wlCtrl.text.trim()),
      warnHigh: double.tryParse(whCtrl.text.trim()),
    );
    setState(() => _rules[i] = updated);
    AlertService.I.setRules(_rules);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Rule saved')));
  }

  void _delete(int i) {
    setState(() => _rules.removeAt(i));
    AlertService.I.setRules(_rules);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alert Rules')),
      floatingActionButton:
          FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
      body: ListView.builder(
        itemCount: _rules.length,
        itemBuilder: (_, i) {
          final r = _rules[i];
          final topicCtrl = TextEditingController(text: r.topic);
          final minCtrl = TextEditingController(text: r.min?.toString() ?? '');
          final maxCtrl = TextEditingController(text: r.max?.toString() ?? '');
          final wlCtrl =
              TextEditingController(text: r.warnLow?.toString() ?? '');
          final whCtrl =
              TextEditingController(text: r.warnHigh?.toString() ?? '');
          return Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                      controller: topicCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Topic (supports {device}, +, #)')),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                          child: TextField(
                              controller: minCtrl,
                              decoration:
                                  const InputDecoration(labelText: 'Min'),
                              keyboardType: TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: TextField(
                              controller: maxCtrl,
                              decoration:
                                  const InputDecoration(labelText: 'Max'),
                              keyboardType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                          child: TextField(
                              controller: wlCtrl,
                              decoration:
                                  const InputDecoration(labelText: 'Warn Low'),
                              keyboardType: TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: TextField(
                              controller: whCtrl,
                              decoration:
                                  const InputDecoration(labelText: 'Warn High'),
                              keyboardType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.tonal(
                          onPressed: () => _delete(i),
                          child: const Text('Delete')),
                      const Spacer(),
                      FilledButton(
                          onPressed: () => _apply(
                              i, topicCtrl, minCtrl, maxCtrl, wlCtrl, whCtrl),
                          child: const Text('Apply')),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
