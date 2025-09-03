// File: lib/features/history/history_page.dart
import 'package:flutter/material.dart';
import '../../services/mqtt_service.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context) {
    final msgs = MqttService.I.messages;
    final pad = MediaQuery.of(context).size.width < 360 ? 12.0 : 16.0;
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: ValueListenableBuilder(
        valueListenable: msgs,
        builder: (_, List<String> items, __) {
          return ListView.separated(
            padding: EdgeInsets.all(pad),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => Text(items[i]),
          );
        },
      ),
    );
  }
}
