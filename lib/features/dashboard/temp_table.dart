// File: lib/features/dashboard/temp_table.dart
// Temperature table using TopicStore buffer for a single scoped topic.

import 'package:flutter/material.dart';
import '../data/topic_store.dart';

class TempTable extends StatelessWidget {
  final String topic; // e.g. esp32server/{device}/temp
  final int rows;
  const TempTable({super.key, required this.topic, this.rows = 20});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: TopicStore.I.tick,
      builder: (_, __, ___) {
        final buf = TopicStore.I.buffer(topic).reversed.take(rows).toList();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Time')),
                DataColumn(label: Text('Value')),
              ],
              rows: buf
                  .map((s) => DataRow(cells: [
                        DataCell(
                            Text(TimeOfDay.fromDateTime(s.ts).format(context))),
                        DataCell(Text(s.value?.toStringAsFixed(2) ?? s.raw)),
                      ]))
                  .toList(),
            ),
          ),
        );
      },
    );
  }
}
