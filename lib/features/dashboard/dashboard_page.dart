// File: lib/features/dashboard/dashboard_page.dart
// Dashboard: bootstrap vPin locks on load and keep registry in sync with storage changes.

import 'package:flutter/material.dart';

import '../devices/device_registry.dart';
import '../../services/storage_service.dart';
import '../../services/vpin_registry.dart';
import '../../services/mqtt_service.dart';

import 'models.dart';
import 'editor_canvas.dart';
import 'widgets_gallery.dart' as wg;
import 'edit_home_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<DashPageModel> pages = [];
  late final VoidCallback _tickListener;

  @override
  void initState() {
    super.initState();
    VpinRegistry.I.start(); // Bootstrap locks from saved pages
    _loadPages();
    MqttService.I.subscribe('esp32server/+/#');
    _tickListener = () async {
      await _loadPages();
      VpinRegistry.I.rebuildFromPages(pages);
    };
    StorageService.pagesChanged.addListener(_tickListener);
  }

  @override
  void dispose() {
    StorageService.pagesChanged.removeListener(_tickListener);
    super.dispose();
  }

  Future<void> _loadPages() async {
    pages = await StorageService.loadPages();
    if (mounted) setState(() {});
  }

  String? _scopeTopic(String? t, String? device) {
    if (t == null) return null;
    if (device == null || device.isEmpty) return t;
    return t.replaceAll('{device}', device);
  }

  @override
  Widget build(BuildContext context) {
    final device = DeviceRegistry.I.selected.value;
    final int length = pages.isEmpty ? 1 : pages.length;

    Widget buildScoped(BuildContext ctx, DashWidget dw) {
      final show = dw.copyWith(
        readTopic: _scopeTopic(dw.readTopic, device),
        writeTopic: _scopeTopic(dw.writeTopic, device),
      );
      return wg.buildWidgetCard(ctx, show, MqttService.I);
    }

    return DefaultTabController(
      key: ValueKey('home_tabs_len_$length'),
      length: length,
      child: Stack(
        children: [
          Column(
            children: [
              if (pages.isNotEmpty)
                Material(
                  color: Colors.transparent,
                  child: TabBar(
                    isScrollable: true,
                    tabs: [for (final p in pages) Tab(text: p.title)],
                  ),
                ),
              Expanded(
                child: TabBarView(
                  physics: const BouncingScrollPhysics(),
                  children: pages.isNotEmpty
                      ? pages.map((p) {
                          return LayoutBuilder(builder: (context, box) {
                            return EditorCanvas(
                              size: Size(box.maxWidth, box.maxHeight),
                              items: p.items,
                              onChanged: (_) {}, // locked on Home
                              widgetBuilder: buildScoped,
                              editable: false,
                            );
                          });
                        }).toList()
                      : const [
                          Center(child: Text('No pages yet. Tap Edit to add.'))
                        ],
                ),
              ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const EditHomePage()));
              },
              icon: const Icon(Icons.edit),
              label: const Text('Edit'),
            ),
          ),
        ],
      ),
    );
  }
}
